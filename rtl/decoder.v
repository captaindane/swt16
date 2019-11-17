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
    
    localparam [OPCODE_WIDTH-1:0] OPCODE_NOP    = 4'b0000; 
    localparam [OPCODE_WIDTH-1:0] OPCODE_U_TYPE = 4'b0001;
    localparam [OPCODE_WIDTH-1:0] OPCODE_S_TYPE = 4'b0011;
    localparam [OPCODE_WIDTH-1:0] OPCODE_LH     = 4'b0100; // I-TYPE

    localparam [ FUNC1_WIDTH-1:0] FUNC1_JRZ     = 4'b0000;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_JRNZ    = 4'b0001;
    localparam [ FUNC1_WIDTH-1:0] FUNC1_SH      = 4'b0010;
    
    localparam [ FUNC2_WIDTH-1:0] FUNC2_J       = 4'b0000;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JAL     = 4'b0001;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_JR      = 4'b0010;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LI      = 4'b0011;
    localparam [ FUNC2_WIDTH-1:0] FUNC2_LIL     = 4'b0100;
    
    reg  [PMEM_WORD_WIDTH-1:0]  instr_1st_word_sampled;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_1st_word;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_sampled;

    reg  [       PC_WIDTH-1:0]  pc_sampled;
    reg  [       PC_WIDTH-1:0]  pc_sampled2;

    reg  [PMEM_ADDR_WIDTH-1:0]  jump_offset;
    reg                         is_2cycle_instr;

    reg  [                2:0]  cycle_in_instr_next;
    reg  [                2:0]  cycle_in_instr_sampled;

    
    // R-Type instruction segments
    wire [   OPCODE_WIDTH-1:0]  opcode       = instr_1st_word_sampled [OPCODE_WIDTH-1:0];
    wire [  REG_IDX_WIDTH-1:0]  src1_reg_idx = instr_1st_word_sampled [11:8];
    wire [  REG_IDX_WIDTH-1:0]  src2_reg_idx = instr_1st_word_sampled [15:12];

    assign out_src1_reg_idx = src1_reg_idx; // TODO: null me when i am not needed
    assign out_src2_reg_idx = src2_reg_idx; // TODO: null me when i am not needed
    
    
    // I-Type instruction segments
    wire [    FUNC2_WIDTH-1:0]  func1 = instr_1st_word_sampled[7:4];
    
    
    // U-Type instruction segments
    wire [                3:0]  immA  = instr_1st_word_sampled[15:12];
    wire [PMEM_WORD_WIDTH-1:0]  immB  = instr_sampled; // only valid in 2nd cycle of multi-cycle instruction
    wire [    FUNC2_WIDTH-1:0]  func2 = instr_1st_word_sampled[11:8];
    
    
    // Connecting signals to output ports
    assign out_instr        = instr_sampled;
    assign out_pc           = pc_sampled;
    assign out_res_reg_idx  = instr_1st_word_sampled[7:4];
    

    // Register: index of the current cycle within a multi-cycle instruction
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
            cycle_in_instr_sampled <= cycle_in_instr_next;
        else
            cycle_in_instr_sampled <= 0;
    end

    // Register: holds the first word of a multi-cycle instruction
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
            instr_1st_word_sampled <= instr_1st_word;
        else
            instr_1st_word_sampled <= 0;
    end

    // Register: holds the latest instruction
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
            instr_sampled <= in_instr;
        else
            instr_sampled <= 0;
    end

    // Register: sample PC
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            pc_sampled  <= in_pc;
            pc_sampled2 <= pc_sampled;
        end
        else begin
            pc_sampled  <= 0;
            pc_sampled2 <= 0;
        end
    end

    
    // Multiplexer: Hold first instruction word in case of 2-cycle instruction
    always @(*)
    begin
        if (is_2cycle_instr)
            instr_1st_word = instr_sampled;
        else
            instr_1st_word = in_instr;
    end

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

    // Decode 1st instruction word
    always @(*)
    begin
        // Flush
        if (in_flush) begin
            is_2cycle_instr          = 0;
            cycle_in_instr_next      = 0;
            zero_outputs();
        end
        
        // U-Type instructions
        else if (opcode == OPCODE_U_TYPE)
        begin
            case (func2)
                // Jump by immediate
                FUNC2_J:
                begin
                    is_2cycle_instr                          = 1;
                    cycle_in_instr_next                      = 1;
                    
                    if (cycle_in_instr_sampled == 1) begin
                        out_act_ialu_add                     = 1;
                        out_act_incr_pc_is_res               = 0;
                        out_act_jump_to_ialu_res             = 1;
                        out_act_load_dmem                    = 0;
                        out_act_store_dmem                   = 0;
                        out_act_write_res_to_reg             = 0;
                        out_act_write_src2_to_res            = 0;
                        out_src1[PC_WIDTH-1:0]               = pc_sampled2;
                        out_src1[IALU_WORD_WIDTH-1:PC_WIDTH] = 0;
                        out_src2                             = immB;
                    end
                    else begin
                        zero_outputs();
                    end
                end
    
                // Jump and link by immediate
                FUNC2_JAL:
                begin
                    is_2cycle_instr                          = 1;
                    cycle_in_instr_next                      = 1;
                    
                    if (cycle_in_instr_sampled == 1) begin
                        out_act_ialu_add                     = 1;
                        out_act_incr_pc_is_res               = 1;
                        out_act_jump_to_ialu_res             = 1;
                        out_act_load_dmem                    = 0;
                        out_act_store_dmem                   = 0;
                        out_act_write_res_to_reg             = 1;
                        out_act_write_src2_to_res            = 0;
                        out_src1[PC_WIDTH-1:0]               = pc_sampled2;
                        out_src1[IALU_WORD_WIDTH-1:PC_WIDTH] = 0;
                        out_src2                             = immB;
                    end
                    else begin
                        zero_outputs();
                    end
                end

                // Load immediate value to 4 LSBs (no sign extension)
                FUNC2_LIL:
                begin
                    is_2cycle_instr                          = 0;
                    cycle_in_instr_next                      = 0;
                    
                    out_act_ialu_add                         = 0;
                    out_act_incr_pc_is_res                   = 0;
                    out_act_jump_to_ialu_res                 = 0;
                    out_act_load_dmem                        = 0;
                    out_act_store_dmem                       = 0;
                    out_act_write_res_to_reg                 = 1;
                    out_act_write_src2_to_res                = 1;
                    out_src1                                 = 0;
                    out_src2[IMMA_WIDTH-1:0]                 = immA;
                    out_src2[IALU_WORD_WIDTH-1:IMMA_WIDTH]   = 0;
                end
                
                //
                default:
                begin
                    is_2cycle_instr          = 0;
                    cycle_in_instr_next      = 0;
                    zero_outputs();

                    $display("WARNING: unknown U-Type instruction with opcode %b, func2 %b\n", opcode, func2);
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
                    is_2cycle_instr           = 0;
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
                    is_2cycle_instr           = 0;
                    cycle_in_instr_next       = 0;
                    zero_outputs();

                    $display("WARNING: unknown S-Type instruction with opcode %b, func1 %b\n", opcode, func1);
                end
                
            endcase
        end
    
        // Load from DMEM
        else if (opcode == OPCODE_LH) begin
            is_2cycle_instr     = 0;
            cycle_in_instr_next = 0;

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
            is_2cycle_instr     = 0;
            cycle_in_instr_next = 0;
            zero_outputs();
        end
        
        // default
        else begin
            is_2cycle_instr     = 0;
            cycle_in_instr_next = 0;
            zero_outputs();
            
            $display("WARNING: unknown R-Type instruction with opcode %b\n", opcode);
        end
    end

endmodule
