// Register File
// Register 0 set to zero at reset and cannot be written.

module regfile #(parameter WORD_WIDTH=16, IDX_WIDTH=4) 
       (
       input                   clock,
       input                   reset,
       input                   in_write,
       input  [IDX_WIDTH-1:0]  in_src1_idx,
       input  [IDX_WIDTH-1:0]  in_src2_idx,
       input  [IDX_WIDTH-1:0]  in_dst_idx,
       input  [WORD_WIDTH-1:0] in_dst,
       output [WORD_WIDTH-1:0] out_src1,
       output [WORD_WIDTH-1:0] out_src2
       );

    localparam NUM_REGS = (1<<IDX_WIDTH);

    integer i;

    reg [WORD_WIDTH-1:0] registers [NUM_REGS-1:0];


    // Multiplexer: select src1 output (asynchronous read)
    always @(*)
    begin
        out_src1 = registers[in_src1_idx];
    end

    // Multiplexer: select src2 output (asynchronous read)
    always @(*)
    begin
        out_src2 = registers[in_src2_idx];
    end

    // Register bank: write selected register
    always @(posedge clock or posedge reset)
    begin
        if (!reset)
        begin
            if (in_write)
            begin
                if (in_dst_idx > 0) begin
                    registers[in_dst_idx] <= in_dst;
                end
            end
        end
        else
        begin
            for (i=0; i<NUM_REGS; i++)
            begin
                registers[i] = 0;
            end
        end
    end


endmodule;

