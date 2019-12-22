module swt16_top  #(parameter DMEM_ADDR_WIDTH = 12, 
                              DMEM_WORD_WIDTH = 16,
                              DMEM_NUM_WORDS  = 2048,
                              DMEM_FILE       = "../prog/_dmem_to_use.txt",
                              
                              PMEM_ADDR_WIDTH = 12, 
                              PMEM_WORD_WIDTH = 16,
                              PMEM_NUM_WORDS  = 2048,
                              PMEM_FILE       = "../prog/_pmem_to_use.txt",
                              
                              OPCODE_WIDTH    = 4,
                              REG_IDX_WIDTH   = 4,
                              REG_WORD_WIDTH  = 16,
                              IALU_WORD_WIDTH = 16,
                              PC_WIDTH        = 12,
                              PC_INCREMENT    =  2
                              ) 
                   (input clock,
                    input dmem_dbg_dump, // debug only, not synthesizable
                    input reset
);

   wire                         set_pc;
   wire                         flush_IF;
   wire                         flush_pipeline; // TODO: better name. differentiate from flush_IF.
   wire [PMEM_ADDR_WIDTH-1 : 0] branch_pc;
   
   // Connections: PMEM
   wire [PMEM_ADDR_WIDTH-1 : 0] pmem_addr;
   wire [PMEM_WORD_WIDTH-1 : 0] pmem_word;
   
   // Connections: DMEM
   wire [DMEM_ADDR_WIDTH-1 : 0] dmem_rd_addr;
   wire [DMEM_WORD_WIDTH-1 : 0] dmem_rd_word; 
   wire [DMEM_ADDR_WIDTH-1 : 0] dmem_wr_addr;
   wire [DMEM_WORD_WIDTH-1 : 0] dmem_wr_word; 
   wire                         dmem_write_en;
  
   // Connections: IF stage -> DC stage
   wire [PMEM_WORD_WIDTH-1 : 0] instr_IF_DC;
   wire [PMEM_ADDR_WIDTH-1 : 0] pc_IF_DC;
   
   // Connections: DC stage -> EX stage
   wire                         act_branch_ialu_res_ff_eq0_DC_EX;
   wire                         act_branch_ialu_res_ff_gt0_DC_EX;
   wire                         act_branch_ialu_res_ff_lt0_DC_EX;
   wire                         act_ialu_add_DC_EX;
   wire                         act_ialu_and_DC_EX;
   wire                         act_ialu_mul_DC_EX;
   wire                         act_ialu_neg_src2_DC_EX;
   wire                         act_ialu_or_DC_EX;
   wire                         act_ialu_sll_DC_EX;
   wire                         act_ialu_sra_DC_EX;
   wire                         act_ialu_srl_DC_EX;
   wire                         act_ialu_write_src2_to_res_DC_EX;
   wire                         act_ialu_xor_DC_EX;
   wire                         act_incr_pc_is_res_DC_EX;
   wire                         act_jump_to_ialu_res_DC_EX;
   wire                         act_load_dmem_DC_EX;
   wire                         act_store_dmem_DC_EX;
   wire                         act_write_res_to_reg_DC_EX;
   wire                 [2 : 0] cycle_in_instr_DC_EX;
   wire [PMEM_WORD_WIDTH-1 : 0] instr_DC_EX;
   wire                         instr_is_bubble_DC_EX;
   wire [PMEM_ADDR_WIDTH-1 : 0] pc_DC_EX;
   wire [  REG_IDX_WIDTH-1 : 0] res_reg_idx_DC_EX;
   wire [IALU_WORD_WIDTH-1 : 0] src1_DC_EX;
   wire [IALU_WORD_WIDTH-1 : 0] src2_DC_EX;
   wire [IALU_WORD_WIDTH-1 : 0] src3_DC_EX;

   // Connections: EX stage -> MEM stage
   wire                         act_load_dmem_EX_MEM;
   wire                         act_store_dmem_EX_MEM;
   wire                         act_write_res_to_reg_EX_MEM;
   wire [DMEM_ADDR_WIDTH-1 : 0] dmem_rd_addr_EX_MEM;
   wire [DMEM_ADDR_WIDTH-1 : 0] dmem_wr_addr_EX_MEM;
   wire [DMEM_WORD_WIDTH-1 : 0] dmem_wr_word_EX_MEM;
   wire [PMEM_WORD_WIDTH-1 : 0] instr_EX_MEM;
   wire [PMEM_ADDR_WIDTH-1 : 0] pc_EX_MEM;
   wire [IALU_WORD_WIDTH-1 : 0] res_EX_MEM;
   wire [  REG_IDX_WIDTH-1 : 0] res_reg_idx_EX_MEM;

   // Connections: MEM stage -> WB stage
   wire                         act_write_res_to_reg_MEM_WB;
   wire [PMEM_WORD_WIDTH-1 : 0] instr_MEM_WB;
   wire [PMEM_ADDR_WIDTH-1 : 0] pc_MEM_WB;
   wire [IALU_WORD_WIDTH-1 : 0] res_MEM_WB;
   wire [  REG_IDX_WIDTH-1 : 0] res_reg_idx_MEM_WB;
   
   // Connections: Register file
   wire [ REG_WORD_WIDTH-1 : 0] dst;
   wire [  REG_IDX_WIDTH-1 : 0] dst_idx;
   wire                         reg_write;
   wire [  REG_IDX_WIDTH-1 : 0] src1_idx;
   wire [  REG_IDX_WIDTH-1 : 0] src2_idx;
   wire [ REG_WORD_WIDTH-1 : 0] src1;
   wire [ REG_WORD_WIDTH-1 : 0] src2;

   // Connections: Bypassing, stalling
   wire                         res_valid_EX_DC;
   wire                         stall_DC_IF;

   // Register file
   regfile #(.IDX_WIDTH(REG_IDX_WIDTH), .WORD_WIDTH(IALU_WORD_WIDTH)) regfile_inst
   (
      .clock       (clock),
      .reset       (reset),
      .in_write    (reg_write),
      .in_src1_idx (src1_idx),
      .in_src2_idx (src2_idx),
      .in_dst_idx  (dst_idx),
      .in_dst      (dst),
      .out_src1    (src1),
      .out_src2    (src2)
   );
   
   // Program memory
   pmem_sim #(.WORD_WIDTH (PMEM_WORD_WIDTH),
              .ADDR_WIDTH (PMEM_ADDR_WIDTH),
              .NUM_WORDS  (PMEM_NUM_WORDS ),
              .PMEM_FILE  (PMEM_FILE      ) ) pmem_sim_inst
   (
      .clock       ( clock ),
      .in_addr     ( pmem_addr ),
      .out_word    ( pmem_word )
   );

   // Data memory
   dmem_sim #(.WORD_WIDTH (DMEM_WORD_WIDTH),
              .ADDR_WIDTH (DMEM_ADDR_WIDTH),
              .NUM_WORDS  (DMEM_NUM_WORDS ),
              .MEM_FILE   (DMEM_FILE      ) ) dmem_sim_inst
   (
      .clock       ( clock ),
      .in_addr_rd  ( dmem_rd_addr  ),
      .in_addr_wr  ( dmem_wr_addr  ),
      .in_dbg_dump ( dmem_dbg_dump ),
      .in_write_en ( dmem_write_en ),
      .in_word     ( dmem_wr_word  ),
      .out_word    ( dmem_rd_word  )

   );

   // Fetch stage with programm counter
   fetch #(.PC_WIDTH    (PC_WIDTH       ),
           .PMEM_WIDTH  (PMEM_WORD_WIDTH),
           .PC_INCREMENT(PC_INCREMENT   )  ) fetch_inst
   (
      .clock         ( clock ),
      .reset         ( reset ),
      .in_branch_pc  ( branch_pc ),
      .in_set_pc     ( set_pc ),
      .in_flush      ( flush_IF ),
      .in_instr      ( pmem_word ),
      .in_stall      ( stall_DC_IF ),
      .out_instr     ( instr_IF_DC ),
      .out_pc        ( pc_IF_DC ),
      .out_pmem_addr ( pmem_addr )
   );

   // Instruction decoder
   decoder #(.OPCODE_WIDTH   (OPCODE_WIDTH   ),
             .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
             .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
             .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
             .REG_IDX_WIDTH  (REG_IDX_WIDTH  ),
             .PC_WIDTH       (PC_WIDTH       )) decoder_inst
   (
      .clock                          ( clock ),
      .reset                          ( reset ),
      .in_flush                       ( flush_pipeline ),
      .in_instr                       ( instr_IF_DC ),
      .in_pc                          ( pc_IF_DC ),
      .in_res_EX                      ( res_EX_MEM ),
      .in_res_MEM                     ( res_MEM_WB ),
      .in_res_reg_idx_EX              ( res_reg_idx_EX_MEM ),
      .in_res_reg_idx_MEM             ( res_reg_idx_MEM_WB ),
      .in_res_valid_EX                ( res_valid_EX_DC ),
      .in_src1                        ( src1 ),
      .in_src2                        ( src2 ),
      .out_act_branch_ialu_res_ff_eq0 ( act_branch_ialu_res_ff_eq0_DC_EX ),
      .out_act_branch_ialu_res_ff_gt0 ( act_branch_ialu_res_ff_gt0_DC_EX ),
      .out_act_branch_ialu_res_ff_lt0 ( act_branch_ialu_res_ff_lt0_DC_EX ),
      .out_act_ialu_add               ( act_ialu_add_DC_EX ),
      .out_act_ialu_and               ( act_ialu_and_DC_EX ),
      .out_act_ialu_mul               ( act_ialu_mul_DC_EX ),
      .out_act_ialu_neg_src2          ( act_ialu_neg_src2_DC_EX ),
      .out_act_ialu_or                ( act_ialu_or_DC_EX ),
      .out_act_ialu_sll               ( act_ialu_sll_DC_EX ),
      .out_act_ialu_sra               ( act_ialu_sra_DC_EX ),
      .out_act_ialu_srl               ( act_ialu_srl_DC_EX ),
      .out_act_ialu_write_src2_to_res ( act_ialu_write_src2_to_res_DC_EX ),
      .out_act_ialu_xor               ( act_ialu_xor_DC_EX ),
      .out_act_incr_pc_is_res         ( act_incr_pc_is_res_DC_EX ),
      .out_act_jump_to_ialu_res       ( act_jump_to_ialu_res_DC_EX ),
      .out_act_load_dmem              ( act_load_dmem_DC_EX ),
      .out_act_store_dmem             ( act_store_dmem_DC_EX ),
      .out_act_write_res_to_reg       ( act_write_res_to_reg_DC_EX ),
      .out_cycle_in_instr             ( cycle_in_instr_DC_EX ),
      .out_instr                      ( instr_DC_EX ),
      .out_instr_is_bubble            ( instr_is_bubble_DC_EX ),
      .out_pc                         ( pc_DC_EX ),
      .out_res_reg_idx                ( res_reg_idx_DC_EX ),
      .out_src1                       ( src1_DC_EX ),
      .out_src1_reg_idx               ( src1_idx ),
      .out_src2                       ( src2_DC_EX ),
      .out_src2_reg_idx               ( src2_idx ),
      .out_src3                       ( src3_DC_EX ),
      .out_stall                      ( stall_DC_IF )
   );

   // Execution stage
   exec    #(.DMEM_ADDR_WIDTH(DMEM_ADDR_WIDTH),
             .DMEM_WORD_WIDTH(DMEM_WORD_WIDTH),
             .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
             .OPCODE_WIDTH   (OPCODE_WIDTH   ),
             .PC_INCREMENT   (PC_INCREMENT   ),
             .PC_WIDTH       (PC_WIDTH       ),
             .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
             .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
             .REG_IDX_WIDTH  (REG_IDX_WIDTH  )) exec_inst
   (
       .clock                         ( clock ),
       .reset                         ( reset ),
       .in_act_branch_ialu_res_ff_eq0 ( act_branch_ialu_res_ff_eq0_DC_EX ),
       .in_act_branch_ialu_res_ff_gt0 ( act_branch_ialu_res_ff_gt0_DC_EX ),
       .in_act_branch_ialu_res_ff_lt0 ( act_branch_ialu_res_ff_lt0_DC_EX ),
       .in_act_ialu_add               ( act_ialu_add_DC_EX ),
       .in_act_ialu_and               ( act_ialu_and_DC_EX ),
       .in_act_ialu_mul               ( act_ialu_mul_DC_EX ),
       .in_act_ialu_neg_src2          ( act_ialu_neg_src2_DC_EX ),
       .in_act_ialu_or                ( act_ialu_or_DC_EX ),
       .in_act_ialu_sll               ( act_ialu_sll_DC_EX ),
       .in_act_ialu_sra               ( act_ialu_sra_DC_EX ),
       .in_act_ialu_srl               ( act_ialu_srl_DC_EX ),
       .in_act_ialu_write_src2_to_res ( act_ialu_write_src2_to_res_DC_EX ),
       .in_act_ialu_xor               ( act_ialu_xor_DC_EX ),
       .in_act_incr_pc_is_res         ( act_incr_pc_is_res_DC_EX ),
       .in_act_jump_to_ialu_res       ( act_jump_to_ialu_res_DC_EX ),
       .in_act_load_dmem              ( act_load_dmem_DC_EX ),
       .in_act_store_dmem             ( act_store_dmem_DC_EX ),
       .in_act_write_res_to_reg       ( act_write_res_to_reg_DC_EX ),
       .in_cycle_in_instr             ( cycle_in_instr_DC_EX ),
       .in_flush                      ( flush_pipeline ),
       .in_instr                      ( instr_DC_EX ),
       .in_instr_is_bubble            ( instr_is_bubble_DC_EX ),
       .in_pc                         ( pc_DC_EX ),
       .in_res_reg_idx                ( res_reg_idx_DC_EX ),
       .in_src1                       ( src1_DC_EX ),
       .in_src2                       ( src2_DC_EX ),
       .in_src3                       ( src3_DC_EX ),
       .out_act_load_dmem             ( act_load_dmem_EX_MEM ),
       .out_act_store_dmem            ( act_store_dmem_EX_MEM ),
       .out_act_write_res_to_reg      ( act_write_res_to_reg_EX_MEM ),
       .out_branch_pc                 ( branch_pc ),
       .out_dmem_rd_addr              ( dmem_rd_addr_EX_MEM ),
       .out_dmem_wr_addr              ( dmem_wr_addr_EX_MEM ),
       .out_dmem_wr_word              ( dmem_wr_word_EX_MEM ),
       .out_flush                     ( flush_pipeline ),
       .out_flush_IF                  ( flush_IF ),
       .out_instr                     ( instr_EX_MEM ),
       .out_pc                        ( pc_EX_MEM ),
       .out_res                       ( res_EX_MEM ),
       .out_res_reg_idx               ( res_reg_idx_EX_MEM ),
       .out_res_valid                 ( res_valid_EX_DC ),
       .out_set_pc                    ( set_pc )
   );

   // Memory stage
   mem     #(.DMEM_ADDR_WIDTH(DMEM_ADDR_WIDTH),
             .DMEM_WORD_WIDTH(DMEM_WORD_WIDTH),
             .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
             .OPCODE_WIDTH   (OPCODE_WIDTH   ),
             .PC_WIDTH       (PC_WIDTH       ),
             .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
             .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
             .REG_IDX_WIDTH  (REG_IDX_WIDTH  )) mem_inst
   (
       .clock                    ( clock ),
       .reset                    ( reset ),
       .in_act_load_dmem         ( act_load_dmem_EX_MEM ),
       .in_act_store_dmem        ( act_store_dmem_EX_MEM ),
       .in_act_write_res_to_reg  ( act_write_res_to_reg_EX_MEM ),
       .in_instr                 ( instr_EX_MEM ),
       .in_mem_rd_addr           ( dmem_rd_addr_EX_MEM ),
       .in_mem_rd_word           ( dmem_rd_word ),
       .in_mem_wr_addr           ( dmem_wr_addr_EX_MEM ),
       .in_mem_wr_word           ( dmem_wr_word_EX_MEM ),
       .in_pc                    ( pc_EX_MEM ),
       .in_res                   ( res_EX_MEM ),
       .in_res_reg_idx           ( res_reg_idx_EX_MEM ),
       .out_act_write_res_to_reg ( act_write_res_to_reg_MEM_WB ),
       .out_instr                ( instr_MEM_WB ),
       .out_mem_rd_addr          ( dmem_rd_addr ),
       .out_mem_wr_addr          ( dmem_wr_addr ),
       .out_mem_wr_word          ( dmem_wr_word ),
       .out_mem_write_en         ( dmem_write_en ),
       .out_pc                   ( pc_MEM_WB ),
       .out_res                  ( res_MEM_WB ),
       .out_res_reg_idx          ( res_reg_idx_MEM_WB )
   );

   // Writeback stage
   writeback #(.OPCODE_WIDTH   (OPCODE_WIDTH   ),
               .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
               .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
               .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
               .REG_IDX_WIDTH  (REG_IDX_WIDTH  ),
               .PC_WIDTH       (PC_WIDTH       )) writeback_inst
   (
       .clock                    ( clock ),
       .reset                    ( reset ),
       .in_act_write_res_to_reg  ( act_write_res_to_reg_MEM_WB ),
       .in_instr                 ( instr_MEM_WB ),
       .in_pc                    ( pc_MEM_WB ),
       .in_res                   ( res_MEM_WB ),
       .in_res_reg_idx           ( res_reg_idx_MEM_WB ),
       .out_act_write_res_to_reg ( reg_write ),
       .out_res                  ( dst ),
       .out_res_reg_idx          ( dst_idx )
   );

endmodule

