//           | in_branch_pc
//           |
//     +-----|-----+----------------------+
//     |     |     | + PC_INCREMENT       |
//     |     V     V                      |
//     |   +---------+                    |
//     |   \_________/                    |
//     |        |                         |
//     |        | pc_next                 | out_pmem_addr
//     |        V                         V
//     |   +---------+              +-------------+
//     |   |>  PC    |              | program mem |
//     |   +---------+              +-------------+
//     |        |                         | in_instr
//     ---------+ pc_ff                   | out_instr 
//              |                         |
//              V out_pc                  V
//  +--------------------------------------------+
//  |>                 FE -> DC                  |
//  +--------------------------------------------+

module fetch #(parameter PC_WIDTH=12, PMEM_WIDTH=16, PC_INCREMENT=2)
           (
            input                    clock,
            input                    reset,
            input                    in_flush,
            input  [PMEM_WIDTH-1:0]  in_instr,
            input  [  PC_WIDTH-1:0]  in_branch_pc,
            input                    in_set_pc,    // Are we setting a new PC via "in_branch_pc"?
            output [PMEM_WIDTH-1:0]  out_instr,
            output [  PC_WIDTH-1:0]  out_pc,       // This goes to the pipeline (i.e., DC stage)
            output [  PC_WIDTH-1:0]  out_pmem_addr // This goes to the program memory
           );

    reg  [PC_WIDTH-1:0] pc_next;
    reg  [PC_WIDTH-1:0] pc_next_int;
    wire [PC_WIDTH-1:0] pc_next_ext;
    reg  [PC_WIDTH-1:0] pc_ff;
   
    localparam MAX_PC = ((1<<PC_WIDTH)-PC_INCREMENT);
    
    assign pc_next_ext = in_branch_pc;
    assign out_pc      = pc_ff;    // Forward: sampled PC is forwarded to the decode stage
    
    // Register: sample next PC
    always @(posedge clock or posedge reset)
    begin
    if (!reset)
        pc_ff <= pc_next;
    else
        pc_ff <= MAX_PC;
    end

    // Adder: add increment to sampled PC
    always @(*)
    begin
        pc_next_int = pc_ff + PC_INCREMENT;
    end

    // Multiplexer: select internal or external next PC
    always @(*)
    begin
        if (in_set_pc == 1)
            pc_next = pc_next_ext;
        else
            pc_next = pc_next_int;
    end

    // Multiplexer: if we are setting external PC, send it directly to output
    //              otherwise: send incremented PC to output
    always @(*)
    begin
        if (in_set_pc ==1)
            out_pmem_addr = pc_next_ext;
        else
            out_pmem_addr = pc_next_int;
    end

    // Multiplexer: if pipeline is being flushed, send out nop (0x0). Otherwise send out instruction from pmem
    always @(*)
    begin
        if (in_flush == 1)
            out_instr = 0;
        else
            out_instr  = in_instr;
    end

endmodule
           
