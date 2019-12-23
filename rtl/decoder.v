module decoder #(parameter OPCODE_WIDTH    =  4,
                           PMEM_ADDR_WIDTH = 12,
                           PMEM_WORD_WIDTH = 16,
                           IALU_WORD_WIDTH = 16,
                           REG_IDX_WIDTH   =  4,
                           PC_WIDTH        = 12)
       (
       input                         clock,
       input                         reset,
       input                         in_flush,                          // flushes decode stage, i.e., zeros all outputs (from EX stage)
       input  [PMEM_WORD_WIDTH-1:0]  in_instr,                          // instruction (from FE stage)
       input  [       PC_WIDTH-1:0]  in_pc,                             // program counter (from FE stage)
       input  [IALU_WORD_WIDTH-1:0]  in_res_EX,                         // result from EX stage (for bypassing)
       input  [IALU_WORD_WIDTH-1:0]  in_res_MEM,                        // result from MEM stage (for bypassing)
       input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx_EX,                 // result register index from EX stage (for bypassing)
       input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx_MEM,                // result register index from MEM stage (for bypassing)
       input                         in_res_valid_EX,                   // the result of the EX stage is valid (can be forwarded from there)
       input  [IALU_WORD_WIDTH-1:0]  in_src1,                           // 1st input (from regfile)
       input  [IALU_WORD_WIDTH-1:0]  in_src2,                           // 2nd input (from regfile)
       output                        out_act_branch_ialu_res_ff_eq0,    // branch if registered IALU result is equal to zero
       output                        out_act_branch_ialu_res_ff_gt0,    // branch if registered IALU result is greater zero
       output                        out_act_branch_ialu_res_ff_lt0,    // branch if registered IALU result is less than zero
       output                        out_act_ialu_add,                  // integer add
       output                        out_act_ialu_and,                  // logic and
       output                        out_act_ialu_mul,                  // integer multiply
       output                        out_act_ialu_neg_src2,             // negate src2 before forwarding it to the ALU
       output                        out_act_ialu_or,                   // logic or
       output                        out_act_ialu_sll,                  // shift left logically
       output                        out_act_ialu_sra,                  // shift right arithmetically
       output                        out_act_ialu_srl,                  // shift right logically
       output                        out_act_ialu_write_src2_to_res,    // make src2 the result if the IALU without any actual calculation
       output                        out_act_ialu_xor,                  // logic xor
       output                        out_act_incr_pc_is_res,            // incremented pc becomes result of EX stage (not of IALU)
       output                        out_act_jump_to_ialu_res,          // jump to the result of the IALU 
       output                        out_act_load_dmem,                 // load data from dmem into register
       output                        out_act_store_dmem,                // store date from register in dmem
       output                        out_act_write_res_to_reg,          // activate writeback to regfile in WB stage
       output                 [2:0]  out_cycle_in_instr,                // for multi-cycle instructions: which cycle are we in?
       output [PMEM_WORD_WIDTH-1:0]  out_instr,                         // forward instruction to EX stage
       output                        out_instr_is_bubble,               // instruction is a bubble, NOP
       output [       PC_WIDTH-1:0]  out_pc,                            // forward program counter to EX stage
       output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,                   // index of register that the result from EX is written to one it reaches WB
       output                        out_res_valid_EX,                  // result in EX stage can be bypassed back as input to DC stage
       output [IALU_WORD_WIDTH-1:0]  out_src1,                          // forward 1st input from regfile to EX stage
       output [  REG_IDX_WIDTH-1:0]  out_src1_reg_idx,                  // inform register file which register we want as src1 input to EX stage
       output [IALU_WORD_WIDTH-1:0]  out_src2,                          // forward 2nd input from regfile to EX stage
       output [  REG_IDX_WIDTH-1:0]  out_src2_reg_idx,                  // inform register file which register we want as src2 input to EX stage
       output [IALU_WORD_WIDTH-1:0]  out_src3,                          // 3rd input to EX stage. only used by SH and SHO instructions
       output                        out_stall                          // stalls the FE stage so no new instruction is loaded from PMEM
       );

    localparam IMMA_WIDTH  = 4;
    localparam IMMB_WITHD  = 16;
    localparam FUNC1_WIDTH = 4;
    localparam FUNC2_WIDTH = 4;
    localparam FUNC3_WIDTH = 4;
    
    // Root opcode
    localparam [OPCODE_WIDTH-1:0] OPCODE_NOP    = 4'b0000; 
    localparam [OPCODE_WIDTH-1:0] OPCODE_U_TYPE = 4'b0001;
    localparam [OPCODE_WIDTH-1:0] OPCODE_J_TYPE = 4'b0010;
    localparam [OPCODE_WIDTH-1:0] OPCODE_S_TYPE = 4'b0011;
    localparam [OPCODE_WIDTH-1:0] OPCODE_LH     = 4'b0100; // I-Type: Load half
    localparam [OPCODE_WIDTH-1:0] OPCODE_LHO    = 4'b0101; // I-Type: Load half with offset
    localparam [OPCODE_WIDTH-1:0] OPCODE_ADD    = 4'b0110; // R-Type: integer addition
    localparam [OPCODE_WIDTH-1:0] OPCODE_SUB    = 4'b0111; // R-Type: integer subtraction
    localparam [OPCODE_WIDTH-1:0] OPCODE_MUL    = 4'b1000; // R-Type: integer multiplication
    localparam [OPCODE_WIDTH-1:0] OPCODE_SLL    = 4'b1001; // R-Type: shift left logically
    localparam [OPCODE_WIDTH-1:0] OPCODE_SRL    = 4'b1010; // R-Type: shift right logically
    localparam [OPCODE_WIDTH-1:0] OPCODE_SRA    = 4'b1011; // R-Type: shift right arithmetically
    localparam [OPCODE_WIDTH-1:0] OPCODE_AND    = 4'b1100; // R-Type: logical and
    localparam [OPCODE_WIDTH-1:0] OPCODE_OR     = 4'b1101; // R-Type: logical or
    localparam [OPCODE_WIDTH-1:0] OPCODE_XOR    = 4'b1110; // R-Type: logical xor

    // S-TYPE
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BEQ     = 4'b0000; // Branch if equal
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BNEQ    = 4'b0001; // Branch if not equal
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BGE     = 4'b0010; // Branch if greater or equal
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BLT     = 4'b0011; // Branch if less than
    localparam [ FUNC1_WIDTH-1:0] FUNC1_SH      = 4'b0100; // Store half (i.e., 16-bit)
    localparam [ FUNC1_WIDTH-1:0] FUNC1_SHO     = 4'b0101; // Store half (i.e., 16-bit) with offset
    
    // U-TYPE
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LI      = 4'b0011;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LIL     = 4'b0100;

    // J-Type
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JAL     = 4'b0000;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JALR    = 4'b0001;

    // Special instructions
    localparam [PMEM_WORD_WIDTH-1:0] INSTR_NOP  = {{12{1'b0}}, OPCODE_NOP};
    
    
    reg  [                2:0]  cycle_in_instr_next;
    reg  [                2:0]  cycle_in_instr_ff;

    reg                         flush_ff;
    wire [PMEM_WORD_WIDTH-1:0]  instr_1st_word;  // Holds first word of instruction (also for multi-cycle instructions)
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff;        // Current instruction word
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff2;       // Instruction word before current word instruction

    reg  [PMEM_ADDR_WIDTH-1:0]  jump_offset;

    reg  [       PC_WIDTH-1:0]  pc_ff;
    reg  [       PC_WIDTH-1:0]  pc_ff2;

    reg                         res_used;        // Is valid result assgined to result field in instruction?
    reg  [IALU_WORD_WIDTH-1:0]  src1_mod;        // Holds src1 input to EX stage (either from regfile or bypassed)
    reg                         src1_stall;      // Do we have to stall because src1 is unavailable?
    reg                         src1_used;       // Is a valid operand assigned to src1?
    reg  [IALU_WORD_WIDTH-1:0]  src2_mod;        // Holds src2 input to EX stage (either from regfile or bypassed)
    reg                         src2_stall;      // Do we have to stall because src2 is unavailable?
    reg                         src2_used;       // Is a valid operand assigned to src2?

    
    // Instruction segments
    wire [   OPCODE_WIDTH-1:0]  opcode       = instr_1st_word [OPCODE_WIDTH-1:0];
    wire [  REG_IDX_WIDTH-1:0]  src1_reg_idx = instr_1st_word [11:8];
    wire [  REG_IDX_WIDTH-1:0]  src2_reg_idx = instr_1st_word [15:12];
    wire [    FUNC1_WIDTH-1:0]  func1        = instr_1st_word [7:4];
    wire [    FUNC2_WIDTH-1:0]  func2        = instr_1st_word [11:8];
    wire [    FUNC3_WIDTH-1:0]  func3        = instr_1st_word [15:12];
    wire [                3:0]  immA         = instr_1st_word [15:12];
    wire [PMEM_WORD_WIDTH-1:0]  immB         = instr_ff; // only valid in 2nd cycle of multi-cycle instruction

    
    // Connecting signals to output ports
    assign out_cycle_in_instr  = cycle_in_instr_ff; 
    assign out_instr           = (src1_stall || src2_stall) ? INSTR_NOP : instr_ff; // if stalled, forward NOP instruction to EX stage
    assign out_instr_is_bubble = (out_instr[OPCODE_WIDTH-1:0] == OPCODE_NOP) ? 1 : 0;
    assign out_pc              = pc_ff;
    assign out_res_reg_idx     = (res_used) ? instr_1st_word[7:4] : 0; // forward result register index only if the field is valid in current instruction
    assign out_src1_reg_idx    = src1_reg_idx; // TODO: null me when i am not needed
    assign out_src2_reg_idx    = src2_reg_idx; // TODO: null me when i am not needed
    assign out_stall           = src1_stall | src2_stall;

    // Register: hold sampled inputs
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            flush_ff  <= in_flush;
            instr_ff  <= in_instr;
            pc_ff     <= in_pc;
        end
        else begin
            flush_ff  <= 0;
            instr_ff  <= 0;
            pc_ff     <= 0;
        end
    end

    // Register: index of the current cycle within a multi-cycle instruction
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
            cycle_in_instr_ff <= cycle_in_instr_next;
        else
            cycle_in_instr_ff <= 0;
    end

    // Register: holds the last sampled instruction and pc for two-cycle instructions
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            instr_ff2 <= instr_ff;
            pc_ff2    <= pc_ff;
        end
        else begin
            instr_ff2 <= 0;
            pc_ff2    <= 0;
        end
    end

    // Multiplexer: Hold first instruction word in case of 2-cycle instruction
    assign instr_1st_word = (cycle_in_instr_ff == 0) ? instr_ff : instr_ff2;

    // Bypassing logic: obtain src1 from pipeline, if it is present in there as valid results.
    always @(*)
    begin
        // Bypass from EX
        if ((src1_reg_idx == in_res_reg_idx_EX) && in_res_valid_EX)
        begin
            src1_mod = in_res_EX;
            src1_stall = 0;
        end
        // Bypass from MEM
        else if ( src1_reg_idx == in_res_reg_idx_MEM )
        begin
            src1_mod = in_res_MEM;
            src1_stall = 0;
        end
        // Instruction with desired result is in EX stage but result is invalid (memory load)
        else if ((src1_reg_idx == in_res_reg_idx_EX) && !in_res_valid_EX && src1_used)
        begin
            src1_mod   = 0;
            src1_stall = 1;
        end
        // Get data from regfile
        else
        begin
            src1_mod = in_src1;
            src1_stall = 0;
        end
    end

    // Bypassing logic: obtain src2 from pipeline, if it is present in there as valid results.
    always @(*)
    begin
        // Bypass from EX
        if ((src2_reg_idx == in_res_reg_idx_EX) && in_res_valid_EX)
        begin
            src2_mod = in_res_EX;
            src2_stall = 0;
        end
        // Bypass from MEM
        else if ( src2_reg_idx == in_res_reg_idx_MEM )
        begin
            src2_mod = in_res_MEM;
            src2_stall = 0;
        end
        // Instruction with desired result is in EX stage but result is invalid (memory load)
        else if ((src2_reg_idx == in_res_reg_idx_EX) && !in_res_valid_EX && src2_used) begin
            src2_mod   = 0;
            src2_stall = 1;
        end
        // Get data from regfile
        else
        begin
            src2_mod = in_src2;
            src2_stall = 0;
        end
    end

    // Helper function: set all output to zero
    task zero_outputs;
        out_act_branch_ialu_res_ff_eq0  = 0;
        out_act_branch_ialu_res_ff_gt0  = 0;
        out_act_branch_ialu_res_ff_lt0  = 0;
        out_act_ialu_add                = 0;
        out_act_ialu_and                = 0;
        out_act_ialu_mul                = 0;
        out_act_ialu_neg_src2           = 0;
        out_act_ialu_or                 = 0;
        out_act_ialu_sll                = 0; 
        out_act_ialu_sra                = 0; 
        out_act_ialu_srl                = 0; 
        out_act_ialu_write_src2_to_res  = 0;
        out_act_ialu_xor                = 0;
        out_act_incr_pc_is_res          = 0;
        out_act_jump_to_ialu_res        = 0;
        out_act_load_dmem               = 0;
        out_act_store_dmem              = 0;
        out_act_write_res_to_reg        = 0;
        out_res_valid_EX                = 0;
        out_src1                        = 0;
        out_src2                        = 0;
        out_src3                        = 0;
    endtask;

    // Set validity of src1, src2 in current instruction: is the field in the instruction used?
    // This is needed for stalling, since we only stall if there is an actual data dependency
    always @(*)
    begin
        case (opcode)
            OPCODE_S_TYPE,
            OPCODE_ADD,
            OPCODE_SUB,
            OPCODE_MUL,
            OPCODE_SLL,
            OPCODE_SRL,
            OPCODE_SRA,
            OPCODE_AND,
            OPCODE_OR ,
            OPCODE_XOR:
            begin
                src1_used = 1;
                src2_used = 1;
            end

            OPCODE_J_TYPE,
            OPCODE_LH,
            OPCODE_LHO:
            begin
                src1_used = 1;
                src2_used = 0;
            end

            default:
            begin
                src1_used = 0;
                src2_used = 0;
            end

        endcase
    end

    // Set validity of res in current instruction: is the field in the instruction used?
    // This is needed for stalling, since we only stall if there is an actual data dependency
    always @(*)
    begin
        case (opcode)
            OPCODE_S_TYPE:
            begin
                res_used = 0;
            end

            default:
            begin
                res_used = 1;
            end
        endcase
    end
    
    
    //==============================================
    // Decode instruction word
    //==============================================
    always @(*)
    begin
        // Flush or stall
        if (flush_ff == 1 || src1_stall == 1 || src2_stall == 1) begin
            cycle_in_instr_next      = 0;
            zero_outputs();
        end
        
        // U-Type instructions
        else if (opcode == OPCODE_U_TYPE)
        begin
            case (func2)
                // Load 16-bit immediate value
                FUNC2_LI:
                begin
                    if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 0;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 1;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_res_valid_EX                       = 1;    // result can be bypassed from EX
                        out_src1                               = 0;
                        out_src2                               = immB;
                        out_src3                               = 0;
                    end
                    else begin
                        cycle_in_instr_next                    = 1;
                        zero_outputs();
                    end
                end
                
                // Load immediate value to 4 LSBs (no sign extension)
                FUNC2_LIL:
                begin
                        cycle_in_instr_next                    = 0;
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 0;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 1;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_res_valid_EX                       = 1;    // result can be bypassed from EX
                        out_src1                               = 0;
                        out_src2[IMMA_WIDTH-1:0]               = immA;
                        out_src2[IALU_WORD_WIDTH-1:IMMA_WIDTH] = 0;
                        out_src3                               = 0;
                end
                
                //
                default:
                begin
                        cycle_in_instr_next                    = 0;
                        zero_outputs();

                        $display("WARNING: unknown U-Type instruction with opcode %b, func2 %b at time %0t.\n", opcode, func2, $time);
                end
            endcase
        end  // else if (opcode == OPCODE_U_TYPE)

        // S-Type instructions
        else if (opcode == OPCODE_S_TYPE)
        begin
            case (func1)
                
                // Branch if equal
                FUNC1_BEQ:
                begin
                    // 1st and 2nd cycle
                        out_act_branch_ialu_res_ff_eq0         = 1;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_res_valid_EX                       = 0;    // result cannot be bypassed from EX
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src2                  = 1;
                        out_src1                               = src1_mod;
                        out_src2                               = src2_mod;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_src1                               = immB;
                        out_src2[PC_WIDTH-1:0]                 = pc_ff2;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH]   = 0;
                        out_src3                               = 0;
                    end

                end

                // Branch if not equal
                FUNC1_BNEQ:
                begin
                    // 1st and 2nd cycle
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 1;
                        out_act_branch_ialu_res_ff_lt0         = 1;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_res_valid_EX                       = 0;    // result cannot be bypassed from EX
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src2                  = 1;
                        out_src1                               = src1_mod;
                        out_src2                               = src2_mod;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_src1                               = immB;
                        out_src2[PC_WIDTH-1:0]                 = pc_ff2;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH]   = 0;
                        out_src3                               = 0;
                    end

                end

                // Branch if greater equal
                FUNC1_BGE:
                begin
                    // 1st and 2nd cycle
                        out_act_branch_ialu_res_ff_eq0         = 1;
                        out_act_branch_ialu_res_ff_gt0         = 1;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_res_valid_EX                       = 0;    // result cannot be bypassed from EX
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src2                  = 1;
                        out_src1                               = src1_mod;
                        out_src2                               = src2_mod;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_src1                               = immB;
                        out_src2[PC_WIDTH-1:0]                 = pc_ff2;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH]   = 0;
                        out_src3                               = 0;
                    end

                end
                
                // Branch if less than
                FUNC1_BLT:
                begin
                    // 1st and 2nd cycle
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 1;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_res_valid_EX                       = 0;    // result cannot be bypassed from EX
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src2                  = 1;
                        out_src1                               = src1_mod;
                        out_src2                               = src2_mod;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_src1                               = immB;
                        out_src2[PC_WIDTH-1:0]                 = pc_ff2;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH]   = 0;
                        out_src3                               = 0;
                    end

                end
                
                // Store half (16bit) to DMEM
                FUNC1_SH:
                begin
                        cycle_in_instr_next                    = 0;
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 0;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 1;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 1;
                        out_act_write_res_to_reg               = 0;
                        out_res_valid_EX                       = 0;         // result cannot be bypassed from EX
                        out_src1                               = 0;         // base addr
                        out_src2                               = src2_mod;  // offset
                        out_src3                               = src1_mod;  // value;
                end

                // Store half (16bit) with offset to DMEM
                FUNC1_SHO:
                begin
                    if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 1;
                        out_act_write_res_to_reg               = 0;
                        out_res_valid_EX                       = 0;         // result cannot be bypassed from EX
                        out_src1                               = immB;      // base addr
                        out_src2                               = src2_mod;  // offset
                        out_src3                               = src1_mod;  // value
                    end
                    else begin
                        cycle_in_instr_next                    = 1;
                        zero_outputs();
                    end
                end

                default:
                begin
                    cycle_in_instr_next       = 0;
                    zero_outputs();

                    $display("WARNING: unknown S-Type instruction with opcode %b, func1 %b at time %0t.\n", opcode, func1, $time);
                end
                
            endcase
        end

        else if (opcode == OPCODE_J_TYPE)
        begin
            case (func3)
                
                // Jump and link by immediate
                FUNC2_JAL:
                begin
                    if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 1;
                        out_act_jump_to_ialu_res               = 1;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_res_valid_EX                       = 0;    // result cannot be bypassed from EX
                        out_src1                               = immB;
                        out_src2[PC_WIDTH-1:0]                 = pc_ff2;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH]   = 0;
                        out_src3                               = 0;
                    end
                    else begin
                        cycle_in_instr_next                    = 1;
                        zero_outputs();
                    end
                end
                
                // Jump and link by register
                FUNC2_JALR:
                begin
                        cycle_in_instr_next                    = 0;
                        out_act_branch_ialu_res_ff_eq0         = 0;
                        out_act_branch_ialu_res_ff_gt0         = 0;
                        out_act_branch_ialu_res_ff_lt0         = 0;
                        out_act_ialu_add                       = 1;
                        out_act_ialu_and                       = 0;
                        out_act_ialu_mul                       = 0;
                        out_act_ialu_neg_src2                  = 0;
                        out_act_ialu_or                        = 0;
                        out_act_ialu_sll                       = 0; 
                        out_act_ialu_sra                       = 0; 
                        out_act_ialu_srl                       = 0; 
                        out_act_ialu_write_src2_to_res         = 0;
                        out_act_ialu_xor                       = 0;
                        out_act_incr_pc_is_res                 = 1;
                        out_act_jump_to_ialu_res               = 1;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_res_valid_EX                       = 0;    // result cannot be bypassed from EX
                        out_src1                               = src1_mod;
                        out_src2[PC_WIDTH-1:0]                 = pc_ff;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH]   = 0;
                        out_src3                               = 0;
                end

                default:
                begin
                        cycle_in_instr_next                    = 0;
                        zero_outputs();
    
                        $display("WARNING: unknown J-Type instruction with opcode %b, func3 %b at time %0t.\n", opcode, func3, $time);
                end
                
            endcase
        end
    
        // Load half word from DMEM
        else if (opcode == OPCODE_LH) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 1;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 1;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 0;             // result cannot be bypassed from EX
                out_src1                               = 0;
                out_src2                               = src1_mod;      // address (yes, strange to write src1 to src2, but srcX_to_res only exists for src2)
                out_src3                               = 0;
        end

        // Load half word with offset from DMEM
        else if (opcode == OPCODE_LHO) begin
            
            if (cycle_in_instr_ff == 1) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 1;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 1;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 0;             // result cannot be bypassed from EX
                out_src1                               = src1_mod;
                out_src2                               = immB;
                out_src3                               = 0;

            end
            else begin
                cycle_in_instr_next                    = 1;
                zero_outputs();
            end

        end

        // Integer addition
        else if (opcode == OPCODE_ADD) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 1;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Integer subtraction
        else if (opcode == OPCODE_SUB) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 1;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 1;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Integer multiplication
        else if (opcode == OPCODE_MUL) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 1;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Shift left logically
        else if (opcode == OPCODE_SLL) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 1; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Shift right logically
        else if (opcode == OPCODE_SRL) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 1; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Shift right arithmetically
        else if (opcode == OPCODE_SRA) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 1; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Bitwise logical and
        else if (opcode == OPCODE_AND) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 1;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // Bitwise logical or
        else if (opcode == OPCODE_OR) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 1;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end

        // Bitwise logical xor
        else if (opcode == OPCODE_XOR) begin
                cycle_in_instr_next                    = 0;
                out_act_branch_ialu_res_ff_eq0         = 0;
                out_act_branch_ialu_res_ff_gt0         = 0;
                out_act_branch_ialu_res_ff_lt0         = 0;
                out_act_ialu_add                       = 0;
                out_act_ialu_and                       = 0;
                out_act_ialu_mul                       = 0;
                out_act_ialu_neg_src2                  = 0;
                out_act_ialu_or                        = 0;
                out_act_ialu_sll                       = 0; 
                out_act_ialu_sra                       = 0; 
                out_act_ialu_srl                       = 0; 
                out_act_ialu_write_src2_to_res         = 0;
                out_act_ialu_xor                       = 1;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 0;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_res_valid_EX                       = 1;             // result can be bypassed from EX
                out_src1                               = src1_mod;      // argument 1
                out_src2                               = src2_mod;      // argument 2
                out_src3                               = 0;
        end
        
        // No operation
        else if (opcode == OPCODE_NOP) begin
            cycle_in_instr_next       = 0;
            zero_outputs();
        end
        
        // default
        else begin
            cycle_in_instr_next       = 0;
            zero_outputs();
            
            $display("WARNING: unknown R-Type instruction with opcode %b at time %0t.\n", opcode, $time);
        end
    end

endmodule
