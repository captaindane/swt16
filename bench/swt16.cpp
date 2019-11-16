#include <verilated.h>          // Defines common routines
#include "Vswt16_top.h"

#include "verilated_vcd_c.h"

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

double sc_time_stamp () {       // Called by $time in Verilog
    return main_time;           // converts to double, to match
    // what SystemC does
}


// Config structure
typedef struct cmdLineArgs_t
{
    bool        abort;
    size_t      simTime;
    std::string execName;

} cmdLineArgs_t;


// Prints help text on stdout
void printHelp (cmdLineArgs_t& cmdLineArgs)
{
    std::cout << "Usage of swt16 simulator" << std::endl;

    std::cout << cmdLineArgs.execName << "  --simTime  <simulation time in time units>" << std::endl
              << "                    --help" << std::endl;
}



// Command line parser
void parseCmdLine (int argc, char**argv, cmdLineArgs_t& cmdLineArgs)
{
    // Set default values
    cmdLineArgs.abort    = false;
    cmdLineArgs.simTime  = 100;

    // Set name of simulation executable
    cmdLineArgs.execName = std::string(argv[0]);

    // Loop through all parameters
    for (size_t parIdx=1; parIdx < argc; parIdx++)
    {
	    std::string par = argv[parIdx];

	    if      (par == "--simTime")
	    {
            std::string value   = argv[++parIdx];
	        cmdLineArgs.simTime = std::stoi(value);
	    }

        else if (par == "--help")
        {
            cmdLineArgs.abort = true;
        }
    }
}


// Main function. Runs simulator loop.
int main(int argc, char** argv)
{
    // turn on trace or not?
    bool vcdTrace = true;
    VerilatedVcdC* tfp = NULL;

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

        tfp = new VerilatedVcdC;
        uut->trace(tfp, 99);

        std::string vcdname = argv[0];
        vcdname += ".vcd";
        std::cout << vcdname << std::endl;
        tfp->open(vcdname.c_str());
    }

    // Reset
    uut->clock = 0;
    uut->reset = 1;
    uut->eval();
    if (tfp != NULL) { tfp->dump (main_time); }
    main_time++;

    uut->clock = 1;
    uut->reset = 1;
    uut->eval();
    if (tfp != NULL) { tfp->dump (main_time); }
    main_time++;

    uut->clock = 0;
    uut->reset = 0;
    uut->eval();
    if (tfp != NULL) { tfp->dump (main_time); }
    main_time++;

    while (main_time < cmdLineArgs.simTime)
    {
        uut->clock = uut->clock ? 0 : 1;       // Toggle clock
        uut->eval();            // Evaluate model

        if (tfp != NULL)
        {
            tfp->dump (main_time);
        }
 
        main_time++;            // Time passes...
    }

    uut->final();               // Done simulating

    if (tfp != NULL)
    {
        tfp->close();
        delete tfp;
    }

    std::cout << "Finished simulation of " << cmdLineArgs.simTime << " time units." << std::endl;

    delete uut;

    return 0;
}
