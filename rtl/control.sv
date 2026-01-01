module control (
  input  logic [6:0] opcode,   // instr[6:0]
  input  logic [2:0] func,      // instr[14:12] (funct3)

  output logic       oeram,        // RAM output enable (read)
  output logic       weram,        // RAM write enable (store)
  output logic       immselsorl,   // 1: use S-type imm (stores), 0: use I-type imm (addi/lw/lbu/jalr)
  output logic       isload,       // 1 for loads (lw/lbu)
  output logic       lwlbu,        // 0: lw, 1: lbu (only meaningful when isload=1)
  output logic       islui,        // 1 for LUI
  output logic       jumpornot,
  output logic       immorR2      // 1 for JALR
);

  // RISC-V opcodes (RV32I base)
  localparam logic [6:0] OP_RTYPE  = 7'b0110011; // add
  localparam logic [6:0] OP_ITYPE  = 7'b0010011; // addi
  localparam logic [6:0] OP_LOAD   = 7'b0000011; // lw, lbu
  localparam logic [6:0] OP_STORE  = 7'b0100011; // sw, sb
  localparam logic [6:0] OP_LUI    = 7'b0110111; // lui
  localparam logic [6:0] OP_JALR   = 7'b1100111; // jalr

  // funct3 values we care about
  localparam logic [2:0] F3_ADDI = 3'b000;
  localparam logic [2:0] F3_LW   = 3'b010;
  localparam logic [2:0] F3_LBU  = 3'b100;
  localparam logic [2:0] F3_SW   = 3'b010;
  localparam logic [2:0] F3_SB   = 3'b000;
  localparam logic [2:0] F3_JALR = 3'b000;

  // decoded instruction “is_x” wires (one-hot-ish)
  logic is_add, is_addi, is_lw, is_lbu, is_sw, is_sb, is_store, is_jalr;

  always_comb begin
    is_add   = (opcode == OP_RTYPE);                      // add (you can also check funct3/funct7 if you want)
    is_addi  = (opcode == OP_ITYPE) && (func == F3_ADDI);
    is_lw    = (opcode == OP_LOAD)  && (func == F3_LW);
    is_lbu   = (opcode == OP_LOAD)  && (func == F3_LBU);
    is_sw    = (opcode == OP_STORE) && (func == F3_SW);
    is_sb    = (opcode == OP_STORE) && (func == F3_SB);
    is_store = is_sw || is_sb;
    is_jalr  = (opcode == OP_JALR)  && (func == F3_JALR);
  end

  // outputs
  always_comb begin
    // defaults
    oeram      = 1'b0;
    weram      = 1'b0;
    immselsorl = 1'b0; // default: I-type immediate
    isload     = 1'b0;
    lwlbu      = 1'b0;
    islui      = 1'b0;
    jumpornot  = 1'b0;
    immorR2    = 1'b0;

    // RAM control
    // reads for lw/lbu, writes for sw/sb
    if (is_add) begin
      immorR2 = 1'b1;
    end
    if (is_lw || is_lbu) begin
      oeram  = 1'b1;
      weram  = 1'b0;
      isload = 1'b1;
      lwlbu  = is_lbu;   // 1 if lbu, 0 if lw
      // loads use I-type imm for address
    end

    if (is_store) begin
      oeram  = 1'b0;     // IMPORTANT: OE must be 0 during write (matches Logisim needs)
      weram  = 1'b1;
      // stores use S-type imm for address
      immselsorl = 1'b1;
    end

    // LUI control
    if (opcode == OP_LUI) begin
      islui = 1'b1;
      // no RAM
      oeram = 1'b0;
      weram = 1'b0;
    end

    // JALR control
    if (is_jalr) begin
      jumpornot = 1'b1;
      // jalr uses I-type imm for target address calc
      immselsorl = 1'b0;
      // no RAM
      oeram = 1'b0;
      weram = 1'b0;
    end

    // ADD/ADDI: no RAM
    // addi uses I-type imm (imm2selori=0 already)
    // add uses rs2 (your ALU operand select is done elsewhere)
  end

endmodule
