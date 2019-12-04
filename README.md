# swt16
A sweet 16 bit processor

Check [doc/isa.ods] for the current (humble) state of the ISA.
RTL code for the processor is located in [rtl].
Test programs written in assembler can be found in [prog].

Build the simulator by calling make from [bench]. After that, the simulator will be located in [bench/swt16/Vswt16_top].
Call the simulator with parameter "--help" to see all available options to run it.

This project is developed and tested using Ubuntu.

The RTL simulator is built using Verilator (https://www.veripool.org/).
Verilator is open source. It can be downloaded from Github or obtained from the Ubuntu packet manager.
