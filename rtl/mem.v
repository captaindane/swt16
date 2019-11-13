module mem #(parameter OPCODE_WIDTH    =  4,
                       DMEM_ADDR_WIDTH = 12,
                       DMEM_WORD_WIDTH = 16,
                       IALU_WORD_WIDTH = 16,
                       REG_IDX_WIDTH   =  4,
                       PC_WIDTH        = 12)
           (
           input                         clock,
           input                         reset,
           input                         in_act_load_dmem,
           input                         in_act_store_dmem,
           input                         in_act_write_res_to_reg,
           input  [DMEM_ADDR_WIDTH-1:0]  in_mem_rd_addr;
           input  [DMEM_WORD_WIDTH-1:0]  in_mem_rd_word;
           input  [DMEM_ADDR_WIDTH-1:0]  in_mem_wr_addr;
           input  [DMEM_WORD_WIDTH-1:0]  in_mem_wr_word;
           input  [IALU_WORD_WIDTH-1:0]  in_res,
           input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
           output                        out_act_write_res_to_reg,
           output [DMEM_ADDR_WIDTH-1:0]  out_mem_rd_addr;
           output [DMEM_ADDR_WIDTH-1:0]  out_mem_wr_addr;
           output [DMEM_WORD_WIDTH-1:0]  out_mem_wr_word;
           output                        out_mem_write_en;
           output [IALU_WORD_WIDTH-1:0]  out_res,
           output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx
           );

    // Sampled CTRL inputs
    reg act_load_dmem_sampled;
    reg act_store_dmem_sampled;

    // Sampled data inputs
    reg [IALU_WORD_WIDTH-1:0] in_res_sampled;

    // Wiring: write address, write word, and write enable to DMEM
    assign out_mem_wr_addr  = in_mem_wr_addr;
    assign out_mem_wr_word  = in_mem_wr_word;
    assign out_mem_write_en = in_act_store_dmem;

    
    // Register: pass through
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            in_res_sampled           <= in_res;
            out_act_write_res_to_reg <= in_act_write_res_to_reg;
            out_res_reg_idx          <= in_res_reg_idx;
        end
        else begin
            in_res_sampled           <= 0;
            out_act_write_res_to_reg <= 0;
            out_res_reg_idx          <= 0;
        end
    end

    // Register: sample control inputs
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            act_load_dmem_sampled  <= in_act_load_dmem;
            act_store_dmem_sampled <= in_act_store_dmem;
        end
        else begin
            act_load_dmem_sampled  <= 0;
            act_store_dmem_sampled <= 0;
        end
    end

    // Load/store logic
    always @(*)
    begin
        if (act_load_dmem_sampled == 1) begin
            out_res = in_rd_word;
        end
        else begin
            out_res = in_res_sampled;
        end
    end

endmodule;

