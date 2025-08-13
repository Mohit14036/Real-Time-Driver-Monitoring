`timescale 1ns / 1ps

module rgb_conv_layer_64 #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire load_weight,

    // Shared input pixels for R, G, B
    input wire [DATA_WIDTH-1:0] pixel_in_r,
    input wire [DATA_WIDTH-1:0] pixel_in_g,
    input wire [DATA_WIDTH-1:0] pixel_in_b,
    
    input pixel_valid_r,
    input pixel_valid_g,
    input pixel_valid_b,

    // Output of 64 parallel convolutions
    output wire [64*(2*DATA_WIDTH+6)-1:0] conv_outs
);

    // Constant 9x1s vector for weights per channel (72 bits if DATA_WIDTH = 8)
    localparam [9*DATA_WIDTH-1:0] CONST_ONES = {9{8'd1}};  // 9 weights of value 1
    
    wire total_window_done;
    
    rgb_window_generator #(.DATA_WIDTH(DATA_WIDTH)) window (
            
                .clk(clk),
                .rst(rst),
                .pixel_in_r(pixel_in_r),
                .pixel_in_g(pixel_in_g),
                .pixel_in_b(pixel_in_b),
                .pixel_valid_r(pixel_valid_r),
                .pixel_valid_g(pixel_valid_g),
                .pixel_valid_b(pixel_valid_b),
                .output_col_r(input_col_r),
                .output_col_g(input_col_g),
                .output_col_b(input_col_b),
                .done(total_window_done)
            
            );

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : conv_filters
            wire [9*DATA_WIDTH-1:0] wr = CONST_ONES;
            wire [9*DATA_WIDTH-1:0] wg = CONST_ONES;
            wire [9*DATA_WIDTH-1:0] wb = CONST_ONES;

            wire signed [2*DATA_WIDTH+5:0] conv_out_i;

            rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) conv_unit (
                .clk(clk),
                .rst(rst),
                .total_window_done(total_window_done),
                .load_weight(load_weight),
                .input_col_r(input_col_r),
                .input_col_g(input_col_g),
                .input_col_b(input_col_b),
                .weights_r(wr),
                .weights_g(wg),
                .weights_b(wb),
                .conv_out_rgb(conv_out_i)
            );

            assign conv_outs[(i+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i;
        end
    endgenerate

endmodule
