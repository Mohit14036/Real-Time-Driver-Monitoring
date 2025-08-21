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
    output reg [3*(2*(2*DATA_WIDTH+6)+6)-1:0] conv_outs_2,
    //output reg [3*(2*DATA_WIDTH+6)-1:0] conv_outs_2,
    output reg conv_outs_2_valid
);

    // Constant 9x1s vector for weights per channel (72 bits if DATA_WIDTH = 8)
    localparam [9*DATA_WIDTH-1:0] CONST_ONES = {9{8'd1}};  // 9 weights of value 1
    
    wire total_window_done;
    wire start_conv;
    wire col;
    wire [3*DATA_WIDTH-1:0] input_col_r;
    wire [3*DATA_WIDTH-1:0] input_col_g;
    wire [3*DATA_WIDTH-1:0] input_col_b;
    
    reg [3*(2*DATA_WIDTH+6)-1:0] conv_outs;
    wire take_col;
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
                .done(total_window_done),
                .start_conv(start_conv),
                .col(col),
                .take_col(take_col)
            );

    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : conv_filters
            wire [9*DATA_WIDTH-1:0] wr = CONST_ONES;
            wire [9*DATA_WIDTH-1:0] wg = CONST_ONES;
            wire [9*DATA_WIDTH-1:0] wb = CONST_ONES;

            wire signed [2*DATA_WIDTH+5:0] conv_out_i;
            wire conv_valid_i;
            rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) conv_unit (
                .clk(clk),
                .rst(rst),
                .start_conv(start_conv),
            
                .load_weight(load_weight),
                .input_col_r(input_col_r),
                .input_col_g(input_col_g),
                .input_col_b(input_col_b),
                .weights_r(wr),
                .weights_g(wg),
                .weights_b(wb),
                .conv_out_rgb(conv_out_i),
                .conv_out_rgb_valid(conv_valid_i),
                .col(col)
            );
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    conv_outs[(i+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] <= 0;
                    conv_outs_2_valid <= 0;
                end else if (conv_valid_i) begin   // only latch when valid
                    conv_outs[(i+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] <= conv_out_i;
                    conv_outs_2_valid <= 1; 
                end
                else begin
                    conv_outs_2_valid <= 0;  //  not valid
                end
            end
            //assign conv_outs_2[(i+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i;
        end
    endgenerate
   
    reg [(2*DATA_WIDTH+6)-1:0] pixel_in_r_2;
    reg [(2*DATA_WIDTH+6)-1:0] pixel_in_g_2;
    reg [(2*DATA_WIDTH+6)-1:0] pixel_in_b_2;
    
    reg pixel_valid_r_2;
    reg pixel_valid_g_2;
    reg pixel_valid_b_2;
    
    wire [3*(2*DATA_WIDTH+6)-1:0] input_col_r_2;
    wire [3*(2*DATA_WIDTH+6)-1:0] input_col_g_2;
    wire [3*(2*DATA_WIDTH+6)-1:0] input_col_b_2;
    
    wire total_window_done_2;
    wire start_conv_2;
    
    always @(posedge clk) begin
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
    end

    
    wire col1,conv_valid_i1;
    
    rgb_window_generator #(.DATA_WIDTH((2*DATA_WIDTH+6)),.IMAGE_SIZE(222)) window1 (
            
                .clk(clk),
                .rst(rst),
                .pixel_in_r(pixel_in_r_2),
                .pixel_in_g(pixel_in_g_2),
                .pixel_in_b(pixel_in_b_2),
                .pixel_valid_r(pixel_valid_r_2),
                .pixel_valid_g(pixel_valid_g_2),
                .pixel_valid_b(pixel_valid_b_2),
                .output_col_r(input_col_r_2),
                .output_col_g(input_col_g_2),
                .output_col_b(input_col_b_2),
                .done(total_window_done_2),
                .start_conv(start_conv_2),
                .col(col1)
               
            );

    genvar j;
    generate
        for (j = 0; j < 3; j = j + 1) begin : conv_filters1
            wire [9*DATA_WIDTH-1:0] wr = CONST_ONES;
            wire [9*DATA_WIDTH-1:0] wg = CONST_ONES;
            wire [9*DATA_WIDTH-1:0] wb = CONST_ONES;

            wire signed [2*(2*DATA_WIDTH+6)+5:0] conv_out_i_2;

            rgb_systolic_array_3x3 #(.DATA_WIDTH((2*DATA_WIDTH+6)),.OUTPUT_CYCLES(220)) conv_unit1 (
                .clk(clk),
                .rst(rst),
                .start_conv(start_conv_2),
                .load_weight(load_weight),
                .input_col_r(input_col_r_2),
                .input_col_g(input_col_g_2),
                .input_col_b(input_col_b_2),
                .weights_r(wr),
                .weights_g(wg),
                .weights_b(wb),
                .conv_out_rgb(conv_out_i_2),
                .col(col1),
                .conv_out_rgb_valid(conv_valid_i1)

                
            );
            always @(posedge clk) begin
            if (rst) begin
                conv_outs_2[(j+1)(2(2*DATA_WIDTH+6)+6)-1 -: (2*(2*DATA_WIDTH+6)+6)] <= 0;
            end else begin
                conv_outs_2[(j+1)(2(2*DATA_WIDTH+6)+6)-1 -: (2*(2*DATA_WIDTH+6)+6)] <= conv_out_i_2;
            end
        end
            //assign conv_outs_2[(j+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i_2;
        end
    endgenerate
    

endmodule