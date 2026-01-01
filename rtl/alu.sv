module alu (
  input  logic [31:0] R1,        // rs1 value
  input  logic [31:0] R2,        // rs2 value    // I-type immediate (sign-extended)   // S-type immediate (sign-extended)

  input  logic  [31:0]  imm_sel,    // 0: imm (I-type), 1: immofs (S-type)
  input  logic        immorR2,
  input logic   [31:0] imm,   // 0: use R2, 1: use selected immediate

  input  logic [31:0] pc,        // current PC (byte address)

  output logic [31:0] alures,    // ALU result (R1 + opB)
  output logic [31:0] pcjump,    // (R1 + imm) & ~1   (jalr target)
  output logic [31:0] pc4,       // pc + 4

  output logic [31:0] addr,      // word index for RAM: alures >> 2
  output logic [1:0]  addr10     // byte offset: alures[1:0]
);

  // -------------------------
  // PC+4
  // -------------------------
  assign pc4 = pc + 32'd4;

  // -------------------------
  // Choose immediate type (I vs S)
  // -------------------------

  // -------------------------
  // Choose ALU second operand (R2 vs immediate)
  // -------------------------
  logic [31:0] immR2_res;
  assign immR2_res = (immorR2) ? R2: imm_sel;

  // -------------------------
  // ALU itself (only add in your miniRV)
  // -------------------------
  assign alures = R1 + immR2_res;

  // -------------------------
  // Memory address decode from ALU result
  // -------------------------
  assign addr   = alures >> 2;   // word index
  assign addr10 = alures[1:0];   // byte offset

  // -------------------------
  // JALR jump target: (R1 + imm) & ~1
  // Use I-type imm (not S-type) just like your circuit
  // -------------------------
  assign pcjump = (R1 + imm) & 32'hFFFF_FFFE;

endmodule
