module exec #(parameter OPCODE_WIDTH    =  4,
                        PMEM_ADDR_WIDTH = 12,
                        PMEM_WORD_WIDTH = 16,
                        IALU_WORD_WIDTH = 16,
                        REG_IDX_WIDTH   =  4,
                        PC_WIDTH        = 12)
             (
             input                         clock,
             input                         reset,
             input                         in_act_ialu_add,
             input                         in_act_jump_to_ialu_res,
             input  [IALU_WORD_WIDTH-1:0]  in_src1,
             input  [IALU_WORD_WIDTH-1:0]  in_src2,
             input  [PC_WIDTH-1       :0]  in_pc,
             output [IALU_WORD_WIDTH-1:0]  out_res,
             output                        out_flush,
             output                        out_set_pc,
             output [PMEM_ADDR_WIDTH-1:0]  out_new_pc
             );

    reg [IALU_WORD_WIDTH-1:0] src1_sampled;
    reg [IALU_WORD_WIDTH-1:0] src2_sampled;
    reg                       act_ialu_add_sampled;
    reg                       act_jump_to_ialu_res_sampled;
    
    // Register: sample inputs
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
        begin
            src1_sampled                 <= in_src1;
            src2_sampled                 <= in_src2;
            act_ialu_add_sampled         <= in_act_ialu_add;
            act_jump_to_ialu_res_sampled <= in_act_jump_to_ialu_res;
        end
        else
        begin
            src1_sampled                 <= 0;
            src2_sampled                 <= 0;
            act_ialu_add_sampled         <= 0;
            act_jump_to_ialu_res_sampled <= 0;
        end
    end

    // ALU
    always @(*)
    begin
        // Integer addition
        if (act_ialu_add_sampled)
        begin
            out_res = src1_sampled + src2_sampled;
        end
        
        // default: do nothing
        else
        begin
            out_res = 0;
        end
    end
    
    // JUMP / BRANCH
    always @(*)
    begin
        // Trigger jump after getting 2nd instruction word with immedate target address
        if (act_jump_to_ialu_res_sampled) begin
            out_flush  = 1;
            out_set_pc = 1;
            out_new_pc = out_res[PMEM_ADDR_WIDTH-1:0];
        end
        else begin
            out_flush  = 0;
            out_set_pc = 0;
            out_new_pc = 0;
        end
    end


endmodule

