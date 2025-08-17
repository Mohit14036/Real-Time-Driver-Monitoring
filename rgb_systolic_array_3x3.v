`timescale 1ns / 1ps

module rgb_systolic_array_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter OUTPUT_CYCLES=222
)(
    input wire clk,
    input wire rst,
    input wire load_weight,
    input wire start_conv,
    input wire col,

    // Each color has 3x1 inputs per clock (3 rows)
    input wire [3*DATA_WIDTH-1:0] input_col_r,
    input wire [3*DATA_WIDTH-1:0] input_col_g,
    input wire [3*DATA_WIDTH-1:0] input_col_b,

    // Each color has its own 3x3 kernel
    input wire [9*DATA_WIDTH-1:0] weights_r,
    input wire [9*DATA_WIDTH-1:0] weights_g,
    input wire [9*DATA_WIDTH-1:0] weights_b,

    // Final combined convolution output
    output reg [2*DATA_WIDTH+5:0] conv_out_rgb,
    output reg conv_out_rgb_valid
);

    wire [2*DATA_WIDTH+3:0] conv_r;
    wire [2*DATA_WIDTH+3:0] conv_g;
    wire [2*DATA_WIDTH+3:0] conv_b;

    wire conv_r_valid, conv_g_valid, conv_b_valid;

    // Instantiate systolic array for Red channel
    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH),.OUTPUT_CYCLES(OUTPUT_CYCLES)) red_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_r),
        .filter_weights(weights_r),
        .conv_out(conv_r),
        .conv_out_valid(conv_r_valid),
        .col(col)
    );

    // Instantiate systolic array for Green channel
    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH),.OUTPUT_CYCLES(OUTPUT_CYCLES)) green_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_g),
        .filter_weights(weights_g),
        .conv_out(conv_g),
        .conv_out_valid(conv_g_valid),
        .col(col)
    );

    // Instantiate systolic array for Blue channel
    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH),.OUTPUT_CYCLES(OUTPUT_CYCLES)) blue_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_b),
        .filter_weights(weights_b),
        .conv_out(conv_b),
        .conv_out_valid(conv_b_valid),
        .col(col)
    );

    // Sum all three outputs only when valid
    always @(posedge clk or posedge rst) begin
        if (rst || ~start_conv) begin
            conv_out_rgb       <= 0;
            conv_out_rgb_valid <= 0;
        end else begin
            if (conv_r_valid && conv_g_valid && conv_b_valid) begin
                conv_out_rgb       <= conv_r + conv_g + conv_b;
                conv_out_rgb_valid <= 1;
            end else begin
                conv_out_rgb_valid <= 0; // no valid output
            end
        end
    end

endmodule
