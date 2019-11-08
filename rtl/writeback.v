module writeback #(parameter OPCODE_WIDTH    =  4,
                             PMEM_ADDR_WIDTH = 12,
                             PMEM_WORD_WIDTH = 16,
                             IALU_WORD_WIDTH = 16,
                             REG_IDX_WIDTH   =  4,
                             PC_WIDTH        = 12)
           (
           input                         clock,
           input                         reset,
           input                         in_act_write_res_to_reg,
           input  [IALU_WORD_WIDTH-1:0]  in_res,
           input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
           output                        out_act_write_res_to_reg,
           output [IALU_WORD_WIDTH-1:0]  out_res,
           output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx
           );

    reg                        act_write_res_to_reg_sampled;
    reg [IALU_WORD_WIDTH-1:0]  res_sampled;
    reg [  REG_IDX_WIDTH-1:0]  res_reg_idx_sampled;


    assign out_act_write_res_to_reg = in_act_write_res_to_reg;
    assign out_res                  = in_res;
    assign out_res_reg_idx          = in_res_reg_idx;

    
    // Register: sampled inputs (TODO: do we need this?)
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            act_write_res_to_reg_sampled <= in_act_write_res_to_reg;
            res_sampled                  <= res_sampled;
            res_reg_idx_sampled          <= res_reg_idx_sampled;
        end
        else begin
            act_write_res_to_reg_sampled <= 0;
            res_sampled                  <= 0;
            res_reg_idx_sampled          <= 0;
        end
    end

endmodule;

