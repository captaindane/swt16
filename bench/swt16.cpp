#include <verilated.h>          // Defines common routines
#include "Vswt16_top.h"

#include "verilated_vcd_c.h"

#include <fstream>
#include <iostream>
#include <string>
#include <cstdlib>
#include <cstdio>


// Forward declaration of types
struct cmdLineArgs_t;

// Function headers
void parseCmdLine (int argc, char**argv, size_t& simTime);
void printHelp    (cmdLineArgs_t& cmdLineArgs);


Vswt16_top *uut;                // Instantiation of module
vluint64_t main_time = 0;       // Current simulation time

// Called by $time in Verilog
double sc_time_stamp ()
{
    return main_time;           // converts to double, to match
    // what SystemC does
}


// Config structure for parsed command line arguments
typedef struct cmdLineArgs_t
{
    bool        abort;

    bool        dmemDump;
    std::string dmemFile;
    bool        dmemFileSpecified;

    std::string execName;
    bool        exitOnNop;
    
    std::string pmemFile;
    bool        pmemFileSpecified;
    
    size_t      simTime;

} cmdLineArgs_t;


// Prints help text on stdout
void printHelp (cmdLineArgs_t& cmdLineArgs)
{
    std::cout << "Usage of swt16 simulator" << std::endl;

    std::cout << cmdLineArgs.execName << std::endl \
              << "        --dmemFile <hex file containing init values for data memory>" << std::endl \
              << "        --dmemDump" << std::endl \
              << "        --exitOnNop" << std::endl \
              << "        --pmemFile <hex file containing contents of program memory>" << std::endl \
              << "        --simTime  <simulation time in time units>" << std::endl \
              << "        --help" << std::endl;
}



// Command line parser
void parseCmdLine (int argc, char**argv, cmdLineArgs_t& cmdLineArgs)
{
    // Set default values
    cmdLineArgs.abort             = false;
    cmdLineArgs.dmemDump          = false;
    cmdLineArgs.dmemFileSpecified = false;
    cmdLineArgs.exitOnNop         = false;
    cmdLineArgs.pmemFileSpecified = false;
    cmdLineArgs.simTime           = 100;

    // Set name of simulation executable
    cmdLineArgs.execName = std::string(argv[0]);

    // Loop through all parameters
    for (size_t parIdx=1; parIdx < argc; parIdx++)
    {
	    std::string par = argv[parIdx];
        
        
        if      (par == "--dmemDump")
        {
            cmdLineArgs.dmemDump = true;
        }
        
        else if (par == "--dmemFile")
        {
            cmdLineArgs.dmemFile          = std::string(argv[++parIdx]);
            cmdLineArgs.dmemFileSpecified = true;
        }

        else if (par == "--exitOnNop")
        {
            cmdLineArgs.exitOnNop = true;
        }
	    
        else if (par == "--help")
        {
            cmdLineArgs.abort = true;
        }
        
        else if (par == "--pmemFile")
        {
            cmdLineArgs.pmemFile          = std::string(argv[++parIdx]);
            cmdLineArgs.pmemFileSpecified = true;
        }
	    
        else if (par == "--simTime")
	    {
	        cmdLineArgs.simTime = std::stoi(std::string(argv[++parIdx]));
	    }

        else
        {
            std::cout << "ERROR: unknown parameter " << par << std::endl;
            abort();
        }
        
    }

    // Setup DMEM, PMEM
    if (cmdLineArgs.dmemFileSpecified == true)
    {
        std::ofstream outfile;
        outfile.open("../prog/_dmem_to_use.txt");
        outfile << cmdLineArgs.dmemFile << std::endl; 
        outfile.close();
    }
    
    if (cmdLineArgs.pmemFileSpecified == true)
    {
        std::ofstream outfile;
        outfile.open("../prog/_pmem_to_use.txt");
        outfile << cmdLineArgs.pmemFile << std::endl; 
        outfile.close();
    }
}


// Main function. Runs simulator loop.
int main(int argc, char** argv)
{
    // Depth of the RISC pipeline
    size_t const   pipeDepth = 5;
    
    // Turn on trace or not?
    bool           vcdTrace   = true;
    VerilatedVcdC* pVcdTracer = NULL;

    Verilated::commandArgs(argc, argv);   // Remember args
    
    // Parse command line
    cmdLineArgs_t cmdLineArgs;

    parseCmdLine ( argc, argv, cmdLineArgs);

    // If help text is demanded, print it and exit
    if (cmdLineArgs.abort == true) { printHelp(cmdLineArgs); return 0; }

    
    uut = new Vswt16_top;   // Create instance

    uut->eval();
    uut->eval();

    if (vcdTrace)
    {
        Verilated::traceEverOn(true);

        pVcdTracer = new VerilatedVcdC;
        uut->trace(pVcdTracer, 99);

        std::string vcdname = argv[0];
        vcdname += ".vcd";
        pVcdTracer->open(vcdname.c_str());
    }

    // Reset
    uut->clock = 0;
    uut->reset = 1;
    uut->eval();
    if (pVcdTracer != NULL) { pVcdTracer->dump (main_time); }
    main_time++;

    uut->clock = 1;
    uut->reset = 1;
    uut->eval();
    if (pVcdTracer != NULL) { pVcdTracer->dump (main_time); }
    main_time++;

    uut->clock = 0;
    uut->reset = 0;
    uut->eval();
    if (pVcdTracer != NULL) { pVcdTracer->dump (main_time); }
    main_time++;

    // Run for specified amount of time
    while (   (cmdLineArgs.exitOnNop == false && (main_time < cmdLineArgs.simTime))
           || (cmdLineArgs.exitOnNop == true  && !(uut->out_nop_in_WB && main_time > 2*pipeDepth)) )
    {
        // Toggle clock
        uut->clock = uut->clock ? 0 : 1;

        // Evaluate model
        uut->eval();
        if (pVcdTracer != NULL) { pVcdTracer->dump (main_time); }
        main_time++;
    }

    // Dump contents of dmem
    if (cmdLineArgs.dmemDump == true)
    {
        uut->in_dmem_dump = 1;
        uut->eval();
        if (pVcdTracer != NULL) { pVcdTracer->dump (main_time); }
        main_time++;
    }
    
    // Done simulating
    uut->final();

    if (pVcdTracer != NULL)
    {
        pVcdTracer->close();
        delete pVcdTracer;
    }

    std::cout << "Finished simulation of " << main_time << " time units." << std::endl;

    delete uut;

    return 0;
}
