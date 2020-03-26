#include "Vcpu.h"
#include "verilated.h"
#include "verilated_vcd_c.h"


// Simple Verilator test harness that dumps everything to
// a VCD wave file.  You really don't want to mess with
// anything here except maybe the filename and length
// of simulation.
int main(int argc, char **argv, char **env) {
  int i;
  int clk;
  Verilated::commandArgs(argc, argv);
  // init top verilog instance
  Vcpu* top = new Vcpu;
  // init trace dump
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  top->trace (tfp, 99);
  tfp->open ("cpu.vcd");
  // initialize simulation inputs
  top->clk_in = 1;
  top->nreset = 0;
  // run simulation for 1000 clock periods
  for (i=0; i<1000; i++) {
    top->nreset = (i > 2);
    // dump variables into VCD file and toggle clock
    for (clk=0; clk<2; clk++) {
      tfp->dump (2*i+clk);
      top->clk_in = !top->clk_in;
      top->eval ();
    }
    if (Verilated::gotFinish())  exit(0);
  }
  tfp->close();
  exit(0);
}


