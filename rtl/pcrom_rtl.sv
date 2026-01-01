module pcrom #(
  parameter int    ROM_WORDS = 1 << 20,          // 1M x 32 like your ROM
  parameter string HEXFILE   = ""                // optional: $readmemh file
) (
  input  logic        clk,
  input  logic        rst,        // when 1 -> PC=0
  input  logic        jumpornot,  // 1 -> take pcjump, 0 -> take pc+4
  input  logic [31:0] pcjump,     // absolute byte address target (already aligned if you want)
  output logic [31:0] pc,         // current PC (byte address)
  output logic [31:0] instr       // fetched instruction
);


  initial $readmemh("program_mem.hex", rom);


  // -------------------------
  // PC update logic
  // -------------------------
  logic [31:0] pc_plus4;
  logic [31:0] pc_next;

  assign pc_plus4 = pc + 32'd4;
  assign pc_next  = (jumpornot) ? pcjump : pc_plus4;

  always_ff @(posedge clk) begin
    if (rst) pc <= 32'h0000_0000;
    else     pc <= pc_next;
  end

  // -------------------------
  // ROM (instruction memory)
  // Address = PC >> 2 (word index)
  // -------------------------
  reg [31:0] rom [0:ROM_WORDS-1];

  // Use word index from PC; truncate to ROM size
  localparam int ADDR_BITS = $clog2(ROM_WORDS);
  logic [ADDR_BITS-1:0] rom_addr;

  assign rom_addr = pc[ADDR_BITS+1 : 2]; // same as (pc >> 2) limited to ROM size
  assign instr    = rom[rom_addr];       // async read like Logisim ROM

endmodule
