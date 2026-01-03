module miniRV_top (
  input  logic        clk,
  input  logic        rst,
  output logic [31:0] dbg_pc,
  output logic [31:0] dbg_instr,
  output logic        dbg_reg_we,
  output logic [3:0]  dbg_rd,
  output logic [31:0] dbg_wdata,
    // ===== DEBUG: memory =====
  output logic        dbg_mem_we,
  output logic        dbg_mem_re,
  output logic [31:0] dbg_mem_addr,
  output logic [31:0] dbg_mem_wdata,
  output logic [3:0]  dbg_mem_wmask,
  output logic [31:0] dbg_mem_rdata,
  output logic [31:0] dbg_R10



);
// ===== DEBUG hookups =====
assign dbg_mem_we    = weram;
assign dbg_mem_re    = oeram;
assign dbg_mem_rdata = ramout;

// // byte address used by RAM
// assign dbg_mem_addr  = dbg_byte_addr;

// // what we write
// assign dbg_mem_wdata = dbg_wdata_aligned;

// // byte mask (same logic as ram_dpi)
// assign dbg_mem_wmask = dbg_wmask4;

// // what we read
// assign dbg_mem_rdata = ramout;

assign dbg_pc     = pc;      // your internal PC signal
assign dbg_instr  = instr;   // instruction currently executed
assign dbg_reg_we = we;  // writeback enable
assign dbg_rd     = rd;      // destination reg index
assign dbg_wdata  = wdata; // value written to rd


  // -------------------------
  // PC / Instruction
  // -------------------------
  logic [31:0] pc;
  logic [31:0] instr;

  // -------------------------
  // Decoded fields / immediates
  // -------------------------
  logic [6:0]  opcode;
  logic [2:0]  func;        // funct3
  logic [3:0]  rs1, rs2, rd;

  logic [31:0] imm_i;       // I-type sign-extended immediate
  logic [31:0] imm_s;       // S-type sign-extended immediate
  logic [31:0] imm_u;       // U-type immediate for LUI (already <<12 in decode or later)

  // some designs also pass raw imm[11:0] etc — keep simple

  // -------------------------
  // Control signals
  // -------------------------
  logic        oeram;
  logic        weram;
  logic        immselsorl;   // 0:I-type, 1:S-type
  logic        isload;       // 1 for loads (lw/lbu)
  logic        lwlbu;        // 0 lw, 1 lbu
  logic        islui;        // 1 for LUI
  logic        jumpornot;    // 1 for JALR
  logic        immorR2;
  logic     we;
  logic is_ebreak;
assign is_ebreak = (instr == 32'h0010_0073);

  // -------------------------
  // Register file data
  // -------------------------
  logic [31:0] R1, R2;
  assign we = (opcode != 7'h23) && !is_ebreak; // disable regfile write on store and ebreak

  // -------------------------
  // ALU / address outputs
  // -------------------------
  logic [31:0] alures;
  logic [31:0] pcjump;
  logic [31:0] pc4;

  logic [31:0] addr;        // word address for RAM indexing
  logic [1:0]  addr10;      // byte offset

  // -------------------------
  // Data memory outputs
  // -------------------------
  logic [31:0] ramout;

  // -------------------------
  // Writeback data
  // -------------------------
  logic [31:0] wdata;

  // -------------------------
  // Immediate select for ALU address calc
  // -------------------------
  logic [31:0] imm_sel;
  assign imm_sel = (immselsorl) ? imm_s : imm_i;

  // ============================================================
  // 1) PC + ROM
  // ============================================================
  pcrom_dpi u_pcrom (
  .clk       (clk),
  .rst       (rst),
  .pcjump    (pcjump),
  .jumpornot (jumpornot),
  .pc        (pc),
  .instr     (instr)
);


  // ============================================================
  // 2) Decode
  // ============================================================
  instr_fields u_instr_fields (
    .instr  (instr),
    .op (opcode),
    .func   (func),
    .rs1    (rs1),
    .rs2    (rs2),
    .rd     (rd),
    .imm  (imm_i),
    .immofs  (imm_s),
    .lui  (imm_u)
  );

  // ============================================================
  // 3) Control
  // ============================================================
  control u_control (
    .opcode     (opcode),
    .func       (func),
    .oeram      (oeram),
    .weram      (weram),
    .immselsorl (immselsorl),
    .isload     (isload),
    .lwlbu      (lwlbu),
    .islui      (islui),
    .jumpornot  (jumpornot),
    .immorR2    (immorR2)
  );

  // ============================================================
  // 4) Register file
  // ============================================================
  regfile u_regfile (
    .clk    (clk),
    .rst    (rst),
    .rs1    (rs1),
    .rs2    (rs2),
    .rd     (rd),   // if you use it internally to decide write enable
    .wdata  (wdata),
    .rdata1     (R1),
    .we (we),
    .rdata2     (R2),
    .dbg_R10    (dbg_R10)  // optional: debug output for R10
  );

  // ============================================================
  // 5) ALU (does add/addi/address, pc+4, pcjump)
  // ============================================================
  alu u_alu (
    .R1       (R1),
    .R2       (R2),
    .imm_sel   (imm_sel),   // I or S immediate for address/addi/jalr target    // if your ALU needs it for LUI path; otherwise ignore
    .pc       (pc),
    .immorR2  (immorR2),
    .imm      (imm_i),
    .pcjump   (pcjump),
    .alures   (alures),
    .addr     (addr),
    .addr10   (addr10),
    .pc4      (pc4)
  );

  // ============================================================
  // 6) Data memory
  // ============================================================
  ram_dpi u_ram (
  .clk   (clk),
  .addr  (addr),
  .addr10(addr10),
  .weram (weram),
  .oeram (oeram),
  .func  (func),
  .R2    (R2),
  .ramout(ramout),

  // DEBUG connections
  .dbg_byte_addr     (dbg_mem_addr),
  .dbg_wdata_aligned (dbg_mem_wdata),
  .dbg_wmask4        (dbg_mem_wmask)

);


  // ============================================================
  // 7) Writeback select
  // ============================================================
  writeback u_writeback (
    .alures        (alures),
    .ramout        (ramout),
    .lwlbu        (lwlbu),
    .islui         (islui),
    .isload        (isload),
    .jumpornot     (jumpornot),  // if you write pc+4 on jalr
    .lui         (imm_u),
    .pc4           (pc4),
    .wdata         (wdata),
    .addr10       (addr10)
  );

endmodule
