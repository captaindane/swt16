module mem #(parameter DMEM_ADDR_WIDTH = 12,
                       DMEM_WORD_WIDTH = 16,
                       IALU_WORD_WIDTH = 16,
                       OPCODE_WIDTH    =  4,
                       PC_WIDTH        = 12,
                       PMEM_ADDR_WIDTH = 12,
                       PMEM_WORD_WIDTH = 16,
                       REG_IDX_WIDTH   =  4)
           (
           input                             clock,
           input                             reset,
           input                             in_act_load_dmem,
           input                             in_act_store_dmem,
           input                             in_act_write_res_to_reg,
           input      [                2:0]  in_cycle_in_instr,
           input      [PMEM_WORD_WIDTH-1:0]  in_instr,
           input                             in_instr_is_bubble,
           input      [DMEM_ADDR_WIDTH-1:0]  in_mem_rd_addr,
           input      [DMEM_WORD_WIDTH-1:0]  in_mem_rd_word,  // from dmem
           input      [DMEM_ADDR_WIDTH-1:0]  in_mem_wr_addr,
           input      [DMEM_WORD_WIDTH-1:0]  in_mem_wr_word,
           input      [       PC_WIDTH-1:0]  in_pc,
           input      [IALU_WORD_WIDTH-1:0]  in_res,
           input      [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
           input                             in_res_valid_MEM,
           output reg                        out_act_write_res_to_reg,
           output reg [                2:0]  out_cycle_in_instr,
           output     [PMEM_WORD_WIDTH-1:0]  out_instr,
           output reg                        out_instr_is_bubble,
           output     [DMEM_ADDR_WIDTH-1:0]  out_mem_rd_addr,
           output     [DMEM_ADDR_WIDTH-1:0]  out_mem_wr_addr,
           output     [DMEM_WORD_WIDTH-1:0]  out_mem_wr_word,
           output                            out_mem_write_en,
           output     [       PC_WIDTH-1:0]  out_pc,
           output     [IALU_WORD_WIDTH-1:0]  out_res,
           output reg [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,
           output reg                        out_res_valid_MEM
           );

    // Sampled CTRL inputs
    reg                         act_load_dmem_ff;
    reg                         act_store_dmem_ff;
    reg  [       PC_WIDTH-1:0]  pc_ff;

    // Sampled data inputs
    reg  [IALU_WORD_WIDTH-1:0]  res_ff;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff;

    // Wiring: write address, write word, and write enable to DMEM
    assign out_mem_rd_addr  = in_mem_rd_addr;
    assign out_mem_wr_addr  = in_mem_wr_addr;
    assign out_mem_wr_word  = in_mem_wr_word;
    assign out_mem_write_en = in_act_store_dmem;

    // Wiring: forwarding sampled instruction, pc
    assign out_instr        = instr_ff;
    assign out_pc           = pc_ff;

    
    // Register: pass through
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            instr_ff                 <= in_instr;
            out_act_write_res_to_reg <= in_act_write_res_to_reg;
            out_cycle_in_instr       <= in_cycle_in_instr;
            out_instr_is_bubble      <= in_instr_is_bubble;
            out_res_reg_idx          <= in_res_reg_idx;
            out_res_valid_MEM        <= in_res_valid_MEM;
            pc_ff                    <= in_pc;
            res_ff                   <= in_res;
        end
        else begin
            instr_ff                 <= 0;
            out_act_write_res_to_reg <= 0;
            out_cycle_in_instr       <= 0;
            out_instr_is_bubble      <= 0;
            out_res_reg_idx          <= 0;
            out_res_valid_MEM        <= 0;
            pc_ff                    <= 0;
            res_ff                   <= 0;
        end
    end

    // Register: sample control inputs
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            act_load_dmem_ff         <= in_act_load_dmem;
            act_store_dmem_ff        <= in_act_store_dmem;
        end
        else begin
            act_load_dmem_ff         <= 0;
            act_store_dmem_ff        <= 0;
        end
    end

    // Load/store logic
    // If we are loading a value from memory and storing it to the regfile, output the word from dmem.
    // Otherwise, output the result value passed by the execute stage.
    always @(*)
    begin
        if (act_load_dmem_ff == 1) begin
            out_res = in_mem_rd_word;
        end
        else begin
            out_res = res_ff;
        end
    end

endmodule;

