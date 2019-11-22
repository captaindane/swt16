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
       output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,
       output [IALU_WORD_WIDTH-1:0]  out_src1,
       output [  REG_IDX_WIDTH-1:0]  out_src1_reg_idx,  // to regfile
       output [IALU_WORD_WIDTH-1:0]  out_src2,
       output [  REG_IDX_WIDTH-1:0]  out_src2_reg_idx,  // to regfile
       output                        out_act_ialu_add,
       output                        out_act_incr_pc_is_res,
       output                        out_act_jump_to_ialu_res,
       output                        out_act_load_dmem,
       output                        out_act_store_dmem,
       output                        out_act_write_res_to_reg,
       output                        out_act_write_src2_to_res,
       output [PMEM_WORD_WIDTH-1:0]  out_instr,
       output [       PC_WIDTH-1:0]  out_pc
       );

    localparam IMMA_WIDTH  = 4;
    localparam IMMB_WITHD  = 16;
    localparam FUNC1_WIDTH = 4;
    localparam FUNC2_WIDTH = 4;
    localparam FUNC3_WIDTH = 4;
    
    localparam [OPCODE_WIDTH-1:0] OPCODE_NOP    = 4'b0000; 
    localparam [OPCODE_WIDTH-1:0] OPCODE_U_TYPE = 4'b0001;
    localparam [OPCODE_WIDTH-1:0] OPCODE_J_TYPE = 4'b0010;
    localparam [OPCODE_WIDTH-1:0] OPCODE_S_TYPE = 4'b0011;
    localparam [OPCODE_WIDTH-1:0] OPCODE_LH     = 4'b0100; // I-TYPE

    // S-TYPE
    localparam [ FUNC1_WIDTH-1:0] FUNC1_JRZ     = 4'b0000;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_JRNZ    = 4'b0001;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_SH      = 4'b0010;
    
    // U-TYPE
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LI      = 4'b0011;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LIL     = 4'b0100;

    // J-Type
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JAL     = 4'b0000;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JALR    = 4'b0001;
    
    
    wire [PMEM_WORD_WIDTH-1:0]  instr_1st_word;  // Holds first word of instruction (also for multi-cycle instructions)
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff;   // Current instruction word
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff2;  // Instruction word before current word instruction

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
    assign out_src1_reg_idx = src1_reg_idx; // TODO: null me when i am not needed
    assign out_src2_reg_idx = src2_reg_idx; // TODO: null me when i am not needed
    assign out_instr        = instr_ff;
    assign out_pc           = pc_ff;
    assign out_res_reg_idx  = instr_1st_word[7:4];
    

    // Register: index of the current cycle within a multi-cycle instruction
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
            cycle_in_instr_ff <= cycle_in_instr_next;
        else
            cycle_in_instr_ff <= 0;
    end

    // Register: holds the current and last sampled instruction
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            instr_ff  <= in_instr;
            instr_ff2 <= instr_ff;
        end
        else begin
            instr_ff  <= 0;
            instr_ff2 <= 0;
        end
    end

    // Register: sample PC
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            pc_ff  <= in_pc;
            pc_ff2 <= pc_ff;
        end
        else begin
            pc_ff  <= 0;
            pc_ff2 <= 0;
        end
    end

    // Multiplexer: Hold first instruction word in case of 2-cycle instruction
    assign instr_1st_word = (cycle_in_instr_ff == 0) ? instr_ff : instr_ff2;

    // Helper function: set all output to zero
    task zero_outputs;
        out_act_ialu_add             = 0;
        out_act_incr_pc_is_res       = 0;
        out_act_jump_to_ialu_res     = 0;
        out_act_load_dmem            = 0;
        out_act_store_dmem           = 0;
        out_act_write_res_to_reg     = 0;
        out_act_write_src2_to_res    = 0;
        out_src1                     = 0;
        out_src2                     = 0;
    endtask;

    // Decode instruction word
    always @(*)
    begin
        // Flush
        if (in_flush) begin
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
                        out_act_ialu_add                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_act_write_src2_to_res              = 1;
                        out_src1                               = 0;
                        out_src2                               = immB;
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
                        out_act_ialu_add                       = 0;
                        out_act_incr_pc_is_res                 = 0;
                        out_act_jump_to_ialu_res               = 0;
                        out_act_load_dmem                      = 0;
                        out_act_store_dmem                     = 0;
                        out_act_write_res_to_reg               = 1;
                        out_act_write_src2_to_res              = 1;
                        out_src1                               = 0;
                        out_src2[IMMA_WIDTH-1:0]               = immA;
                        out_src2[IALU_WORD_WIDTH-1:IMMA_WIDTH] = 0;
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
                
                // Store half
                FUNC1_SH:
                begin
                    cycle_in_instr_next       = 0;

                    out_act_ialu_add          = 0;
                    out_act_incr_pc_is_res    = 0;
                    out_act_jump_to_ialu_res  = 0;
                    out_act_load_dmem         = 0;
                    out_act_store_dmem        = 1;
                    out_act_write_res_to_reg  = 0;
                    out_act_write_src2_to_res = 1;
                    out_src1                  = in_src1;  // value
                    out_src2                  = in_src2;  // offset
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
                        cycle_in_instr_next                  = 0;
                        out_act_ialu_add                     = 1;
                        out_act_incr_pc_is_res               = 1;
                        out_act_jump_to_ialu_res             = 1;
                        out_act_load_dmem                    = 0;
                        out_act_store_dmem                   = 0;
                        out_act_write_res_to_reg             = 1;
                        out_act_write_src2_to_res            = 0;
                        out_src1                             = immB;
                        out_src2[PC_WIDTH-1:0]               = pc_ff2;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH] = 0;
                    end
                    else begin
                        cycle_in_instr_next                  = 1;
                        zero_outputs();
                    end
                end
                
                // Jump and link by register
                FUNC2_JALR:
                begin
                        cycle_in_instr_next                  = 0;
                        out_act_ialu_add                     = 1;
                        out_act_incr_pc_is_res               = 1;
                        out_act_jump_to_ialu_res             = 1;
                        out_act_load_dmem                    = 0;
                        out_act_store_dmem                   = 0;
                        out_act_write_res_to_reg             = 1;
                        out_act_write_src2_to_res            = 0;
                        out_src1                             = in_src1;
                        out_src2[PC_WIDTH-1:0]               = pc_ff;
                        out_src2[IALU_WORD_WIDTH-1:PC_WIDTH] = 0;
                end

                default:
                begin
                        cycle_in_instr_next                  = 0;
                        zero_outputs();
    
                        $display("WARNING: unknown J-Type instruction with opcode %b, func3 %b at time %0t.\n", opcode, func3, $time);
                end
                
            endcase
        end
    
        // Load from DMEM
        else if (opcode == OPCODE_LH) begin
            cycle_in_instr_next       = 0;
            out_act_ialu_add          = 0;
            out_act_incr_pc_is_res    = 0;
            out_act_jump_to_ialu_res  = 0;
            out_act_load_dmem         = 1;
            out_act_store_dmem        = 0;
            out_act_write_res_to_reg  = 1;
            out_act_write_src2_to_res = 0;
            out_src1                  = in_src1;      // address (comes back from regrile)
            out_src2                  = 0;
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
