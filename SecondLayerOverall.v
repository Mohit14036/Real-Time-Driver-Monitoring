`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// SecondLayerOverall.v
// Top-level module for second convolutional layer
// - Uses WindowGenerator64 to generate vertical KERNEL_SIZE×1 columns
// - Feeds these columns to normal_conv to produce NUM_FILTERS outputs
// - Generalized for any KERNEL_SIZE (default 10x10)
// -----------------------------------------------------------------------------
module SecondLayerOverall #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_SIZE   = 222,
    parameter NUM_CHANNELS = 64,
    parameter NUM_FILTERS  = 64,
    parameter KERNEL_SIZE  = 10
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    // Packed first-layer pixels: NUM_CHANNELS × DATA_WIDTH
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] pixels_in,
    input  wire pixel_valid,

    // Packed final outputs: NUM_FILTERS × OUT_WIDTH
    output wire [NUM_FILTERS*(2*DATA_WIDTH+8)-1:0] conv_out_pw,
    output wire conv_out_valid
);

    // -------------------------------------------------------------------------
    // Window generator
    // -------------------------------------------------------------------------
    wire [NUM_CHANNELS*KERNEL_SIZE*DATA_WIDTH-1:0] input_col;
    wire wg_start_conv;
    wire wg_done;
    wire wg_col_valid;
    wire wg_take_col;

    WindowGenerator64 #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_SIZE  (IMAGE_SIZE),
        .NUM_FILTERS (NUM_CHANNELS),   // each channel = one filter stream in this stage
        .KERNEL_SIZE (KERNEL_SIZE)
    ) u_window_gen (
        .clk         (clk),
        .rst         (rst),
        .pixel_in    (pixels_in),
        .pixel_valid (pixel_valid),

        .output_col  (input_col),
        .start_conv  (wg_start_conv),
        .done        (wg_done),
        .col_valid   (wg_col_valid),
        .take_col    (wg_take_col)
    );

    // -------------------------------------------------------------------------
    // Weight storage (placeholder for now)
    // TOTAL_WEIGHTS = NUM_FILTERS × NUM_CHANNELS × (KERNEL_SIZE × KERNEL_SIZE) × DATA_WIDTH
    // -------------------------------------------------------------------------
    localparam TOTAL_WEIGHTS = NUM_FILTERS * NUM_CHANNELS * KERNEL_SIZE * KERNEL_SIZE * DATA_WIDTH;
    wire [TOTAL_WEIGHTS-1:0] conv_weights;

    // For now: all weights are 1s (can be replaced with memory load later)
    assign conv_weights = {TOTAL_WEIGHTS{1'b1}};

    // -------------------------------------------------------------------------
    // Normal convolution block
    // -------------------------------------------------------------------------
    wire conv_valid_internal;

    normal_conv #(
        .DATA_WIDTH   (DATA_WIDTH),
        .NUM_CHANNELS (NUM_CHANNELS),
        .NUM_FILTERS  (NUM_FILTERS),
        .OUT_WIDTH    (2*DATA_WIDTH + 8)
    ) u_normal_conv (
        .clk           (clk),
        .rst           (rst),
        .load_weight   (load_weight),

        .input_col     (input_col),
        .conv_weights  (conv_weights),
        .col_valid     (wg_col_valid),

        .conv_out      (conv_out_pw),
        .conv_out_valid(conv_valid_internal)
    );

    // -------------------------------------------------------------------------
    // Output valid signal
    // -------------------------------------------------------------------------
    assign conv_out_valid = conv_valid_internal;

endmodule
