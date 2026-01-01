module ram_dpi (
  input  logic        clk,
  input  logic [31:0] addr,     // you said: "word address for RAM indexing"
  input  logic [1:0]  addr10,   // byte offset
  input  logic        weram,
  input  logic        oeram,
  input  logic [2:0]  func,     // funct3 (sb/sh/sw/lw/lbu)
  input  logic [31:0] R2,
  output logic [31:0] ramout,
  output logic [31:0] dbg_byte_addr,
  output logic [31:0] dbg_wdata_aligned,
  output logic [3:0]  dbg_wmask4
);
  import "DPI-C" function int unsigned mem_read(input int unsigned raddr);
  import "DPI-C" function void mem_write(
    input int unsigned waddr,
    input int unsigned wdata,
    input byte         wmask
  );
  assign dbg_byte_addr     = byte_addr;
assign dbg_wdata_aligned = wdata_aligned;
assign dbg_wmask4        = wmask4;


    logic [31:0] byte_addr;

  always_comb begin
    byte_addr = {addr[29:0], 2'b00};
  end

  always_comb begin
    if (oeram) ramout = mem_read(byte_addr);
    else       ramout = 32'd0;
  end



  // Write: generate correct wmask + aligned wdata (this is the key part)
  logic [3:0]  wmask4;
  logic [31:0] wdata_aligned;

  always_comb begin
    wmask4 = 4'b0000;
    wdata_aligned = 32'd0;

    unique case (func)
      3'b000: begin // SB
        wmask4 = (4'b0001 << addr10);
        wdata_aligned = ({24'd0, R2[7:0]} << (8 * addr10));
      end
      3'b010: begin // SW
        wmask4 = 4'b1111;
        wdata_aligned = R2;
      end
      default: begin
        wmask4 = 4'b0000;
        wdata_aligned = 32'd0;
      end
    endcase
  end

  // Commit writes on clock edge
  always_ff @(posedge clk) begin
    if (weram) begin
      mem_write(byte_addr, wdata_aligned, {4'b0, wmask4});
    end
  end

endmodule
