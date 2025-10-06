`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// SingleSecondLayer.v
// Instantiates one SecondLayerOverall module
// Generalized for any KERNEL_SIZE (default 10×10)
// -----------------------------------------------------------------------------
module SingleSecondLayer #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_SIZE   = 224,
    parameter NUM_CHANNELS = 3,
    parameter NUM_FILTERS  = 3,
    parameter KERNEL_SIZE  = 10
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    // Pixel input stream
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] pixels_in,
    input  wire pixel_valid,

    // Output from the second-layer instance
    output wire [NUM_FILTERS*(2*DATA_WIDTH+8)-1:0] conv_out,
    output wire conv_out_valid
);

    // -------------------------------------------------------------------------
    // Single SecondLayerOverall instance
    // -------------------------------------------------------------------------
    SecondLayerOverall #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_SIZE  (IMAGE_SIZE),
        .NUM_CHANNELS(NUM_CHANNELS),
        .NUM_FILTERS (NUM_FILTERS),
        .KERNEL_SIZE (KERNEL_SIZE)
    ) u_second (
        .clk           (clk),
        .rst           (rst),
        .load_weight   (load_weight),
        .pixels_in     (pixels_in),
        .pixel_valid   (pixel_valid),
        .conv_out_pw   (conv_out),
        .conv_out_valid(conv_out_valid)
    );

endmodule
