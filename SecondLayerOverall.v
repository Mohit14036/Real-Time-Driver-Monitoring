`timescale 1ns / 1ps

module conv_layer_64 #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_SIZE   = 222,
    parameter NUM_CHANNELS = 64
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    // First layer outputs (64 channels, DATA_WIDTH bits each)
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] pixels_in,
    input  wire pixel_valid,

    // Final output: summed convolution across 64 channels
    output wire [2*DATA_WIDTH+12:0] conv_out_sum,
    output wire conv_out_valid
);

    // --------------------------------------------------------
    // WIRES
    // --------------------------------------------------------
    wire [NUM_CHANNELS*9*DATA_WIDTH-1:0] input_win;   // 64 channels, each window = 3x3
    wire start_conv;
    wire done;

    // --------------------------------------------------------
    // 64-channel Window Generator
    // --------------------------------------------------------
    window_generator_64 #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMAGE_SIZE(IMAGE_SIZE),
        .NUM_CHANNELS(NUM_CHANNELS)
    ) window64 (
        .clk(clk),
        .rst(rst),
        .pixel_in(pixels_in),
        .pixel_valid(pixel_valid),
        .output_win(input_win),   // <-- fixed name
        .start_conv(start_conv),
        .done(done)
    );

    // --------------------------------------------------------
    // 64-channel Systolic Array
    // --------------------------------------------------------
    systolic_array_for_64 #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CHANNELS(NUM_CHANNELS),
        .OUTPUT_CYCLES(IMAGE_SIZE-2)   // valid cycles after 3x3 conv
    ) conv64 (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .start_conv(start_conv),
        .col(1'b0),   // not used in this version

        .input_col(input_win),
        .weights({NUM_CHANNELS*9*DATA_WIDTH{1'b1}}), // TODO: replace with actual kernel weights

        .conv_out_sum(conv_out_sum),
        .conv_out_valid(conv_out_valid)
    );

endmodule
