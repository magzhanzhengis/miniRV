module pcrom_dpi (
  input  logic        clk,
  input  logic        rst,
  input  logic [31:0] pcjump,
  input  logic        jumpornot,
  output logic [31:0] pc,
  output logic [31:0] instr
);

  import "DPI-C" function int unsigned mem_read(input int unsigned raddr);

  // Make PC known immediately at time 0 (important for Verilator)
  initial pc = 32'h8000_0000;

  reg [31:0] data [23:0];

  // PC update
  always_ff @(posedge clk) begin
    if (rst)              pc <= 32'h8000_0000;
    else if (jumpornot)   pc <= pcjump;
    else                  pc <= pc + 32'd4;
  end

  // Instruction fetch:
  // During reset, don't call DPI (PC might still be uninitialized in early evals)
  // 0x00000013 = ADDI x0, x0, 0 (NOP)
  always_comb begin
    if (rst) instr = 32'h0000_0013;
    else     instr = mem_read(pc);
  end

endmodule
