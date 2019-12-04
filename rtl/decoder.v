module decoder #(parameter OPCODE_WIDTH    =  4,
                           PMEM_ADDR_WIDTH = 12,
                           PMEM_WORD_WIDTH = 16,
                           IALU_WORD_WIDTH = 16,
                           REG_IDX_WIDTH   =  4,
                           PC_WIDTH        = 12)
       (
       input                         clock,
       input                         reset,
       input                         in_flush,
       input  [PMEM_WORD_WIDTH-1:0]  in_instr,
       input  [       PC_WIDTH-1:0]  in_pc,
       input  [IALU_WORD_WIDTH-1:0]  in_src1,
       input  [IALU_WORD_WIDTH-1:0]  in_src2,
       output                        out_act_branch_ialu_res_ff_eq0,
       output                        out_act_branch_ialu_res_ff_gt0,
       output                        out_act_branch_ialu_res_ff_lt0,
       output                        out_act_ialu_add,
       output                        out_act_ialu_neg_src1,
       output                        out_act_incr_pc_is_res,
       output                        out_act_jump_to_ialu_res,
       output                        out_act_load_dmem,
       output                        out_act_store_dmem,
       output                        out_act_write_res_to_reg,
       output                        out_act_write_src2_to_res,
       output                 [2:0]  out_cycle_in_instr,
       output [PMEM_WORD_WIDTH-1:0]  out_instr,
       output [       PC_WIDTH-1:0]  out_pc,
       output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,
       output [IALU_WORD_WIDTH-1:0]  out_src1,
       output [  REG_IDX_WIDTH-1:0]  out_src1_reg_idx,  // to regfile
       output [IALU_WORD_WIDTH-1:0]  out_src2,
       output [  REG_IDX_WIDTH-1:0]  out_src2_reg_idx,  // to regfile
       output [IALU_WORD_WIDTH-1:0]  out_src3
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
    localparam [OPCODE_WIDTH-1:0] OPCODE_ADD    = 4'b0110;
    
    // S-TYPE
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BEQ     = 4'b0000;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BNEQ    = 4'b0001;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BGE     = 4'b0010;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_BLT     = 4'b0011;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_SH      = 4'b0100; // Store half (i.e., 16-bit)
    localparam [ FUNC1_WIDTH-1:0] FUNC1_SHO     = 4'b0101; // Store half (i.e., 16-bit) with offset
    
    // U-TYPE
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LI      = 4'b0011;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LIL     = 4'b0100;

    // J-Type
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JAL     = 4'b0000;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JALR    = 4'b0001;
    
    
    reg                         flush_ff;
    wire [PMEM_WORD_WIDTH-1:0]  instr_1st_word;  // Holds first word of instruction (also for multi-cycle instructions)
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff;        // Current instruction word
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff2;       // Instruction word before current word instruction

    reg  [       PC_WIDTH-1:0]  pc_ff;
    reg  [       PC_WIDTH-1:0]  pc_ff2;

    reg  [PMEM_ADDR_WIDTH-1:0]  jump_offset;

    reg  [                2:0]  cycle_in_instr_next;
    reg  [                2:0]  cycle_in_instr_ff;

    
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
    assign out_cycle_in_instr = cycle_in_instr_ff; 
    assign out_instr          = instr_ff;
    assign out_pc             = pc_ff;
    assign out_res_reg_idx    = instr_1st_word[7:4];
    assign out_src1_reg_idx   = src1_reg_idx; // TODO: null me when i am not needed
    assign out_src2_reg_idx   = src2_reg_idx; // TODO: null me when i am not needed

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

    // Helper function: set all output to zero
    task zero_outputs;
        out_act_branch_ialu_res_ff_eq0  = 0;
        out_act_branch_ialu_res_ff_gt0  = 0;
        out_act_branch_ialu_res_ff_lt0  = 0;
        out_act_ialu_add                = 0;
        out_act_ialu_neg_src1           = 0;
        out_act_incr_pc_is_res          = 0;
        out_act_jump_to_ialu_res        = 0;
        out_act_load_dmem               = 0;
        out_act_store_dmem              = 0;
        out_act_write_res_to_reg        = 0;
        out_act_write_src2_to_res       = 0;
        out_src1                        = 0;
        out_src2                        = 0;
        out_src3                        = 0;
    endtask;

    // Decode instruction word
    always @(*)
    begin
        // Flush
        if (flush_ff == 1) begin
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
                        out_act_ialu_neg_src1                  = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_act_write_src2_to_res              = 1;
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
                        out_act_ialu_neg_src1                  = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_act_write_src2_to_res              = 1;
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
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_act_write_src2_to_res              = 0;
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src1                  = 1;
                        out_src1                               = in_src1;
                        out_src2                               = in_src2;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src1                  = 0;
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
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_act_write_src2_to_res              = 0;
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src1                  = 1;
                        out_src1                               = in_src1;
                        out_src2                               = in_src2;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src1                  = 0;
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
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_act_write_src2_to_res              = 0;
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src1                  = 1;
                        out_src1                               = in_src1;
                        out_src2                               = in_src2;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src1                  = 0;
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
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 0;
                        out_act_write_src2_to_res              = 0;
                    
                    // 1st cycle (evaluate branch condition)
                    if (cycle_in_instr_ff == 0) begin
                        cycle_in_instr_next                    = 1;
                        out_act_ialu_neg_src1                  = 1;
                        out_src1                               = in_src1;
                        out_src2                               = in_src2;
                        out_src3                               = 0;
                    end
                    // 2nd cycle (compute branch target address)
                    else if (cycle_in_instr_ff == 1) begin
                        cycle_in_instr_next                    = 0;
                        out_act_ialu_neg_src1                  = 0;
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
                        out_act_ialu_neg_src1                  = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 1;
                        out_act_write_res_to_reg               = 0;
                        out_act_write_src2_to_res              = 1;
                        out_src1                               = 0;        // base addr
                        out_src2                               = in_src2;  // offset
                        out_src3                               = in_src1;  // value;
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
                        out_act_ialu_neg_src1                  = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 1;
                        out_act_write_res_to_reg               = 0;
                        out_act_write_src2_to_res              = 0;
                        out_src1                               = immB;     // base addr
                        out_src2                               = in_src2;  // offset
                        out_src3                               = in_src1;  // value
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
                        out_act_ialu_neg_src1                  = 0;
                        out_act_incr_pc_is_res                 = 1;
                        out_act_jump_to_ialu_res               = 1;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_act_write_src2_to_res              = 0;
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
                        out_act_ialu_neg_src1                  = 0;
                        out_act_incr_pc_is_res                 = 1;
                        out_act_jump_to_ialu_res               = 1;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_act_write_src2_to_res              = 0;
                        out_src1                               = in_src1;
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
                out_act_ialu_neg_src1                  = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 1;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_act_write_src2_to_res              = 1;
                out_src1                               = 0;
                out_src2                               = in_src1;      // address (yes, strange to write src1 to src2, but srcX_to_res only exists for src2)
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
                out_act_ialu_neg_src1                  = 0;
                out_act_incr_pc_is_res                 = 0;
                out_act_jump_to_ialu_res               = 0;
                out_act_load_dmem                      = 1;
                out_act_store_dmem                     = 0;
                out_act_write_res_to_reg               = 1;
                out_act_write_src2_to_res              = 0;
                out_src1                               = in_src1;
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
            out_act_ialu_neg_src1                  = 0;
            out_act_incr_pc_is_res                 = 0;
            out_act_jump_to_ialu_res               = 0;
            out_act_load_dmem                      = 0;
            out_act_store_dmem                     = 0;
            out_act_write_res_to_reg               = 1;
            out_act_write_src2_to_res              = 0;
            out_src1                               = in_src1;      // argument 1
            out_src2                               = in_src2;      // argument 2
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
