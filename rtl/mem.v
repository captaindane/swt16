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
           input                             in_act_load_dmem_byte_signed,
           input                             in_act_load_dmem_byte_unsigned,
           input                             in_act_load_dmem_word,
           input                             in_act_store_dmem_byte,
           input                             in_act_store_dmem_word,
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
    reg                         act_load_dmem_word_ff;
    reg                         act_load_dmem_byte_signed_ff;
    reg                         act_load_dmem_byte_unsigned_ff;
    reg                         act_store_dmem_word_ff;
    reg  [       PC_WIDTH-1:0]  pc_ff;

    // Sampled data inputs
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff;
    reg  [DMEM_ADDR_WIDTH-1:0]  mem_rd_addr_ff;
    reg  [IALU_WORD_WIDTH-1:0]  res_ff;

    // Signales
    reg  [DMEM_WORD_WIDTH-1:0]  mem_postp;

    // Wiring: write address, write word, and write enable to DMEM
    assign out_mem_rd_addr  = in_mem_rd_addr;
    assign out_mem_wr_addr  = in_mem_wr_addr;
    assign out_mem_wr_word  = in_mem_wr_word;
    assign out_mem_write_en = in_act_store_dmem_word;

    // Wiring: forwarding sampled instruction, pc
    assign out_instr        = instr_ff;
    assign out_pc           = pc_ff;

    
    //==============================================
    // Register: pass through
    //==============================================
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

    //==============================================
    // Register: sample control inputs
    //==============================================
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            act_load_dmem_byte_signed_ff   <= in_act_load_dmem_byte_signed;
            act_load_dmem_byte_unsigned_ff <= in_act_load_dmem_byte_unsigned;
            act_load_dmem_word_ff          <= in_act_load_dmem_word;
            act_store_dmem_word_ff         <= in_act_store_dmem_word;
            mem_rd_addr_ff                 <= in_mem_rd_addr;
        end
        else begin
            act_load_dmem_byte_signed_ff   <= 0;
            act_load_dmem_byte_unsigned_ff <= 0;
            act_load_dmem_word_ff          <= 0;
            act_store_dmem_word_ff         <= 0;
            mem_rd_addr_ff                 <= 0;
        end
    end

    //==============================================
    // Load/store logic
    //==============================================
    
    // 3 types of load
    // - entire word
    // - lower byte (w/ or w/o sign extension)
    // - higher byte (w/ or w/o sign extension)
    always @(*)
    begin
        // Load entire word
        if (act_load_dmem_word_ff) begin
            mem_postp = in_mem_rd_word;
        end
        // Load byte
        else begin
            // Fill bits 7..0 with higher or lower byte from memory depending on LSB of address
            if (mem_rd_addr_ff[0] == 0) begin
                mem_postp[7:0] = in_mem_rd_word[7:0];
            end
            else begin
                mem_postp[7:0] = in_mem_rd_word[15:8];
            end
            
            // Fill bits 15..8 with sign extension or zeros depending on load mode
            if (act_load_dmem_byte_signed_ff) begin
                mem_postp[15:8] = {8{in_mem_rd_word[7]}};
            end
            else begin
                mem_postp[15:8] = {8{1'b0}};
            end
        end
    end

    
    // If we are loading a value from memory and storing it to the regfile, output the word from dmem.
    // Otherwise, output the result value passed by the execute stage.
    always @(*)
    begin
        if (act_load_dmem_word_ff | act_load_dmem_byte_signed_ff | act_load_dmem_byte_unsigned_ff) begin
            out_res = mem_postp;
        end
        else begin
            out_res = res_ff;
        end
    end

endmodule;

