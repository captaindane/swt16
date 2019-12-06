# swt16
A sweet 16 bit processor

This project contains an RTL description of a 16-bit processor with a classical five stage RISC pipeline. The pipeline stages are instruction fetch (FE), decode (DC), execute (EX), memory access (MEM), and register writeback (WB). For more information, see https://en.wikipedia.org/wiki/Classic_RISC_pipeline. The RTL description is done in Verilog.

Check [doc/isa.ods] for the current (humble) state of the ISA.
RTL code for the processor is located in [rtl].
Test programs written in assembler can be found in [prog].

Build the simulator by calling make from [bench]. After that, the simulator will be located in [bench/swt16/Vswt16_top].
Call the simulator with parameter "--help" to see all available options to run it.

This project is developed and tested using Ubuntu.

The RTL simulator is built using Verilator (https://www.veripool.org/).
Verilator is open source. It can be downloaded from Github or obtained from the Ubuntu packet manager.
