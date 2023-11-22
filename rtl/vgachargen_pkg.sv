package vgachargen_pkg;

  parameter int unsigned HD = 640; // Display area
  parameter int unsigned HF = 16;  // Front porch
  parameter int unsigned HR = 96;  // Retrace/Sync
  parameter int unsigned HB = 48;  // Back Porch
  parameter int unsigned VD = 480;
  parameter int unsigned VF = 10;
  parameter int unsigned VR = 2;
  parameter int unsigned VB = 33;

  parameter int unsigned HTOTAL = HD + HF + HR + HB;
  parameter int unsigned VTOTAL = VD + VF + VR + VB;

  parameter int unsigned VGA_MAX_H_WIDTH = $clog2(HTOTAL);
  parameter int unsigned VGA_MAX_V_WIDTH = $clog2(VTOTAL);

  parameter int unsigned BITMAP_H_PIXELS   = 8;
  parameter int unsigned BITMAP_V_PIXELS   = 16;
  parameter int unsigned BITMAP_H_WIDTH    = $clog2(BITMAP_H_PIXELS);
  parameter int unsigned BITMAP_V_WIDTH    = $clog2(BITMAP_V_PIXELS);
  parameter int unsigned CH_T_DATA_WIDTH   = BITMAP_H_PIXELS * BITMAP_V_PIXELS;
  parameter int unsigned BITMAP_ADDR_WIDTH = $clog2(CH_T_DATA_WIDTH);
  parameter int unsigned CHARSET_COUNT     = 256;
  parameter int unsigned CH_T_ADDR_WIDTH   = $clog2(CHARSET_COUNT/2);

  parameter int unsigned CH_H_PIXELS        = HD / BITMAP_H_PIXELS;
  parameter int unsigned CH_V_PIXELS        = VD / BITMAP_V_PIXELS;
  parameter int unsigned CH_V_WIDTH         = $clog2(CH_V_PIXELS);
  parameter int unsigned CH_H_WIDTH         = $clog2(CH_H_PIXELS);
  parameter int unsigned CH_MAP_ADDR_WIDTH  = CH_V_WIDTH + CH_H_WIDTH;
  parameter int unsigned CH_MAP_DATA_WIDTH  = 8;
  parameter int unsigned COL_MAP_ADDR_WIDTH = CH_MAP_ADDR_WIDTH;
  parameter int unsigned COL_MAP_DATA_WIDTH = CH_MAP_DATA_WIDTH;

  parameter int unsigned COL_CHAN_WIDTH     = 4;
endpackage
