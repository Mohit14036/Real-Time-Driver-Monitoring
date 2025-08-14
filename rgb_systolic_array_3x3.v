`timescale 1ns / 1ps

module rgb_systolic_array_3x3 #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire load_weight,
    input wire total_window_done,
    input wire start_conv,

    // Each color has 3x1 inputs per clock (3 rows)
    input wire [3*DATA_WIDTH-1:0] input_col_r,
    input wire [3*DATA_WIDTH-1:0] input_col_g,
    input wire [3*DATA_WIDTH-1:0] input_col_b,

    // Each color has its own 3x3 kernel
    input wire [9*DATA_WIDTH-1:0] weights_r,
    input wire [9*DATA_WIDTH-1:0] weights_g,
    input wire [9*DATA_WIDTH-1:0] weights_b,

    // Final combined convolution output
    output reg [2*DATA_WIDTH+5:0] conv_out_rgb
);

    wire [2*DATA_WIDTH+3:0] conv_r;
    wire [2*DATA_WIDTH+3:0] conv_g;
    wire [2*DATA_WIDTH+3:0] conv_b;

    // Instantiate systolic array for Red channel
    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) red_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_r),
        .filter_weights(weights_r),
        .conv_out(conv_r)
    );

    // Instantiate systolic array for Green channel
    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) green_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_g),
        .filter_weights(weights_g),
        .conv_out(conv_g)
    );

    // Instantiate systolic array for Blue channel
    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) blue_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_b),
        .filter_weights(weights_b),
        .conv_out(conv_b)
    );

    // Sum all three outputs
    always @(posedge clk or posedge rst) begin
        if (rst || total_window_done || ~start_conv
        )
            conv_out_rgb <= 0;
        else begin
            conv_out_rgb <= conv_r + conv_g + conv_b;
            //$display("Time: %0t | Final RGB Convolution Output: %0d", $time, conv_out_rgb);
        end
    end

endmodule
