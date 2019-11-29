module dmem_sim #(WORD_WIDTH = 16, 
                  ADDR_WIDTH = 12,
                  NUM_WORDS  = 2048,
                  MEM_FILE   = "")
         (input                   clock,
		  input  [ADDR_WIDTH-1:0] in_addr_rd,
		  input  [ADDR_WIDTH-1:0] in_addr_wr,
          input                   in_dbg_dump,
          input  [WORD_WIDTH-1:0] in_word,
          input                   in_write_en,
		  output [WORD_WIDTH-1:0] out_word);

    // Least significant bit in address that determines which word to read
    localparam ADDR_LSB = ((WORD_WIDTH / 8)-1);
    
    reg [ADDR_WIDTH-ADDR_LSB-1:0]  addr_rd_sampled;
    reg [         WORD_WIDTH-1:0]  mem_array         [ NUM_WORDS-1 : 0 ];

    // Helpers
    integer cfgFileHandle;
    reg  [200*8-1:0] memFileName;

    // Initialze simulation memory
    initial begin
        cfgFileHandle = $fopen(MEM_FILE, "r");

        if (cfgFileHandle == 0) begin
           $display("ERROR: Could not open memory config file %s\n", MEM_FILE);
           $finish;
        end

        $fscanf  (cfgFileHandle, "%s", memFileName);
        $readmemh(memFileName, mem_array);
    end

    // Dump contents of simulation memory (e.g., at the end of the simulation)
    always @(*) begin
        if (in_dbg_dump == 1) begin
            $writememh({memFileName,".postsim"}, mem_array);
        end
    end

    // Register: sample read address
    always @(posedge clock) begin
        addr_rd_sampled <= in_addr_rd[ADDR_WIDTH-1:ADDR_LSB];
    end

    // Read (synchronous)
    always @(*) begin
        out_word = mem_array[addr_rd_sampled];
    end

    // Write (synchronous)
    always @(posedge clock)
    begin
        if (in_write_en == 1) begin
            mem_array[in_addr_wr[ADDR_WIDTH-1:ADDR_LSB]] <= in_word;
        end
    end

endmodule
