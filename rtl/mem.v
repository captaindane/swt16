module mem #(parameter OPCODE_WIDTH    =  4,
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

    // Register: pass through
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            out_act_write_res_to_reg <= in_act_write_res_to_reg;
            out_res                  <= in_res;
            out_res_reg_idx          <= in_res_reg_idx;
        end
        else begin
            out_act_write_res_to_reg <= 0;
            out_res                  <= 0;
            out_res_reg_idx          <= 0;
        end
    end

endmodule;

