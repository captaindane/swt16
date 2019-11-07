module decoder #(parameter OPCODE_WIDTH    =  4,
                           PMEM_ADDR_WIDTH = 12,
                           PMEM_WORD_WIDTH = 16,
                           IALU_WORD_WIDTH = 16,
                           REG_IDX_WIDTH   =  4,
                           PC_WIDTH        = 12)
       (
       input                         clock,
       input                         reset,
       input  [PMEM_WORD_WIDTH-1:0]  in_instr,
       input  [PC_WIDTH-1:0       ]  in_pc,
       output [IALU_WORD_WIDTH-1:0]  out_src1,
       output [IALU_WORD_WIDTH-1:0]  out_src2,
       output                        out_act_ialu_add,
       output                        out_act_jump_to_ialu_res,
       output [PC_WIDTH-1:0       ]  out_pc
       );

    reg  [PMEM_WORD_WIDTH-1:0]  instr_1st_word_sampled;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_1st_word;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_sampled;

    reg  [PC_WIDTH-1:0       ]  pc_sampled;
    reg  [PC_WIDTH-1:0       ]  pc_sampled2;

    reg  [PMEM_ADDR_WIDTH-1:0]  jump_offset;
    reg                         store_pc_incr; // TODO: Am I needed?
    reg                         is_2cycle_instr;

    reg  [2:0]                  cycle_in_instr_next;
    reg  [2:0]                  cycle_in_instr_sampled;

    wire [OPCODE_WIDTH-1:0]     opcode;
    
    // R-Type instruction segments
    wire [REG_IDX_WIDTH-1:0]    src1_reg_idx;
    wire [REG_IDX_WIDTH-1:0]    src2_reg_idx;
    wire [REG_IDX_WIDTH-1:0]    dst_reg_idx;

    // U-Type instruction segments
    wire [3:0]                  immA;
    wire [PMEM_WORD_WIDTH-1:0]  immB;
    wire [3:0]                  func2;
    
    assign opcode       = instr_1st_word_sampled[OPCODE_WIDTH-1:0];
    assign out_pc       = pc_sampled;
    
    // R-Type instruction segments
    assign dst_reg_idx  = instr_1st_word_sampled[7:4];
    assign src1_reg_idx = instr_1st_word_sampled[11:8];
    assign src2_reg_idx = instr_1st_word_sampled[15:12];

    // U-Type instruction segments
    assign func2        = instr_1st_word_sampled[11:8];
    assign immB         = instr_sampled; // only valid in 2nd cycle of multi-cycle instruction


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

    // Decode 1st instruction word
    always @(*)
    begin
        // U-Type instructions
        if (opcode == 4'b0001)
        begin
            case (func2)
                // Jump by immediate
                4'b0000:
                begin
                    store_pc_incr                            = 0;
                    is_2cycle_instr                          = 1;
                    cycle_in_instr_next                      = 1;
                    
                    if (cycle_in_instr_sampled == 1)
                    begin
                        out_act_ialu_add                     = 1;
                        out_act_jump_to_ialu_res             = 1;
                        out_src1[PC_WIDTH-1:0]               = pc_sampled2;
                        out_src1[IALU_WORD_WIDTH-1:PC_WIDTH] = 0;
                        out_src2                             = immB;
                    end
                    else
                    begin
                        out_act_ialu_add                     = 0;
                        out_act_jump_to_ialu_res             = 0;
                        out_src1                             = 0;
                        out_src2                             = 0;
                    end
                end
    
                // Jump and link by immediate
                4'b0001:
                begin
                    store_pc_incr                            = 1;
                    is_2cycle_instr                          = 1;
                    cycle_in_instr_next                      = 1;
                    
                    if (cycle_in_instr_sampled == 1)
                    begin
                        out_act_ialu_add                     = 1;
                        out_act_jump_to_ialu_res             = 1;
                        out_src1[PC_WIDTH-1:0]               = pc_sampled2;
                        out_src1[IALU_WORD_WIDTH-1:PC_WIDTH] = 0;
                        out_src2                             = immB;
                    end
                    else
                    begin
                        out_act_ialu_add                     = 0;
                        out_act_jump_to_ialu_res             = 0;
                        out_src1                             = 0;
                        out_src2                             = 0;
                    end
                end

                //
                default:
                begin
                    store_pc_incr            = 1;
                    is_2cycle_instr          = 0;
                    cycle_in_instr_next      = 0;
                    out_act_ialu_add         = 0;
                    out_act_jump_to_ialu_res = 0;
                    out_src1                 = 0;
                    out_src2                 = 0;
                end
            endcase
        end
    
        // Default
        else begin
            store_pc_incr       = 0;
            is_2cycle_instr     = 0;
            cycle_in_instr_next = 0;
            out_act_ialu_add    = 0;
            out_src1            = 0;
            out_src2            = 0;
        end
    end

endmodule
