#include <verilated.h>          // Defines common routines
#include "Vswt16_top.h"

#include "verilated_vcd_c.h"

#include <iostream>
#include <string>
#include <cstdlib>
#include <cstdio>


// Function headers
void parseCmdLine (int argc, char**argv, size_t& simTime);


Vswt16_top *uut;                // Instantiation of module
vluint64_t main_time = 0;       // Current simulation time

double sc_time_stamp () {       // Called by $time in Verilog
    return main_time;           // converts to double, to match
    // what SystemC does
}


// Command line parser
void parseCmdLine (int argc, char**argv, size_t& simTime)
{
    simTime = 0;

    // Loop through all parameters
    for (size_t parIdx=1; parIdx < argc; parIdx++)
    {
	std::string par = argv[parIdx];

	if (par == "--simTime")
	{
            std::string value = argv[++parIdx];
	    simTime           = std::stoi(value);
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
    size_t simTimeUnits = 0;
    parseCmdLine ( argc, argv, simTimeUnits);

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

//  while (!Verilated::gotFinish())
    while (main_time < simTimeUnits)
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

    std::cout << "Finished simulation of " << simTimeUnits << " time units." << std::endl;

    delete uut;

    return 0;
}
