# swt16
A sweet 16 bit processor

## Overview
This project contains an RTL description of a 16-bit processor with a classic five stage RISC pipeline. The pipeline stages are instruction fetch (FE), decode (DC), execute (EX), memory access (MEM), and register writeback (WB). For more information on the classic five stage pipeline, see https://en.wikipedia.org/wiki/Classic_RISC_pipeline. The RTL description is done in Verilog.

This project also contains a simulator for the RTL design.
The RTL simulator is built using Verilator (https://www.veripool.org/).
Verilator is open source. It can be downloaded from Github or obtained from the Ubuntu packet manager.

## Directory structure
```
├── bench        : simulator directory
├── doc          : ISA documentation
├── prog         : example programs
├── README.md    : this readme
└── rtl          : processor description in Verilog
```
## Prerequisites
Make sure Verilator is installed before attempting to run or build the simulator.
To install Verilator [Verilator](https://www.veripool.org/) and GTKWAVE, execute the following command:

`sudo apt-get install verilator gtkwave`

## Building simulator
Build the simulator by calling make from [bench]. After that, the simulator will be located in [bench/swt16/Vswt16_top].

`cd bench && make`

## Running the simulator
Call the simulator with parameter "--help" to see all available options to run it.

Example simulation run:

`./swt16/Vswt16_top --simTime 200 --pmemFile ../prog/hex_test_load_store.pmem --dmemFile ../prog/hex_test_load_store.dmem --dmemDump`

In this example, `--simTime <timeUnits>` specifies the number of time units for which the simulation is run. The option `--pmemFile <filename>` specifies the program file that is loaded into the program memory. Similarly, `--dmemFile <filename>` specifies the data file that is loaded into the data memory. 

Inspection with GTKWAVE: 

`gtkwave ./swt16/Vswt16_top.vcd -a gtkwave_views/swt16.view.gtkw &`

## Note
This project is developed and tested using Ubuntu.
