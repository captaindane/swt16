module pmem_sim #(WORD_WIDTH = 16, ADDR_WIDTH = 12, NUM_WORDS = 2048, PMEM_FILE="")
         (input                   clock,
		  input  [ADDR_WIDTH-1:0] in_addr,
		  output [WORD_WIDTH-1:0] out_word);

    // Least significant bit in address that determines which word to read
    localparam ADDR_LSB = ((WORD_WIDTH / 8)-1);
    
    reg [WORD_WIDTH-1:0]          mem_array [ NUM_WORDS-1 : 0 ];
    reg [ADDR_WIDTH-ADDR_LSB-1:0] sampled_addr;


    initial begin
        $readmemh(PMEM_FILE, mem_array);
    end

    always @(posedge clock) begin
        sampled_addr <= in_addr[ADDR_WIDTH-1:ADDR_LSB];
    end

    always @(sampled_addr) begin
        out_word = mem_array[sampled_addr];
    end 

endmodule
