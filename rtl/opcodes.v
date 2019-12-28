`ifndef _opcodes_v_
`define _opcodes_v_

// Root opcodes
`define OPCODE_NOP     4'b0000  
`define OPCODE_U_TYPE  4'b0001 
`define OPCODE_J_TYPE  4'b0010 
`define OPCODE_S_TYPE  4'b0011 
`define OPCODE_LH      4'b0100  // I-Type: Load half
`define OPCODE_LHO     4'b0101  // I-Type: Load half with offset
`define OPCODE_ADD     4'b0110  // R-Type: integer addition
`define OPCODE_SUB     4'b0111  // R-Type: integer subtraction
`define OPCODE_MUL     4'b1000  // R-Type: integer multiplication
`define OPCODE_SLL     4'b1001  // R-Type: shift left logically
`define OPCODE_SRL     4'b1010  // R-Type: shift right logically
`define OPCODE_SRA     4'b1011  // R-Type: shift right arithmetically
`define OPCODE_AND     4'b1100  // R-Type: logical and
`define OPCODE_OR      4'b1101  // R-Type: logical or
`define OPCODE_XOR     4'b1110  // R-Type: logical xor

// S-TYPE
`define FUNC1_BEQ      4'b0000  // Branch if equal
`define FUNC1_BNEQ     4'b0001  // Branch if not equal
`define FUNC1_BGE      4'b0010  // Branch if greater or equal
`define FUNC1_BLT      4'b0011  // Branch if less than
`define FUNC1_SH       4'b0100  // Store half (i.e., 16-bit)
`define FUNC1_SHO      4'b0101  // Store half (i.e., 16-bit) with offset

// U-TYPE
`define FUNC2_LI       4'b0011  // Load immediate value
`define FUNC2_LIL      4'b0100  // Load LSBs from 4-bit immedate value

// J-Type
`define FUNC2_JAL      4'b0000  // Jump and link
`define FUNC2_JALR     4'b0001  // Jump and link with address from register

// Special instructions
`define INSTR_NOP      {{12{1'b0}}, `OPCODE_NOP}

`endif
 
