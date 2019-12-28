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
             input                         in_act_branch_ialu_res_ff_eq0,
             input                         in_act_branch_ialu_res_ff_gt0,
             input                         in_act_branch_ialu_res_ff_lt0,
             input                         in_act_ialu_add,
             input                         in_act_ialu_and,
             input                         in_act_ialu_mul,
             input                         in_act_ialu_neg_src2,
             input                         in_act_ialu_or,
             input                         in_act_ialu_sll,  // shift left logically
             input                         in_act_ialu_sra,  // shift right arithmetically
             input                         in_act_ialu_srl,  // shift right logically
             input                         in_act_ialu_write_src2_to_res,
             input                         in_act_ialu_xor,
             input                         in_act_incr_pc_is_res,
             input                         in_act_jump_to_ialu_res,
             input                         in_act_load_dmem,
             input                         in_act_store_dmem,
             input                         in_act_write_res_to_reg,
             input                  [2:0]  in_cycle_in_instr,
             input                         in_flush,
             input  [PMEM_WORD_WIDTH-1:0]  in_instr,
             input                         in_instr_is_bubble,
             input  [       PC_WIDTH-1:0]  in_pc,
             input  [  REG_IDX_WIDTH-1:0]  in_res_reg_idx,
             input                         in_res_valid_EX,
             input                         in_res_valid_MEM,
             input  [IALU_WORD_WIDTH-1:0]  in_src1,
             input  [IALU_WORD_WIDTH-1:0]  in_src2,
             input  [IALU_WORD_WIDTH-1:0]  in_src3,
             output                        out_act_load_dmem,
             output                        out_act_store_dmem,
             output                        out_act_write_res_to_reg,
             output [PMEM_ADDR_WIDTH-1:0]  out_branch_pc,
             output                 [2:0]  out_cycle_in_instr,
             output [DMEM_ADDR_WIDTH-1:0]  out_dmem_rd_addr,
             output [DMEM_ADDR_WIDTH-1:0]  out_dmem_wr_addr,
             output [DMEM_WORD_WIDTH-1:0]  out_dmem_wr_word,
             output                        out_flush_DC_and_EX,
             output                        out_flush_IF,
             output [PMEM_WORD_WIDTH-1:0]  out_instr,
             output                        out_instr_is_bubble,
             output [       PC_WIDTH-1:0]  out_pc,
             output [IALU_WORD_WIDTH-1:0]  out_res,
             output [  REG_IDX_WIDTH-1:0]  out_res_reg_idx,
             output                        out_res_valid_EX,
             output                        out_res_valid_MEM,
             output                        out_set_pc
             );

    // Sampled inputs
    reg                                act_branch_ialu_res_ff_eq0_ff;
    reg                                act_branch_ialu_res_ff_gt0_ff;
    reg                                act_branch_ialu_res_ff_lt0_ff;
    reg                                act_ialu_add_ff;
    reg                                act_ialu_and_ff;
    reg                                act_ialu_mul_ff;
    reg                                act_ialu_neg_src2_ff;
    reg                                act_ialu_or_ff;
    reg                                act_ialu_sll_ff;
    reg                                act_ialu_sra_ff;
    reg                                act_ialu_srl_ff;
    reg                                act_ialu_write_src2_to_res_ff;
    reg                                act_ialu_xor_ff;
    reg                                act_incr_pc_is_res_ff;
    reg                                act_jump_to_ialu_res_ff;
    reg                                act_load_dmem_ff;
    reg                                act_store_dmem_ff;
    reg                                act_write_res_to_reg_ff;
    reg                         [2:0]  cycle_in_instr_ff;
    reg                                flush_ff;
    reg         [PMEM_WORD_WIDTH-1:0]  instr_ff;
    reg                                instr_is_bubble_ff;
    reg         [       PC_WIDTH-1:0]  pc_ff;
    reg         [  REG_IDX_WIDTH-1:0]  res_reg_idx_ff;
    reg                                res_valid_EX_ff;
    reg                                res_valid_MEM_ff;
    reg  signed [IALU_WORD_WIDTH-1:0]  src1_ff;
    reg  signed [IALU_WORD_WIDTH-1:0]  src2_ff;
    reg         [IALU_WORD_WIDTH-1:0]  src3_ff;

    // Modified version of src1, src2 (potentially negated)
    wire [IALU_WORD_WIDTH-1:0]  src2_mod;
    assign src2_mod = (act_ialu_neg_src2_ff == 0) ? src2_ff : (~src2_ff + 1'b1);

    // Current instruction is a bubble if
    // - it was marked so by DC
    // - EX issued a self-flush in the previous cycle
    assign out_instr_is_bubble = (instr_is_bubble_ff | flush_ff);
    
    // Inform DC stage whether or not the result of EX stage is valid
    assign out_res_valid_EX    = res_valid_EX_ff;
    assign out_res_valid_MEM   = res_valid_MEM_ff;

    // Forwarding ctrl signals
    assign out_cycle_in_instr  = cycle_in_instr_ff;

    // ALU regs
    reg  [IALU_WORD_WIDTH-1:0]  ialu_res;
    reg  [IALU_WORD_WIDTH-1:0]  ialu_res_ff;
    
    //==============================================
    // Register: sampled inputs
    //==============================================
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            act_branch_ialu_res_ff_eq0_ff <= in_act_branch_ialu_res_ff_eq0;
            act_branch_ialu_res_ff_gt0_ff <= in_act_branch_ialu_res_ff_gt0;
            act_branch_ialu_res_ff_lt0_ff <= in_act_branch_ialu_res_ff_lt0;
            act_ialu_add_ff               <= in_act_ialu_add;
            act_ialu_and_ff               <= in_act_ialu_and;
            act_ialu_mul_ff               <= in_act_ialu_mul;
            act_ialu_neg_src2_ff          <= in_act_ialu_neg_src2;
            act_ialu_or_ff                <= in_act_ialu_or;
            act_ialu_sll_ff               <= in_act_ialu_sll;
            act_ialu_sra_ff               <= in_act_ialu_sra;
            act_ialu_srl_ff               <= in_act_ialu_srl;
            act_ialu_write_src2_to_res_ff <= in_act_ialu_write_src2_to_res;
            act_ialu_xor_ff               <= in_act_ialu_xor;
            act_incr_pc_is_res_ff         <= in_act_incr_pc_is_res;
            act_jump_to_ialu_res_ff       <= in_act_jump_to_ialu_res;
            act_load_dmem_ff              <= in_act_load_dmem;
            act_store_dmem_ff             <= in_act_store_dmem;
            act_write_res_to_reg_ff       <= in_act_write_res_to_reg;
            cycle_in_instr_ff             <= in_cycle_in_instr;
            flush_ff                      <= in_flush;
            instr_ff                      <= in_instr;
            instr_is_bubble_ff            <= in_instr_is_bubble;
            pc_ff                         <= in_pc;
            res_reg_idx_ff                <= in_res_reg_idx;
            res_valid_EX_ff               <= in_res_valid_EX;
            res_valid_MEM_ff              <= in_res_valid_MEM;
            src1_ff                       <= in_src1;
            src2_ff                       <= in_src2;
            src3_ff                       <= in_src3;
        end
        else begin
            act_branch_ialu_res_ff_eq0_ff <= 0;
            act_branch_ialu_res_ff_gt0_ff <= 0;
            act_branch_ialu_res_ff_lt0_ff <= 0;
            act_ialu_add_ff               <= 0;
            act_ialu_and_ff               <= 0;
            act_ialu_mul_ff               <= 0;
            act_ialu_neg_src2_ff          <= 0;
            act_ialu_or_ff                <= 0;
            act_ialu_sll_ff               <= 0;
            act_ialu_sra_ff               <= 0;
            act_ialu_srl_ff               <= 0;
            act_ialu_write_src2_to_res_ff <= 0;
            act_ialu_xor_ff               <= 0;
            act_incr_pc_is_res_ff         <= 0;
            act_jump_to_ialu_res_ff       <= 0;
            act_load_dmem_ff              <= 0;
            act_store_dmem_ff             <= 0;
            act_write_res_to_reg_ff       <= 0;
            cycle_in_instr_ff             <= 0;
            flush_ff                      <= 0;
            instr_ff                      <= 0;
            instr_is_bubble_ff            <= 0;
            pc_ff                         <= 0;
            res_reg_idx_ff                <= 0;
            res_valid_EX_ff               <= 0;
            res_valid_MEM_ff              <= 0;
            src1_ff                       <= 0;
            src2_ff                       <= 0;
            src3_ff                       <= 0;
        end
    end

    //==============================================
    // Multiplexer:
    // Do not forward values along the pipe in case
    // we are flushing.
    //==============================================
    always @(*)
    begin
        if (flush_ff == 0) begin
            out_act_load_dmem        = act_load_dmem_ff;
            out_act_store_dmem       = act_store_dmem_ff;
            out_act_write_res_to_reg = act_write_res_to_reg_ff;
            out_instr                = instr_ff;
            out_pc                   = pc_ff;
            out_res_reg_idx          = res_reg_idx_ff;
        end
        else begin
            out_act_load_dmem        = 0;
            out_act_store_dmem       = 0;
            out_act_write_res_to_reg = 0;
            out_instr                = 0;
            out_pc                   = 0;
            out_res_reg_idx          = 0;

        end
    end

    
    //==============================================
    // ALU
    // - write ialu_res
    //==============================================
    always @(*)
    begin
        // Output zero if stage should be flushed
        if (flush_ff == 1) begin
            ialu_res = 0;
        end
        
        // Integer addition, subtraction
        else if (act_ialu_add_ff) begin
            ialu_res = src1_ff + src2_mod;
        end

        // Integer multiplication
        else if (act_ialu_mul_ff) begin
           ialu_res = src1_ff * src2_mod;
        end

        // Shift left logically
        else if (act_ialu_sll_ff) begin
            ialu_res = src1_ff << src2_mod;
        end

        // Shift right logically
        else if (act_ialu_srl_ff) begin
            ialu_res = src1_ff >> src2_mod;
        end

        // Shift right arithmetically
        else if (act_ialu_sra_ff) begin
            ialu_res = src1_ff >>> src2_mod;
        end

        // Bitwise logical and
        else if (act_ialu_and_ff) begin
            ialu_res = src1_ff & src2_mod;
        end
        
        // Bitwise logcial or
        else if (act_ialu_or_ff) begin
            ialu_res = src1_ff | src2_mod;
        end

        // Bitwise logical xor
        else if (act_ialu_xor_ff) begin
            ialu_res = src1_ff ^ src2_mod;
        end

        // Forward src2 directly to ALU res
        else if (act_ialu_write_src2_to_res_ff) begin
            ialu_res = src2_mod;
        end
        
        // default: do nothing
        else begin
            ialu_res = 0;
        end
    end

    //==============================================
    // Register: sample ialu_res
    // - Some 2-cycle instructions (e.g., branches)
    //   need the result from the previous IALU
    //   cycle.
    //==============================================
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            ialu_res_ff <= ialu_res;
        end
        else begin
            ialu_res_ff <= 0;
        end
    end
    
    //==============================================
    // Jump / Branch
    // - writes: out_flush_DC_and_EX
    //           out_flush_IF
    //           out_set_pc
    //           out_branch_pc
    //==============================================
    always @(*)
    begin
        // Output zero if stage should be flushed
        if (flush_ff == 1) begin
            out_flush_DC_and_EX = 0;
            out_flush_IF        = 0;
            out_set_pc          = 0;
            out_branch_pc       = 0;
        end

        // Trigger jump after getting 2nd instruction word with immedate target address
        else if (act_jump_to_ialu_res_ff) begin
            out_flush_DC_and_EX = 1;
            out_flush_IF        = 1;
            out_set_pc          = 1;
            out_branch_pc       = ialu_res[PMEM_ADDR_WIDTH-1:0];
        end
        
        // All conditional branch instructions (1st cycle)
        // - Flush IF stage in next cycle.
        // - Do not flush DC, EX stage in next cycle. We still have to compute the branch address.
        // - Do not branch, yet.
        else if (    ((cycle_in_instr_ff == 0) && (act_branch_ialu_res_ff_eq0_ff == 1) && (ialu_res == 0))
                  || ((cycle_in_instr_ff == 0) && (act_branch_ialu_res_ff_gt0_ff == 1) && (ialu_res[IALU_WORD_WIDTH-1] == 1'b0) && (ialu_res[IALU_WORD_WIDTH-2:0] != 0))
                  || ((cycle_in_instr_ff == 0) && (act_branch_ialu_res_ff_lt0_ff == 1) && (ialu_res[IALU_WORD_WIDTH-1] == 1'b1))
                )
        begin
            out_flush_DC_and_EX = 0;
            out_flush_IF        = 1;
            out_set_pc          = 0;
            out_branch_pc       = 0;
        end
        
        // All conditional branch instructions (2nd cycle)
        // - Perform actual branch
        else if (    ((cycle_in_instr_ff == 1) && (act_branch_ialu_res_ff_eq0_ff == 1) && (ialu_res_ff == 0))
                  || ((cycle_in_instr_ff == 1) && (act_branch_ialu_res_ff_gt0_ff == 1) && (ialu_res_ff[IALU_WORD_WIDTH-1] == 1'b0) && (ialu_res_ff[IALU_WORD_WIDTH-2:0] != 0))
                  || ((cycle_in_instr_ff == 1) && (act_branch_ialu_res_ff_lt0_ff == 1) && (ialu_res_ff[IALU_WORD_WIDTH-1] == 1'b1))
                )
        begin
            out_flush_DC_and_EX = 1;
            out_flush_IF        = 1;
            out_set_pc          = 1;
            out_branch_pc       = ialu_res[PMEM_ADDR_WIDTH-1:0];
        end
        
        // default: do nothing
        else begin
            out_flush_DC_and_EX = 0;
            out_flush_IF        = 0;
            out_set_pc          = 0;
            out_branch_pc       = 0;
        end
    end

    //==============================================
    // Load / store
    // - writes: out_dmem_rd_addr
    //           out_dmem_wr_addr
    //           out_dmem_wr_word
    //==============================================
    always @(*)
    begin
        // Load from memory
        if (flush_ff == 1) begin
            out_dmem_rd_addr = 0;
        end
        
        else if (act_load_dmem_ff) begin
            out_dmem_rd_addr = ialu_res[DMEM_ADDR_WIDTH-1:0];
        end
        
        else begin
            out_dmem_rd_addr = 0;
        end
        
        // Store to memory
        if (flush_ff == 1) begin
            out_dmem_wr_addr = 0;
            out_dmem_wr_word = 0;
        end
        
        if (act_store_dmem_ff) begin
            out_dmem_wr_addr = ialu_res[DMEM_ADDR_WIDTH-1:0];
            out_dmem_wr_word = src3_ff;
        end
        
        else begin
            out_dmem_wr_addr = 0;
            out_dmem_wr_word = 0;
        end
    end
    
    // Multiplexer: forward either IALU result or incremented PC to result output port
    always @(*)
    begin
        if (act_incr_pc_is_res_ff) begin
            out_res = pc_ff+PC_INCREMENT;
        end
        else begin
            out_res = ialu_res;           
        end
    end

endmodule

