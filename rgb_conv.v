`timescale 1ns / 1ps

module rgb_conv #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL_SIZE = 10
)(
    input wire clk,
    input wire rst,
    input wire load_weight,
    input wire start_conv,

    // Each color has 3x1 inputs per clock (3 rows)
    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_r,
    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_g,
    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_b,

    // Each color has its own 3x3 kernel
    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_r,
    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_g,
    input wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_b,

    output reg [(2*DATA_WIDTH+9)-1:0] conv_outs_rgb,
    output reg start_fifo
    // Final combined convolution output
    
);

     wire [2*DATA_WIDTH+6:0] conv_r;
     wire [2*DATA_WIDTH+6:0] conv_g;
     wire [2*DATA_WIDTH+6:0] conv_b;

    // Instantiate systolic array for Red channel
    conv #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(10)) red_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_win_r),
        .filter_weights(weights_r),
        .conv_out(conv_r),
        .conv_valid(conv_valid_r)
    );

    // Instantiate systolic array for Green channel
    conv #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(10)) green_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_win_g),
        .filter_weights(weights_g),
        .conv_out(conv_g),
        .conv_valid(conv_valid_g)
    );

    // Instantiate systolic array for Blue channel
    conv #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(10)) blue_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_win_b),
        .filter_weights(weights_b),
        .conv_out(conv_b),
        .conv_valid(conv_valid_b)
    );
    
    always@ (posedge clk) begin 
        start_fifo <= start_conv;
        
        if(conv_valid_r && conv_valid_g && conv_valid_b) begin
        
            conv_outs_rgb[1*(2*DATA_WIDTH+8)-1 -: 2*DATA_WIDTH+8] <= conv_r + conv_g + conv_b;
          //  conv_outs_rgb[2*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
            //conv_outs_rgb[3*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
            
        end 
    
    end

endmodule
