module writeback (
  input  logic [31:0] alures,     // ALU result
  input  logic [31:0] ramout,      // memory read word
  input  logic [1:0]  addr10,      // byte offset
  input  logic [31:0] lui,         // LUI immediate
  input  logic [31:0] pc4,     
  input  logic        lwlbu,    // PC + 4

  input  logic        isload,      // lw or lbu
  input  logic        is_lbu,        // lbu
  input  logic        islui,        // lui
  input  logic        jumpornot,    // jalr

  output logic [31:0] wdata
);

  // -------------------------
  // LBU byte extraction
  // -------------------------
  logic [31:0] load_value;

  always_comb begin
    if (lwlbu) begin
      case (addr10)
        2'd0: load_value = {24'd0, ramout[7:0]};
        2'd1: load_value = {24'd0, ramout[15:8]};
        2'd2: load_value = {24'd0, ramout[23:16]};
        2'd3: load_value = {24'd0, ramout[31:24]};
      endcase
    end else begin
      load_value = ramout; // lw
    end
  end

  // -------------------------
  // Load vs ALU
  // -------------------------
  logic [31:0] alu_or_load;
  assign alu_or_load = isload ? load_value : alures;

  // -------------------------
  // LUI override
  // -------------------------
  logic [31:0] lui_or_prev;
  assign lui_or_prev = islui ? lui : alu_or_load;

  // -------------------------
  // JALR override
  // -------------------------
  assign wdata = jumpornot ? pc4 : lui_or_prev;

endmodule
