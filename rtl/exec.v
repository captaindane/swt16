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
             input                         in_act_branch_ialu_res_eq0,
             input                         in_act_branch_ialu_res_gt0,
             input                         in_act_branch_ialu_res_lt0,
             input                         in_act_ialu_add,
             input                         in_act_ialu_neg_src1,
             input                         in_act_incr_pc_is_res,
             input                         in_act_jump_to_ialu_res,
             input                         in_act_load_dmem,
             input                         in_act_store_dmem,
             input                         in_act_write_res_to_reg,
             input                         in_act_write_src2_to_res,
             input  [       PC_WIDTH-1:0]  in_branch_addr,
             input  [PMEM_WORD_WIDTH-1:0]  in_instr,
             input  [       PC_WIDTH-1:0]  in_pc,
             input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
             input  [IALU_WORD_WIDTH-1:0]  in_src1,
             input  [IALU_WORD_WIDTH-1:0]  in_src2,
             output                        out_act_load_dmem,
             output                        out_act_store_dmem,
             output                        out_act_write_res_to_reg,
             output [PMEM_ADDR_WIDTH-1:0]  out_branch_pc,
             output [DMEM_ADDR_WIDTH-1:0]  out_dmem_rd_addr,
             output [DMEM_ADDR_WIDTH-1:0]  out_dmem_wr_addr,
             output [DMEM_WORD_WIDTH-1:0]  out_dmem_wr_word,
             output                        out_flush,
             output [PMEM_WORD_WIDTH-1:0]  out_instr,
             output [       PC_WIDTH-1:0]  out_pc,
             output [IALU_WORD_WIDTH-1:0]  out_res,
             output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,
             output                        out_set_pc
             );

    // TODO: PROCESS NEW INPUTS
    // in_act_branch_ialu_res_eq0
    // in_act_branch_ialu_res_gt0
    // in_act_branch_ialu_res_lt0
    // in_branch_addr
    // in_act_ialu_neg_src1
    
    // Sampled inputs
    reg                         act_ialu_add_ff;
    reg                         act_incr_pc_is_res_ff;
    reg                         act_jump_to_ialu_res_ff;
    reg                         act_load_dmem_ff;
    reg                         act_store_dmem_ff;
    reg                         act_write_src2_to_res_ff;
    reg  [PMEM_WORD_WIDTH-1:0]  instr_ff;
    reg  [       PC_WIDTH-1:0]  pc_ff;
    reg  [IALU_WORD_WIDTH-1:0]  src1_ff;
    reg  [IALU_WORD_WIDTH-1:0]  src2_ff;
    
    // ALU regs
    reg  [IALU_WORD_WIDTH-1:0]  ialu_res;

    assign out_pc = pc_ff;
    
    
    // Register: sample inputs
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            act_ialu_add_ff          <= in_act_ialu_add;
            act_incr_pc_is_res_ff    <= in_act_incr_pc_is_res;
            act_jump_to_ialu_res_ff  <= in_act_jump_to_ialu_res;
            act_load_dmem_ff         <= in_act_load_dmem;
            act_store_dmem_ff        <= in_act_store_dmem;
            act_write_src2_to_res_ff <= in_act_write_src2_to_res;
            instr_ff                 <= in_instr;
            pc_ff                    <= in_pc;
            src1_ff                  <= in_src1;
            src2_ff                  <= in_src2;
        end
        else begin
            act_ialu_add_ff          <= 0;
            act_incr_pc_is_res_ff    <= 0;
            act_jump_to_ialu_res_ff  <= 0;
            act_load_dmem_ff         <= 0;
            act_store_dmem_ff        <= 0;
            act_write_src2_to_res_ff <= 0;
            instr_ff                 <= 0;
            pc_ff                    <= 0;
            src1_ff                  <= 0;
            src2_ff                  <= 0;
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
        if (act_ialu_add_ff) begin
            ialu_res = src1_ff + src2_ff;
        end

        // Forward src2 directly to res
        else if (act_write_src2_to_res_ff) begin
            ialu_res = src2_ff;
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
        if (act_jump_to_ialu_res_ff) begin
            out_flush     = 1;
            out_set_pc    = 1;
            out_branch_pc = ialu_res[PMEM_ADDR_WIDTH-1:0];
        end
        else begin
            out_flush     = 0;
            out_set_pc    = 0;
            out_branch_pc = 0;
        end
    end

    // Load / store
    always @(*)
    begin
        // Load from memory
        if (act_load_dmem_ff) begin
            out_dmem_rd_addr = src1_ff[DMEM_ADDR_WIDTH-1:0];
        end
        else begin
            out_dmem_rd_addr = 0;
        end
        
        // Store to memory
        if (act_store_dmem_ff) begin
            out_dmem_wr_addr = src2_ff[DMEM_ADDR_WIDTH-1:0];
            out_dmem_wr_word = src1_ff;
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

