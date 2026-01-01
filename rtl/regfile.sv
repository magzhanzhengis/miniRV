module regfile #(
  parameter int NREGS = 16   // set to 8/16 if your miniRV uses fewer regs
) (
  input  logic        clk,
  input  logic        rst,       // optional: if you want reset-to-zero
  input  logic        we,      // global write enable
  input  logic [$clog2(NREGS)-1:0] rs1,
  input  logic [$clog2(NREGS)-1:0] rs2,
  input  logic [$clog2(NREGS)-1:0] rd,
  input  logic [31:0] wdata,

  output logic [31:0] rdata1,
  output logic [31:0] rdata2,
  output logic [31:0] dbg_R10  // optional: debug output for a specific register
);

  logic [31:0] regs [0:NREGS-1];
  // -------------------------
  // Async reads (like Logisim mux read ports)
  // -------------------------
  always_comb begin
    rdata1 = (rs1 == '0) ? 32'd0 : regs[rs1];
    rdata2 = (rs2 == '0) ? 32'd0 : regs[rs2];
  end

  assign dbg_R10 = regs[10];

  // -------------------------
  // Sync write on rising edge (like Logisim register write)
  // -------------------------
  integer i;
  always_ff @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < NREGS; i++) regs[i] <= 32'd0;
    end else begin
      if (we && (rd != '0)) begin
        regs[rd] <= wdata;
      end // keep x0 always 0 (extra safety)
    end
  end

endmodule
