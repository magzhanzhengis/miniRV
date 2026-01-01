#include "VminiRV_top.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>

static void tick(VminiRV_top *top, uint64_t &t) {
  top->clk = 0;
  top->eval();
  t++;

  top->clk = 1;   // posedge
  top->eval();
  t++;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  auto *top = new VminiRV_top;
  uint64_t t = 0;

  // Initialize
  top->clk = 0;
  top->rst = 1;
  top->eval();

  // Hold reset across several posedges
  for (int i = 0; i < 5; i++) tick(top, t);

  // Release reset on a clean boundary
  top->rst = 0;
  tick(top, t); // first cycle out of reset

  // Run
  for (uint64_t cycle = 0; ; cycle++) {
    tick(top, t);

    std::printf("cycle=%d pc=0x%08x instr=0x%08x a0=0x%08x\n",
                cycle,
                top->dbg_pc,
                top->dbg_instr,
                top->dbg_R10);
      // Task 4: stop simulation when CPU executes ebreak
  if (top->dbg_instr == 0x00100073) {          // EBREAK encoding
    uint32_t code = top->dbg_R10;              // a0 = x10
    std::printf("EBREAK seen, exiting with code=%u (0x%08x)\n", code, code);
    delete top;
    return (int)code;                          // exit status
  }

        
  }
  


  delete top;
  return 0;
}
