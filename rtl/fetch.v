//           | in_new_pc
//           |
//     +-----|-----+----------------------+
//     |     |     | + PC_INCREMENT       |
//     |     V     V                      |
//     |   +---------+                    |
//     |   \_________/                    |
//     |        |                         |
//     |        | next_pc                 | out_pmem_addr
//     |        V                         V
//     |   +---------+              +-------------+
//     |   |>  PC    |              | program mem |
//     |   +---------+              +-------------+
//     |        |                         |
//     ---------+ next_pc_sampled         | out_inst 
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
            input                    in_set_pc,
            input  [  PC_WIDTH-1:0]  in_new_pc,
            input  [PMEM_WIDTH-1:0]  in_instr,
            output [PMEM_WIDTH-1:0]  out_instr,
            output [  PC_WIDTH-1:0]  out_pc,       // This goes to the pipeline (i.e., DC stage)
            output [  PC_WIDTH-1:0]  out_pmem_addr // This goes to the program memory
           );

    reg  [PC_WIDTH-1:0] next_pc;
    reg  [PC_WIDTH-1:0] next_pc_int;
    wire [PC_WIDTH-1:0] next_pc_ext;
    reg  [PC_WIDTH-1:0] next_pc_sampled;
   
    localparam MAX_PC = ((1<<PC_WIDTH)-PC_INCREMENT);
    
    assign next_pc_ext = in_new_pc;
    assign out_pc      = next_pc_sampled;    // Forward: sampled PC is forwarded to the decode stage
    
    // Register: sample next PC
    always @(posedge clock or posedge reset)
    begin
    if (!reset)
        next_pc_sampled <= next_pc;
    else
        next_pc_sampled <= MAX_PC;
    end

    // Adder: add increment to sampled PC
    always @(*)
    begin
        next_pc_int = next_pc_sampled + PC_INCREMENT;
    end

    // Multiplexer: select internal or external next PC
    always @(*)
    begin
        if (in_set_pc == 1)
            next_pc = next_pc_ext;
        else
            next_pc = next_pc_int;
    end

    // Multiplexer: if we are setting external PC, send it directly to output
    //              otherwise: send incremented PC to output
    always @(*)
    begin
        if (in_set_pc ==1)
            out_pmem_addr = next_pc_ext;
        else
            out_pmem_addr = next_pc_int;
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
           
