module vgachargen
  import vgachargen_pkg::*;
#(
  parameter int unsigned CLK_FACTOR_25M         = 100 / 25,
  parameter              CH_T_RO_INIT_FILE_NAME = "ch_t_ro.mem",
  parameter              CH_T_RW_INIT_FILE_NAME = "ch_t_rw.mem",
  parameter              CH_MAP_INIT_FILE_NAME  = "ch_map.mem",
  parameter              COL_MAP_INIT_FILE_NAME = "col_map.mem"
) (
  input logic clk_i,
  input logic arstn_i,

  // input  logic [COL_MAP_DATA_WIDTH-1:0] col_map_data_i,
  // input  logic [COL_MAP_ADDR_WIDTH-1:0] col_map_addr_i,
  // input  logic                          col_map_wen_i,
  // input  logic [CH_MAP_DATA_WIDTH-1:0]  ch_map_data_i,
  // input  logic [CH_MAP_ADDR_WIDTH-1:0]  ch_map_addr_i,
  // input  logic                          ch_map_wen_i,
  // input  logic [CH_T_DATA_WIDTH-1:0]    ch_t_rw_data_i,
  // input  logic                          ch_t_rw_wen_i,
  // input  logic [CH_T_ADDR_WIDTH-1:0]    ch_t_rw_addr_i,

  // output logic [CH_MAP_DATA_WIDTH-1:0]  ch_map_data_o,
  // output logic [CH_T_DATA_WIDTH-1:0]    ch_t_rw_data_o,
  // output logic [COL_MAP_DATA_WIDTH-1:0] col_map_data_o,
  output logic [COL_CHAN_WIDTH-1:0]     vga_r_o,
  output logic [COL_CHAN_WIDTH-1:0]     vga_g_o,
  output logic [COL_CHAN_WIDTH-1:0]     vga_b_o,
  output logic                          vga_hs_o,
  output logic                          vga_vs_o
);

  logic [VGA_MAX_H_WIDTH-1:0] hcount_pixels;
  logic [VGA_MAX_V_WIDTH-1:0] vcount_pixels;

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
    .CLK_FACTOR_25M (CLK_FACTOR_25M)
  ) vga_block (
    .clk_i          (clk_i),
    .arstn_i        (arstn_i),
    .hcount_o       (hcount_pixels),
    .vcount_o       (vcount_pixels),
    .pixel_enable_o (pixelDrawing_next),
    .vga_hs_o       (hSYNC_next),
    .vga_vs_o       (vSYNC_next)
  );


  logic [CH_MAP_ADDR_WIDTH-1:0] ch_map_addr_internal;

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

  index_generator index_generator (
    .vcount_i      (vcount_pixels),
    .hcount_i      (hcount_pixels),
    .ch_map_addr_o (ch_map_addr_internal),
    .bitmap_addr_o (characterXY_next)
  );


wire [CH_MAP_DATA_WIDTH-1:0]currentCharacterIndex;

true_dual_port_rw_bram
                #
                (
                  .INIT_FILE_NAME   ("ch_map.mem"),
                  .DATA_WIDTH  (CH_MAP_DATA_WIDTH),
                  .ADDR_WIDTH ($clog2(80 * 30))
                )
                ch_map
                (
                    .clk_i  (clk_i),
                    .addra_i (ch_map_addr_i),
                    .addrb_i (ch_map_addr_internal),
                    .wea_i   (ch_map_wen_i),
                    .dina_i  (ch_map_data_i),
                    .douta_o (ch_map_data_o),
                    .doutb_o (currentCharacterIndex)
                );

wire [16 * 8-1:0]currentCharacter_ch_t_ro;
wire [16 * 8-1:0]currentCharacter_ch_t_rw;
wire [16 * 8-1:0]currentCharacter;

single_port_ro_bram #(
                  .INIT_FILE_NAME    ("ch_t_ro.mem"),
                  .INIT_FILE_IS_BIN (1),
                  .DATA_WIDTH       (128),
                  .ADDR_WIDTH       (CH_T_ADDR_WIDTH)
                )
                ch_t_ro
                (
                    .clk_i(clk_i),

                    .addr_i(currentCharacterIndex[$left(currentCharacterIndex)-1:0]),
                    .dout_o(currentCharacter_ch_t_ro)
                );

  true_dual_port_rw_bram #(
    .INIT_FILE_NAME   ("ch_t_rw.mem"),
    .INIT_FILE_IS_BIN   (1),
    .DATA_WIDTH  (127),
    .ADDR_WIDTH  (CH_T_ADDR_WIDTH)
  ) ch_t_rw (
    .clk_i  (clk_i),
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

  true_dual_port_rw_bram #(
    .INIT_FILE_NAME   ("col_map.mem"),
    .DATA_WIDTH  (8),
    .ADDR_WIDTH  ($clog2(80 * 30))
  ) col_map (
    .clk_i  (clk_i),
    .addra_i (col_map_addr_i),
    .addrb_i (ch_map_addr_internal),
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
