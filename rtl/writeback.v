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
           input  [PMEM_WORD_WIDTH-1:0]  in_instr,
           input  [       PC_WIDTH-1:0]  in_pc,
           input  [IALU_WORD_WIDTH-1:0]  in_res,
           input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
           output                        out_act_write_res_to_reg,
           output [IALU_WORD_WIDTH-1:0]  out_res,
           output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx
           );

    reg                        act_write_res_to_reg_sampled;
    reg [PMEM_WORD_WIDTH-1:0]  instr_ff;
    reg [       PC_WIDTH-1:0]  pc_ff;
    reg [IALU_WORD_WIDTH-1:0]  res_sampled;
    reg [  REG_IDX_WIDTH-1:0]  res_reg_idx_sampled;


    assign out_act_write_res_to_reg = in_act_write_res_to_reg;
    assign out_res                  = in_res;
    assign out_res_reg_idx          = in_res_reg_idx;

    
    // Register: sampled inputs (TODO: do we need all of them?)
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            act_write_res_to_reg_sampled <= in_act_write_res_to_reg;
            instr_ff                     <= in_instr;
            pc_ff                        <= in_pc;
            res_sampled                  <= res_sampled;
            res_reg_idx_sampled          <= res_reg_idx_sampled;
        end
        else begin
            act_write_res_to_reg_sampled <= 0;
            instr_ff                     <= 0;
            pc_ff                        <= 0;
            res_sampled                  <= 0;
            res_reg_idx_sampled          <= 0;
        end
    end

endmodule;

