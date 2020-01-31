# swt16
A 16-bit, 5-stage RISC processor. RTL description in Verilog. Includes assembler, simulator, and example programs.

## Overview
This project contains a register transfer level (RTL) description of a 16-bit processor with a classic five stage RISC pipeline.
The RTL description is done in Verilog.

The pipeline stages are instruction fetch (FE), decode (DC), execute (EX), memory access (MEM), and register writeback (WB).
Regarding memory interfaces, the processor is designed according to the Harvard architecture, i.e., it has separate program and data memories.
More information on the classic five stage pipeline can be found on [Wikipedia](https://en.wikipedia.org/wiki/Classic_RISC_pipeline).
The processor design implements bypassing/forwarding.
When a read-after-write (RAW) data hazard cannot be resolved by bypassing/forwarding, the pipeline stalls.

This project also contains a simulator for the RTL design.
The RTL simulator is built using [Verilator](https://www.veripool.org/).
Verilator is open source. It can be downloaded from Github or obtained from the Ubuntu packet manager.
In addition, this project contains an assembler written in [Python](https://www.python.org/) to generate machine code from programs written in the swt16 assembly language.

## Directory structure
```
├── bench        : Simulator directory
├── doc          : ISA documentation
├── prog         : Example / test programs
├── README.md    : This readme
├── rtl          : Processor description in Verilog
└── utils        : Utilities: automated tests
```
## Prerequisites
Make sure Verilator is installed before attempting to run or build the simulator.
If you want to visualize the processor state during the simulation, you will also need [GTKWAVE](http://gtkwave.sourceforge.net/).
The assembler for the swt16 ISA is written in Python, so have to install Python before you can use the assembler.
To install Verilator, GTKWAVE, and Python, execute the following command (on Ubuntu Linux):

`sudo apt-get install verilator gtkwave python`

## Building the simulator
Build the simulator by calling make from [bench]. After that, the simulator will be located in [bench/swt16/Vswt16_top].

`cd bench && make`

## Running the simulator
Call the simulator with parameter "--help" to see all available options to run it.

Example simulation run:

`./swt16/Vswt16_top --simTime 200 --pmemFile ../prog/test_load_store.pmem --dmemFile ../prog/test_load_store.dmem --dmemDump`

In this example, `--simTime <timeUnits>` specifies the number of time units for which the simulation is run.
The option `--pmemFile <filename>` specifies the program file that is loaded into the program memory.
Similarly, `--dmemFile <filename>` specifies the data file that is loaded into the data memory.

## Running automated tests
In order to make sure the processor behaves as it should (e.g., after making changes to the RTL description),
this project comes with test programs located in [test].
To run all tests and check for correctness, run the shell script below

`cd utils && ./run_automated_tests.sh`

For each test program, this script dumps the contents of the data memory and compares it against a golden reference.

## Examining the processor state over time
When running, the simulation generates a VCD file that tracks the changes of the internal state of the processor over time.
Once the simulation has finished, the internal state of the processor during the simulation can be visualized using GTKWAVE.

Example state inspection with GTKWAVE: 

`gtkwave ./swt16/Vswt16_top.vcd -a gtkwave_views/swt16.view.gtkw &`

## Writing a program
This project contains an assembler written in Python.
The assembler generates machine code for the processor from programs written in the swt16 assembly language.
To invoke the assembler, execute the following:

`cd utils && python asm.py -i <asm_file> -o <machine_code_file>`

You can try out the assember by regenerating the machine code test programs located in [prog].
For example, to regenerate the machine code for the factorial test program, execute the following:

`cd utils && python asm.py -i ../prog/test_factorial.asm`

Refer to [doc/ISA.odt] for an overview of the current state of the assembly language and the ISA.

## Note
This project is developed and tested using Ubuntu Linux.
