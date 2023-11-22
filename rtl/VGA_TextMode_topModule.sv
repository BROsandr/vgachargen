`timescale 1ns / 1ps


module VGA_TextMode_topModule
                (
                    input wire clk_i,
                    input wire arstn_i,

                    // input  wire [7:0]                 col_map_data_i,
                    // output wire [7:0]                 col_map_data_o,
                    // input  wire [$clog2(80 * 30)-1:0] col_map_addr_i,
                    // input  wire                       col_map_wen_i,
                    // input  wire [7:0]                 ch_map_data_i,
                    // output wire [7:0]                 ch_map_data_o,
                    // input  wire [$clog2(80 * 30)-1:0] ch_map_addr_i,
                    // input  wire                       ch_map_wen_i,
                    // input  wire [127:0]               ch_t_rw_data_i,
                    // output wire [127:0]               ch_t_rw_data_o,
                    // input  wire                       ch_t_rw_wen_i,
                    // input  wire [$clog2(128)-1:0]     ch_t_rw_addr_i,
                    // input  wire                       clk_i,

                    output wire [3:0]vga_r_o,
                    output wire [3:0]vga_g_o,
                    output wire [3:0]vga_b_o,

                    output wire vga_hs_o,
                    output wire vga_vs_o
                );
                
                
                
localparam CHARACTER_SET_COUNT = 256;
localparam CHARACTER_ROM_MEMLOC = "ch_t_ro.mem";
localparam CH_T_RW_INIT_FILE = "ch_t_rw.mem";
localparam CHARACTER_BUFFER_MEMLOC = "characterBuffer80x60.mem";
localparam COL_MEMLOC = "cols.mem";

wire [$clog2(640)-1:0]xPixel;
wire [$clog2(480)-1:0]yPixel;

reg [1:0] pixelDrawing_ff;
reg       pixelDrawing_next;

always @(posedge clk_i) begin
  if (!arstn_i) pixelDrawing_ff <= '0;
  else     pixelDrawing_ff <= {pixelDrawing_ff[0], pixelDrawing_next};
end

  logic [1:0] hSYNC_ff;
  logic       hSYNC_next;
  logic [1:0] vSYNC_ff;
  logic       vSYNC_next;

  vga_block #(
    .CLK_FACTOR_25M (4)
  ) vga_block (
    .clk_i          (clk_i),
    .arstn_i        (arstn_i),
    .hcount_o       (xPixel),
    .vcount_o       (yPixel),
    .pixel_enable_o (pixelDrawing_next),
    .vga_hs_o       (hSYNC_next),
    .vga_vs_o       (vSYNC_next)
  );


wire [$clog2(80*30)-1:0]currentCharacterPixelIndex;

reg [$clog2(8 * 16)-1:0] characterXY_ff1;
reg [$clog2(8 * 16)-1:0] characterXY_ff2;
reg [$clog2(8 * 16)-1:0] characterXY_next;

  always_ff @(clk_i) begin
    if (!arstn_i) hSYNC_ff <= '0;
    else     hSYNC_ff <= {hSYNC_ff[0], hSYNC_next};
  end

  always_ff @(clk_i) begin
    if (!arstn_i) vSYNC_ff <= '0;
    else     vSYNC_ff <= {vSYNC_ff[0], vSYNC_next};
  end

always @(posedge clk_i) begin
  if (!arstn_i) {characterXY_ff2, characterXY_ff1} <= '0;
  else     {characterXY_ff2, characterXY_ff1} <= {characterXY_ff1, characterXY_next};
end

TextMode_indexGenerator TMindexGenIns
                (
                    .xPixel(xPixel),
                    .yPixel(yPixel),

                    .currentCharacterPixelIndex(currentCharacterPixelIndex),
                    .characterXY(characterXY_next)
                );



wire [$clog2(CHARACTER_SET_COUNT)-1:0]currentCharacterIndex;

true_dual_port_bram
                #
                (
                  .INIT_FILE   (CHARACTER_BUFFER_MEMLOC),
                  .DATA_WIDTH  ($clog2(CHARACTER_SET_COUNT)),
                  .DEPTH_WORDS (80 * 30)
                )
                TMtextBuffIns
                (
                    .clkb_i  (clk_i),
                    .clka_i  (clk_i),
                    .addra_i (ch_map_addr_i),
                    .addrb_i (currentCharacterPixelIndex),
                    .wea_i   (ch_map_wen_i),
                    .dina_i  (ch_map_data_i),
                    .douta_o (ch_map_data_o),
                    .doutb_o (currentCharacterIndex)
                );

wire [16 * 8-1:0]currentCharacter_ch_t_ro;
wire [16 * 8-1:0]currentCharacter_ch_t_rw;
wire [16 * 8-1:0]currentCharacter;

TextMode_characterROM
                #
                (
                    .CHARACTER_SET_COUNT(CHARACTER_SET_COUNT/2),
                    .MEMFILELOC(CHARACTER_ROM_MEMLOC)
                )
                ch_t_ro
                (
                    .clk(clk_i),
                    .enable(1),

                    .chracterIndex_addressIn(currentCharacterIndex[$left(currentCharacterIndex)-1:0]),
                    .currentCharacter_dataOut(currentCharacter_ch_t_ro)
                );

  true_dual_port_bram #(
    .INIT_FILE   (CH_T_RW_INIT_FILE),
    .DATA_WIDTH  (127),
    .DEPTH_WORDS (CHARACTER_SET_COUNT/2),
    .BINARY_FILE (1)
  ) ch_t_rw (
    .clka_i  (clk_i),
    .clkb_i  (clk_i),
    .addra_i (ch_t_rw_addr_i),
    .addrb_i (currentCharacterIndex[$left(currentCharacterIndex)-1:0]),
    .wea_i   (ch_t_rw_wen_i),
    .dina_i  (ch_t_rw_data_i),
    .douta_o (ch_t_rw_data_o),
    .doutb_o (currentCharacter_ch_t_rw)
  );

  assign currentCharacter = currentCharacterIndex[$left(currentCharacterIndex)] ? currentCharacter_ch_t_rw : currentCharacter_ch_t_ro;

  logic [7:0]      color_next;
  logic [7:0] color_ff1;
  logic [7:0] color_ff2;
  logic [3:0] fg_color;
  logic [3:0] bg_color;

  assign fg_color = color_ff1[7:4];
  assign bg_color = color_ff1[3:0];

  true_dual_port_bram #(
    .INIT_FILE   (COL_MEMLOC),
    .DATA_WIDTH  (8),
    .DEPTH_WORDS (80 * 30)
  ) col_map (
    .clka_i  (clk_i),
    .clkb_i   (clk_i),
    .addra_i (col_map_addr_i),
    .addrb_i (currentCharacterPixelIndex),
    .wea_i   (col_map_wen_i),
    .dina_i  (col_map_data_i),
    .douta_o (col_map_data_o),
    .doutb_o (color_next)
  );

  always_ff @(clk_i) begin
    if (!arstn_i) {color_ff2, color_ff1} <= '0;
    else     {color_ff2, color_ff1} <= {color_ff1, color_next};
  end

wire   currentPixel;
assign currentPixel = (pixelDrawing_ff[1] == 1) ? ~currentCharacter[characterXY_ff2] : 0;

assign vga_r_o = pixelDrawing_ff[1] ? (~((currentPixel) ? fg_color: bg_color)) : '0;
assign vga_b_o = pixelDrawing_ff[1] ? (~((currentPixel) ? fg_color: bg_color)) : '0;
assign vga_g_o = pixelDrawing_ff[1] ? (~((currentPixel) ? fg_color: bg_color)) : '0;

  assign vga_vs_o = vSYNC_ff[1];
  assign vga_hs_o = hSYNC_ff[1];

endmodule
