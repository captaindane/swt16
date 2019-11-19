module exec #(parameter DMEM_ADDR_WIDTH = 12,
                        DMEM_WORD_WIDTH = 16,
                        IALU_WORD_WIDTH = 16,
                        OPCODE_WIDTH    =  4,
                        PC_INCREMENT    =  2,
                        PC_WIDTH        = 12,
                        PMEM_ADDR_WIDTH = 12,
                        PMEM_WORD_WIDTH = 16,
                        REG_IDX_WIDTH   =  4)
             (
             input                         clock,
             input                         reset,
             input                         in_act_ialu_add,
             input                         in_act_incr_pc_is_res,
             input                         in_act_jump_to_ialu_res,
             input                         in_act_load_dmem,
             input                         in_act_store_dmem,
             input                         in_act_write_res_to_reg,
             input                         in_act_write_src2_to_res,
             input  [PMEM_WORD_WIDTH-1:0]  in_instr,
             input  [       PC_WIDTH-1:0]  in_pc,
             input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
             input  [IALU_WORD_WIDTH-1:0]  in_src1,
             input  [IALU_WORD_WIDTH-1:0]  in_src2,
             output                        out_act_load_dmem,
             output                        out_act_store_dmem,
             output                        out_act_write_res_to_reg,
             output [DMEM_ADDR_WIDTH-1:0]  out_dmem_rd_addr,
             output [DMEM_ADDR_WIDTH-1:0]  out_dmem_wr_addr,
             output [DMEM_WORD_WIDTH-1:0]  out_dmem_wr_word,
             output                        out_flush,
             output [PMEM_WORD_WIDTH-1:0]  out_instr,
             output [PMEM_ADDR_WIDTH-1:0]  out_new_pc,
             output [IALU_WORD_WIDTH-1:0]  out_res,
             output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,
             output                        out_set_pc
             );

    // Sampled inputs
    reg                         act_ialu_add_sampled;
    reg                         act_incr_pc_is_res_sampled;
    reg                         act_jump_to_ialu_res_sampled;
    reg                         act_load_dmem_sampled;
    reg                         act_store_dmem_sampled;
    reg                         act_write_src2_to_res_sampled;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_sampled;

    reg  [       PC_WIDTH-1:0]  pc_sampled;
    reg  [IALU_WORD_WIDTH-1:0]  src1_sampled;
    reg  [IALU_WORD_WIDTH-1:0]  src2_sampled;
    
    // ALU regs
    reg [IALU_WORD_WIDTH-1:0] ialu_res;
    
    
    // Register: sample inputs
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            act_ialu_add_sampled          <= in_act_ialu_add;
            act_incr_pc_is_res_sampled    <= in_act_incr_pc_is_res;
            act_jump_to_ialu_res_sampled  <= in_act_jump_to_ialu_res;
            act_load_dmem_sampled         <= in_act_load_dmem;
            act_store_dmem_sampled        <= in_act_store_dmem;
            act_write_src2_to_res_sampled <= in_act_write_src2_to_res;
            instr_sampled                 <= in_instr;
            pc_sampled                    <= in_pc;
            src1_sampled                  <= in_src1;
            src2_sampled                  <= in_src2;
        end
        else begin
            act_ialu_add_sampled          <= 0;
            act_incr_pc_is_res_sampled    <= 0;
            act_jump_to_ialu_res_sampled  <= 0;
            act_load_dmem_sampled         <= 0;
            act_store_dmem_sampled        <= 0;
            act_write_src2_to_res_sampled <= 0;
            instr_sampled                 <= 0;
            pc_sampled                    <= 0;
            src1_sampled                  <= 0;
            src2_sampled                  <= 0;
        end
    end

    // Register: pass through
    always @(posedge clock or posedge reset) begin
        if (!reset) begin
            out_act_load_dmem        <= in_act_load_dmem;
            out_act_store_dmem       <= in_act_store_dmem;
            out_act_write_res_to_reg <= in_act_write_res_to_reg;
            out_instr                <= in_instr;
            out_res_reg_idx          <= in_res_reg_idx;
        end
        else begin
            out_act_load_dmem        <= 0;
            out_act_store_dmem       <= 0;
            out_act_write_res_to_reg <= 0;
            out_instr                <= 0;
            out_res_reg_idx          <= 0;
        end
    end

    // ALU
    always @(*)
    begin
        // Integer addition
        if (act_ialu_add_sampled) begin
            ialu_res = src1_sampled + src2_sampled;
        end

        // Forward src2 directly to res
        else if (act_write_src2_to_res_sampled) begin
            ialu_res = src2_sampled;
        end
        
        // default: do nothing
        else begin
            ialu_res = 0;
        end
    end

    // JUMP / BRANCH
    always @(*)
    begin
        // Trigger jump after getting 2nd instruction word with immedate target address
        if (act_jump_to_ialu_res_sampled) begin
            out_flush  = 1;
            out_set_pc = 1;
            out_new_pc = ialu_res[PMEM_ADDR_WIDTH-1:0];
        end
        else begin
            out_flush  = 0;
            out_set_pc = 0;
            out_new_pc = 0;
        end
    end

    // Load / store
    always @(*)
    begin
        // Load from memory
        if (act_load_dmem_sampled) begin
            out_dmem_rd_addr = src1_sampled[DMEM_ADDR_WIDTH-1:0];
        end
        else begin
            out_dmem_rd_addr = 0;
        end
        
        // Store to memory
        if (act_store_dmem_sampled) begin
            out_dmem_wr_addr = src2_sampled[DMEM_ADDR_WIDTH-1:0];
            out_dmem_wr_word = src1_sampled;
        end
        else begin
            out_dmem_wr_addr = 0;
            out_dmem_wr_word = 0;
        end
    end
    
    // Multiplexer: forward either IALU result or (to be defined) to result output port
    always @(*)
    begin
        out_res = ialu_res;           
    end

endmodule

