//           | in_branch_pc
//           |
//     +-----|-----+                       
//     |     |     | + PC_INCREMENT        
//     |     V     V                       
//     |   +---------+                     
//     |   \_________/                     
//     |        |                          
//     |        +-------------------------+
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
            input  [  PC_WIDTH-1:0]  in_branch_pc, // New program counter that we want to jump to
            input                    in_flush,     // Output out_instr is tied to 0 if this input is1
            input  [PMEM_WIDTH-1:0]  in_instr,     // Current instruction received from PMEM
            input                    in_set_pc,    // Are we setting a new PC via "in_branch_pc"?
            input                    in_stall,     // Keep program counter from advancing
            output [PMEM_WIDTH-1:0]  out_instr,    // Forward instruction to DC stage
            output [  PC_WIDTH-1:0]  out_pc,       // This goes to the pipeline (i.e., DC stage)
            output [  PC_WIDTH-1:0]  out_pmem_addr // This goes to the program memory
           );

    reg  [PMEM_WIDTH-1:0]  instr_ff;
    
    reg  [  PC_WIDTH-1:0] pc_next;
    reg  [  PC_WIDTH-1:0] pc_next_int;
    wire [  PC_WIDTH-1:0] pc_next_ext;
    reg  [  PC_WIDTH-1:0] pc_ff;
   
    localparam MAX_PC = ((1<<PC_WIDTH)-PC_INCREMENT);
    
    assign pc_next_ext   = in_branch_pc;
    assign out_pc        = pc_ff;
    assign out_pmem_addr = pc_next;
    
    // Register: sample next PC, instr
    always @(posedge clock or posedge reset)
    begin
        if (!reset) begin
            instr_ff <= in_instr;
            pc_ff    <= pc_next;
        end
        else begin
            instr_ff <= 0;
            pc_ff    <= MAX_PC;
        end
    end

    // Adder: add increment to sampled PC
    always @(*)
    begin
        pc_next_int = pc_ff + PC_INCREMENT;
    end

    // Multiplexer: select next PC
    // - when not branching: internal (i.e., incremented past value)
    // - when     branching: external next PC
    // - when     stalling : keep it the same as the previous value
    always @(*)
    begin
        if (in_stall) begin
            pc_next = pc_ff;
        end
        else if (in_set_pc == 1) begin
            pc_next = pc_next_ext;
        end
        else begin
            pc_next = pc_next_int;
        end
    end

    // Multiplexer: if pipeline is being flushed, send out nop (0x0). Otherwise send out instruction from pmem
    always @(*)
    begin
        if (in_flush == 1)
            out_instr = 0;
        else if (in_stall == 1)
            out_instr = instr_ff;
        else
            out_instr = in_instr;
    end

endmodule
           
