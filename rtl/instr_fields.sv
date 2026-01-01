module instr_fields (
  input  logic [31:0] instr,

  output logic [6:0]  op,       // opcode
  output logic [2:0]  func,     // funct3
  output logic [3:0]  rd,
  output logic [3:0]  rs1,
  output logic [3:0]  rs2,

  output logic [31:0] imm,      // I-type imm (sign-extended)
  output logic [31:0] immofs,   // S-type imm (sign-extended)
  output logic [31:0] lui       // U-type imm (upper 20 bits << 12)
);

  // -------------------------
  // Basic fields
  // -------------------------
  assign op   = instr[6:0];
  assign rd   = instr[10:7];
  assign func = instr[14:12];
  assign rs1  = instr[18:15];
  assign rs2  = instr[23:20];

  // -------------------------
  // Immediates
  // -------------------------

  // I-type: imm[11:0] = instr[31:20], sign-extend to 32
  always_comb begin
    imm = {{20{instr[31]}}, instr[31:20]};
  end

  // S-type: imm[11:5]=instr[31:25], imm[4:0]=instr[11:7], sign-extend to 32
  always_comb begin
    immofs = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  end

  // U-type (LUI): instr[31:12] placed in upper bits, lower 12 bits are 0
  always_comb begin
    lui = {instr[31:12], 12'b0};
  end

endmodule
