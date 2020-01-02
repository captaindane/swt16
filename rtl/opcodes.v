`ifndef _opcodes_v_
`define _opcodes_v_

// Root opcodes
`define OPCODE_NOP     4'b0000  
`define OPCODE_U_TYPE  4'b0001 
`define OPCODE_J_TYPE  4'b0010 
`define OPCODE_S_TYPE  4'b0011 

// I-TYPE
// +-------+-------+-------+-------+
// |  immA |  rs1  |   rd  |  opc  |
// +-------+-------+-------+-------+
// TODO: convert to J-TYPE and delete
`define OPCODE_LH      4'b0100  // I-Type: Load half
`define OPCODE_LHO     4'b0101  // I-Type: Load half with offset

// R-TYPE
// +-------+-------+-------+-------+
// |  rs2  |  rs1  |   rd  |  opc  |
// +-------+-------+-------+-------+
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
// +-------+-------+-------+-------+
// |  rs2  |  rs1  | func1 |  opc  |
// +-------+-------+-------+-------+
// |        immB (optional)        |
// +-------+-------+-------+-------+
`define FUNC1_BEQ      4'b0000  // Branch if equal (PC-relative addressing)
`define FUNC1_BNEQ     4'b0001  // Branch if not equal (PC-relative addressing)
`define FUNC1_BGE      4'b0010  // Branch if greater or equal (PC-relative addressing)
`define FUNC1_BLT      4'b0011  // Branch if less than (PC-relative addressing)
`define FUNC1_SH       4'b0100  // Store half (i.e., 16-bit)
`define FUNC1_SHO      4'b0101  // Store half (i.e., 16-bit) with offset

// U-TYPE
// +-------+-------+-------+-------+
// |  immA | func2 |   rd  |  opc  |
// +-------+-------+-------+-------+
// |        immB (optional)        |
// +-------+-------+-------+-------+
`define FUNC2_INC      4'b0001  // Increment result by 16-bit immediate value
`define FUNC2_INCL     4'b0010  // Increment result by sign-extended 4-bit immediate value
`define FUNC2_LI       4'b0011  // Load immediate value
`define FUNC2_LIL      4'b0100  // Load LSBs from 4-bit immedate value

// J-Type
// +-------+-------+-------+-------+
// | func3 |  rs1  |   rd  |  opc  |
// +-------+-------+-------+-------+
// |        immB (optional)        |
// +-------+-------+-------+-------+
`define FUNC3_JAL      4'b0000  // Jump and link (absolute addressing)
`define FUNC3_JALR     4'b0001  // Jump and link with address from register (absolute addressing)

// Special instructions
`define INSTR_NOP      {{12{1'b0}}, `OPCODE_NOP}

`endif
 
