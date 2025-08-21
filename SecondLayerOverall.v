`timescale 1ns / 1ps

module SecondLayerOverall #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_SIZE   = 222,
    parameter NUM_CHANNELS = 64
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    // First layer outputs (NUM_CHANNELS channels, DATA_WIDTH bits each)
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] pixels_in,
    input  wire pixel_valid,

    // Final output: summed convolution across NUM_CHANNELS channels
    output wire [2*DATA_WIDTH+12:0] conv_out_sum,
    output wire conv_out_valid
);

    // 3x1 column per channel (packed): NUM_CHANNELS * 3 * DATA_WIDTH bits
    wire [NUM_CHANNELS*3*DATA_WIDTH-1:0] input_col;

    // Handshake / control wires from WindowGenerator64
    wire wg_start_conv;
    wire wg_done;
    wire wg_col_valid;
    wire wg_take_col;

    // weights bus for systolic array: NUM_CHANNELS * 9 weights (3x3 per channel) each DATA_WIDTH bits
    wire [NUM_CHANNELS*9*DATA_WIDTH-1:0] weights;

    // Tie placeholder weights to all ones (replace with real weight loading logic later)
    assign weights = { (NUM_CHANNELS*9*DATA_WIDTH) {1'b1} };

    // Instantiate the WindowGenerator64
    WindowGenerator64 #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMAGE_SIZE(IMAGE_SIZE),
        .NUM_FILTERS(NUM_CHANNELS)     // Window module parameter name is NUM_FILTERS
    ) window64 (
        .clk(clk),
        .rst(rst),

        .pixel_in(pixels_in),
        .pixel_valid(pixel_valid),

        .output_col(input_col),        // packed 3x1 per channel
        .start_conv(wg_start_conv),
        .done(wg_done),
        .col_valid(wg_col_valid),      // note: WindowGenerator64 names this 'col_valid'
        .take_col(wg_take_col)
    );

    // Instantiate the SystolicArrayForN
    // NOTE: ensure SystolicArrayForN's port names/widths match the mapping below.
    SystolicArrayForN #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CHANNELS(NUM_CHANNELS),
        .OUTPUT_CYCLES(IMAGE_SIZE)
    ) conv64 (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),

        // Handshakes: use start_conv and col (col mapped from window's col_valid)
        .start_conv(wg_start_conv),
        .col(wg_col_valid),

        // Data
        .input_col(input_col),
        .weights(weights),

        // Outputs
        .conv_out_sum(conv_out_sum),
        .conv_out_valid(conv_out_valid)
    );

endmodule
