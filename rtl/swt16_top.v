module swt16_top  #(parameter PMEM_ADDR_WIDTH = 12, 
                              PMEM_WORD_WIDTH = 16,
                              PMEM_NUM_WORDS  = 2048,
                              PMEM_FILE       = "../rtl/hex_program.mem",
                              OPCODE_WIDTH    = 4,
                              REG_IDX_WIDTH   = 4,
                              REG_WORD_WIDTH  = 16,
                              IALU_WORD_WIDTH = 16,
                              PC_WIDTH        = 12,
                              PC_INCREMENT    =  2
                              ) 
                   (input clock,
                    input reset );

   wire                         set_pc;
   wire                         flush_pipeline;
   wire [PMEM_ADDR_WIDTH-1 : 0] new_pc;
   wire [PMEM_ADDR_WIDTH-1 : 0] pc;
   wire [PMEM_WORD_WIDTH-1 : 0] pmem_word;
   wire [PMEM_WORD_WIDTH-1 : 0] instr_IF_DC;
   
   // Connections: DC stage -> EX stage
   wire                         act_ialu_add_DC_EX;
   wire                         act_jump_to_ialu_res_DC_EX;
   wire                         act_write_res_to_reg_DC_EX;
   wire [PMEM_ADDR_WIDTH-1 : 0] pc_DC_EX;
   wire [  REG_IDX_WIDTH-1 : 0] res_reg_idx_DC_EX;
   wire [IALU_WORD_WIDTH-1 : 0] src1_DC_EX;
   wire [IALU_WORD_WIDTH-1 : 0] src2_DC_EX;

   // Connections: EX stage -> MEM stage
   wire                         act_write_res_to_reg_EX_MEM;
   wire [IALU_WORD_WIDTH-1 : 0] res_EX_MEM;
   wire [  REG_IDX_WIDTH-1 : 0] res_reg_idx_EX_MEM;

   // Connections: MEM stage -> WB stage
   wire                         act_write_res_to_reg_MEM_WB;
   wire [IALU_WORD_WIDTH-1 : 0] res_MEM_WB;
   wire [  REG_IDX_WIDTH-1 : 0] res_reg_idx_MEM_WB;
   
   // Register file
   wire [REG_IDX_WIDTH-1   : 0] src1_idx;
   wire [REG_IDX_WIDTH-1   : 0] src2_idx;
   wire [REG_IDX_WIDTH-1   : 0] dst_idx;
   wire [REG_WORD_WIDTH-1  : 0] src1;
   wire [REG_WORD_WIDTH-1  : 0] src2;
   wire [REG_WORD_WIDTH-1  : 0] dst;
   wire                         reg_write;
   
   
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
      .in_addr     ( pc ),
      .out_word    ( pmem_word )
   );

   // Fetch stage with programm counter
   fetch #(.PC_WIDTH    (PC_WIDTH       ),
           .PMEM_WIDTH  (PMEM_WORD_WIDTH),
           .PC_INCREMENT(PC_INCREMENT   )  ) fetch_inst
   (
      .clock     ( clock ),
      .reset     ( reset ),
      .in_new_pc ( new_pc ),
      .in_set_pc ( set_pc ),
      .in_flush  ( flush_pipeline ),
      .in_instr  ( pmem_word ),
      .out_instr ( instr_IF_DC ),
      .out_pc    ( pc )
   );

   // Instruction decoder
   decoder #(.OPCODE_WIDTH   (OPCODE_WIDTH   ),
             .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
             .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
             .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
             .REG_IDX_WIDTH  (REG_IDX_WIDTH  ),
             .PC_WIDTH       (PC_WIDTH       )) decoder_inst
   (
      .clock                     ( clock ),
      .reset                     ( reset ),
      .in_instr                  ( instr_IF_DC ),
      .in_pc                     ( pc ),
      .in_flush                  ( flush_pipeline ),
      .out_res_reg_idx           ( res_reg_idx_DC_EX ),
      .out_src1                  ( src1_DC_EX ),
      .out_src2                  ( src2_DC_EX ),
      .out_act_ialu_add          ( act_ialu_add_DC_EX ),
      .out_act_jump_to_ialu_res  ( act_jump_to_ialu_res_DC_EX ),
      .out_act_write_res_to_reg  ( act_write_res_to_reg_DC_EX ),
      .out_pc                    ( pc_DC_EX )
   );

   // Execution stage
   exec    #(.OPCODE_WIDTH   (OPCODE_WIDTH   ),
             .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
             .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
             .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
             .REG_IDX_WIDTH  (REG_IDX_WIDTH  ),
             .PC_WIDTH       (PC_WIDTH       )) exec_inst
   (
       .clock                    ( clock ),
       .reset                    ( reset ),
       .in_act_ialu_add          ( act_ialu_add_DC_EX ),
       .in_act_jump_to_ialu_res  ( act_jump_to_ialu_res_DC_EX ),
       .in_act_write_res_to_reg  ( act_write_res_to_reg_DC_EX ),
       .in_pc                    ( pc_DC_EX ),
       .in_res_reg_idx           ( res_reg_idx_DC_EX ),
       .in_src1                  ( src1_DC_EX ),
       .in_src2                  ( src2_DC_EX ),
       .out_act_write_res_to_reg ( act_write_res_to_reg_EX_MEM ),
       .out_flush                ( flush_pipeline ),
       .out_new_pc               ( new_pc ),
       .out_res                  ( res_EX_MEM ),
       .out_res_reg_idx          ( res_reg_idx_EX_MEM ),
       .out_set_pc               ( set_pc )
   );

   // Memory stage
   mem     #(.OPCODE_WIDTH   (OPCODE_WIDTH   ),
             .PMEM_ADDR_WIDTH(PMEM_ADDR_WIDTH),
             .PMEM_WORD_WIDTH(PMEM_WORD_WIDTH),
             .IALU_WORD_WIDTH(IALU_WORD_WIDTH),
             .REG_IDX_WIDTH  (REG_IDX_WIDTH  ),
             .PC_WIDTH       (PC_WIDTH       )) mem_inst
   (
       .clock                    ( clock ),
       .reset                    ( reset ),
       .in_act_write_res_to_reg  ( act_write_res_to_reg_EX_MEM ),
       .in_res                   ( res_EX_MEM ),
       .in_res_reg_idx           ( res_reg_idx_EX_MEM ),
       .out_act_write_res_to_reg ( act_write_res_to_reg_MEM_WB ),
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
       .in_res                   ( res_MEM_WB ),
       .in_res_reg_idx           ( res_reg_idx_MEM_WB ),
       .out_act_write_res_to_reg ( reg_write ),
       .out_res                  ( dst ),
       .out_res_reg_idx          ( dst_idx )
   );

endmodule

