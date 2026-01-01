module ram #(
  parameter int WORDS = 1 << 20   // 1M x 32 like your Logisim "16M x 32" label (16M bits = 1M words)
) (
  input  logic        clk,

  // control
  input  logic        weram,      // 1 on stores (sw/sb)
  input  logic        oeram,      // 1 on loads (lw/lbu) - optional if you always read combinationally
  input  logic [2:0]  func,       // funct3
  input  logic [1:0]  addr10,     // byte offset (ALU_result[1:0])

  // address/data
  input  logic [31:0] addr,       // WORD address index (ALU_result >> 2)
  input  logic [31:0] R2,         // store data (rs2)
  output logic [31:0] ramout      // read data word
);


  // funct3 values
  localparam logic [2:0] F3_SB = 3'b000;
  localparam logic [2:0] F3_SW = 3'b010;

  // 32-bit word RAM
  logic [31:0] mem [0:WORDS-1];

  initial $readmemh("program_mem.hex", mem);

  // truncate address to memory size
  localparam int ADDR_BITS = $clog2(WORDS);
  logic [ADDR_BITS-1:0] waddr;
  assign waddr = addr[ADDR_BITS-1:0];

  // -------------------------
  // Read (Logisim RAM is async read)
  // If you want to mimic "oeram", you can gate it; otherwise always drive ramout.
  // -------------------------
  assign ramout = mem[waddr];

  // -------------------------
  // Byte enable generation (this replaces your decoder + OR gates)
  // -------------------------
  logic [3:0] wstrb;
  always_comb begin
    wstrb = 4'b0000;

    if (weram) begin
      if (func == F3_SW) begin
        // sw: write all 4 bytes
        wstrb = 4'b1111;
      end
      else if (func == F3_SB) begin
        // sb: write only one byte lane selected by addr10
        wstrb = (4'b0001 << addr10);
      end
      else begin
        // other store types not supported in your subset
        wstrb = 4'b0000;
      end
    end
  end

  // -------------------------
  // IMPORTANT for sb:
  // shift rs2[7:0] into the selected byte lane
  // This is the exact reason sw worked but sb didn't earlier.
  // -------------------------
 
  logic [31:0] wdata_final;
  always_comb begin
    // sw writes full word, sb writes shifted byte pattern
    if (weram && (func == F3_SB)) wdata_final = {4{R2[7:0]}};
    else                          wdata_final = R2;
  end

  // -------------------------
  // Write on rising edge (like Logisim setting "Trigger: Rising Edge")
  // -------------------------
  always_ff @(posedge clk) begin
    if (weram) begin
      if (wstrb[0]) mem[waddr][7:0]   <= wdata_final[7:0];
      if (wstrb[1]) mem[waddr][15:8]  <= wdata_final[15:8];
      if (wstrb[2]) mem[waddr][23:16] <= wdata_final[23:16];
      if (wstrb[3]) mem[waddr][31:24] <= wdata_final[31:24];
    end
  end

endmodule
