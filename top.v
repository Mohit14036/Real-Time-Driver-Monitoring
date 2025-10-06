`timescale 1ns / 1ps

module top #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL_SIZE = 10
    
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
    output wire [(3*(2*(2*DATA_WIDTH+8)+8))-1:0] conv_outs_rgb_2
  
);

    // Constant 9x1s vector for weights per channel (72 bits if DATA_WIDTH = 8)
    localparam [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] CONST_ONES         = {KERNEL_SIZE*KERNEL_SIZE{8'd1}};  // 9 weights of value 1
    localparam [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] CONST_ONES_2 = {KERNEL_SIZE*KERNEL_SIZE{22'd1}};  // 9 weights of value 1
    
    wire total_window_done;
    wire start_conv;
    wire col;
    wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_r;
    wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_g;
    wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_b;
    
    
    wire start_fifo[2:0];
    reg fifo_valid [2:0];
 
    (* dont_touch = "true" *) rgb_window_generator #(.DATA_WIDTH(DATA_WIDTH),.IMAGE_SIZE(224),.KERNEL_SIZE(10)) window (
            
                .clk(clk),
                .rst(rst),
                .pixel_in_r(pixel_in_r),
                .pixel_in_g(pixel_in_g),
                .pixel_in_b(pixel_in_b),
                .pixel_valid_r(pixel_valid_r),
                .pixel_valid_g(pixel_valid_g),
                .pixel_valid_b(pixel_valid_b),
                .output_win_r(input_win_r),
                .output_win_g(input_win_g),
                .output_win_b(input_win_b),
                .done(total_window_done),
                .start_conv(start_conv)
            );
    wire  [(3*(2*DATA_WIDTH+8))-1:0] conv_outs_rgb;
    
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : conv_filters
            wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] wr = CONST_ONES;
            wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] wg = CONST_ONES;
            wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] wb = CONST_ONES;

            
            (* dont_touch = "true" *) rgb_conv #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(10)) conv_unit (
                .clk(clk),
                .rst(rst),
                .start_conv(start_conv),
            
                .load_weight(load_weight),
                .input_win_r(input_win_r),
                .input_win_g(input_win_g),
                .input_win_b(input_win_b),
                .weights_r(wr),
                .weights_g(wg),
                .weights_b(wb),
                .conv_outs_rgb(conv_outs_rgb[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .start_fifo(start_fifo[i])
                
            );
            
            always @(posedge clk) begin 
            
                fifo_valid[i] <= start_fifo[i];
            
            end
            //assign conv_outs_2[(i+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i;
        end
    endgenerate
   
    wire [(2*DATA_WIDTH+8)-1:0] pixel_in_r_2;
    wire [(2*DATA_WIDTH+8)-1:0] pixel_in_g_2;
    wire [(2*DATA_WIDTH+8)-1:0] pixel_in_b_2;
    
    wire pixel_valid_r_2;
    wire pixel_valid_g_2;
    wire pixel_valid_b_2;
    
    wire [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] input_win_r_2;
    wire [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] input_win_g_2;
    wire [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] input_win_b_2;
    
    wire total_window_done_2;
    wire start_conv_2;
    
   
    
    (* dont_touch = "true" *) FIFO #(.DATA_WIDTH(2*DATA_WIDTH+8), .FIFO_DEPTH(222*2*(KERNEL_SIZE-1))) r_fifo (
    
                .clk(clk),
                .rst(rst),
                
                .data_in(conv_outs_rgb[(1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .valid_in(fifo_valid[0]),
                
                .data_out(pixel_in_r_2),
                .valid_out(pixel_valid_r_2)
            
            );
            
        
     (* dont_touch = "true" *) FIFO #(.DATA_WIDTH(2*DATA_WIDTH+8), .FIFO_DEPTH(222*2*(KERNEL_SIZE-1))) g_fifo (
    
                .clk(clk),
                .rst(rst),
                
                .data_in(conv_outs_rgb[(2)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .valid_in(fifo_valid[1]),
                
                .data_out(pixel_in_g_2),
                .valid_out(pixel_valid_g_2)
            
            );
            
        
     (* dont_touch = "true" *) FIFO #(.DATA_WIDTH(2*DATA_WIDTH+8), .FIFO_DEPTH(222*2*(KERNEL_SIZE-1))) b_fifo (
    
                .clk(clk),
                .rst(rst),
                
                .data_in(conv_outs_rgb[(3)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .valid_in(fifo_valid[2]),
                
                .data_out(pixel_in_b_2),
                .valid_out(pixel_valid_b_2)
            
            );  
            
    /*always @(posedge clk) begin
        if (rst) begin
            pixel_in_r_2 <= 0;
            pixel_in_g_2 <= 0;
            pixel_in_b_2 <= 0;
            pixel_valid_r_2 <= 0;
            pixel_valid_g_2 <= 0;
            pixel_valid_b_2 <= 0;
        end else if (conv_outs_2_valid) begin
            
            
            
            pixel_in_r_2 <= conv_outs[(1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)];
            pixel_in_g_2 <= conv_outs[(2)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)];
            pixel_in_b_2 <= conv_outs[(3)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)];
    
            // Set valid flags
            pixel_valid_r_2 <= 1;
            pixel_valid_g_2 <= 1;
            pixel_valid_b_2 <= 1;
        end else begin
            pixel_valid_r_2 <= 0;
            pixel_valid_g_2 <= 0;
            pixel_valid_b_2 <= 0;
        end
    end*/

    wire start_fifo_2[2:0];
    reg fifo_valid_2;
    
    (* dont_touch = "true" *) rgb_window_generator #(.DATA_WIDTH((2*DATA_WIDTH+8)),.IMAGE_SIZE(222), .KERNEL_SIZE(10)) window1 (
            
                .clk(clk),
                .rst(rst),
                .pixel_in_r(pixel_in_r_2),
                .pixel_in_g(pixel_in_g_2),
                .pixel_in_b(pixel_in_b_2),
                .pixel_valid_r(pixel_valid_r_2),
                .pixel_valid_g(pixel_valid_g_2),
                .pixel_valid_b(pixel_valid_b_2),
                .output_win_r(input_win_r_2),
                .output_win_g(input_win_g_2),
                .output_win_b(input_win_b_2),
                .done(total_window_done_2),
                .start_conv(start_conv_2)
               
            );

    genvar j;
    generate
        for (j = 0; j < 3; j = j + 1) begin : conv_filters1
            wire [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] wr = CONST_ONES_2;
            wire [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] wg = CONST_ONES_2;
            wire [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] wb = CONST_ONES_2;

            

            (* dont_touch = "true" *) rgb_conv #(.DATA_WIDTH((2*DATA_WIDTH+8)), .KERNEL_SIZE(10)) conv_unit1 (
                .clk(clk),
                .rst(rst),
                .start_conv(start_conv_2),
                .load_weight(load_weight),
                .input_win_r(input_win_r_2),
                .input_win_g(input_win_g_2),
                .input_win_b(input_win_b_2),
                .weights_r(wr),
                .weights_g(wg),
                .weights_b(wb),
                .conv_outs_rgb(conv_outs_rgb_2[(j+1)*(2*(2*DATA_WIDTH+8)+8)-1 -: (2*(2*DATA_WIDTH+8)+8)]),
                .start_fifo(start_fifo_2[j])

                
            );
            
            always @(posedge clk) begin 
            
                fifo_valid_2 <= start_fifo_2[j];
            
            end
            //assign conv_outs_2[(j+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i_2;
        end
    endgenerate
    

endmodule
