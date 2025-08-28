`timescale 1ns/1ps

module rgb_conv_layer_64 #(
    parameter DATA_WIDTH   = 8,
    parameter OUTPUT_SIZE  = 222*222,             // one filter output size
    parameter RESULT_WIDTH = 2*DATA_WIDTH+6
)(
    input  wire clk,
    input  wire rst,
    input  wire [3*DATA_WIDTH-1:0] input_col_r,
    input  wire [3*DATA_WIDTH-1:0] input_col_g,
    input  wire [3*DATA_WIDTH-1:0] input_col_b,
    input  wire load_weight,
    input  wire input_valid,
    output reg  done,

    // BRAM read interface (for testbench / top layer use)
    input  wire [17:0] rd_addr0_0,
    output wire [RESULT_WIDTH-1:0] rd_data0_0,
    input  wire [17:0] rd_addr1_0,
    output wire [RESULT_WIDTH-1:0] rd_data1_0,
    input  wire [17:0] rd_addr2_0,
    output wire [RESULT_WIDTH-1:0] rd_data2_0,
    
    
    
     input  wire [17:0] rd_addr0_1,
    output wire [RESULT_WIDTH-1:0] rd_data0_1,
    input  wire [17:0] rd_addr1_1,
    output wire [RESULT_WIDTH-1:0] rd_data1_1,
    input  wire [17:0] rd_addr2_1,
    output wire [RESULT_WIDTH-1:0] rd_data2_1,
    
    
     input  wire [17:0] rd_addr0_2,
    output wire [RESULT_WIDTH-1:0] rd_data0_2,
    input  wire [17:0] rd_addr1_2,
    output wire [RESULT_WIDTH-1:0] rd_data1_2,
    input  wire [17:0] rd_addr2_2,
    output wire [RESULT_WIDTH-1:0] rd_data2_2
);

    // -------------------------------
    // CONSTANT WEIGHTS (all ones)
    // -------------------------------
    localparam [9*DATA_WIDTH-1:0] CONST_ONES = {9{8'd1}};

    wire [RESULT_WIDTH-1:0] conv_out0, conv_out1, conv_out2;
    wire conv_valid0, conv_valid1, conv_valid2;

    // Three identical convolution filters
    rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_conv0 (
        .clk(clk), .rst(rst), .load_weight(load_weight), .input_valid(input_valid),
        .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
        .weights_r(CONST_ONES), .weights_g(CONST_ONES), .weights_b(CONST_ONES),
        .conv_out_rgb(conv_out0), .conv_valid(conv_valid0)
    );

    rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_conv1 (
        .clk(clk), .rst(rst), .load_weight(load_weight), .input_valid(input_valid),
        .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
        .weights_r(CONST_ONES), .weights_g(CONST_ONES), .weights_b(CONST_ONES),
        .conv_out_rgb(conv_out1), .conv_valid(conv_valid1)
    );

    rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_conv2 (
        .clk(clk), .rst(rst), .load_weight(load_weight), .input_valid(input_valid),
        .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
        .weights_r(CONST_ONES), .weights_g(CONST_ONES), .weights_b(CONST_ONES),
        .conv_out_rgb(conv_out2), .conv_valid(conv_valid2)
    );


    reg [17:0] wr_addr_cnt;
    reg we_d;   // registered write enable
    reg [RESULT_WIDTH-1:0] din0_d, din1_d, din2_d;

    wire fire = conv_valid0 & conv_valid1 & conv_valid2;

    always @(posedge clk) begin
        if (rst) begin
            wr_addr_cnt <= 18'd0;
            we_d        <= 1'b0;
            done        <= 1'b0;
        end else begin
            we_d <= 1'b0; // default

            if (fire) begin
                din0_d <= conv_out0;
                din1_d <= conv_out1;
                din2_d <= conv_out2;

                we_d <= 1'b1;

                if (wr_addr_cnt == OUTPUT_SIZE-3) begin
                    done <= 1'b1;
                end else begin
                    wr_addr_cnt <= wr_addr_cnt + 1'b1;
                end
            end
        end
    end


    bram #(.DATA_WIDTH(RESULT_WIDTH), .DEPTH(OUTPUT_SIZE)) bram0 (
        .clk(clk), .we(we_d), .wr_addr(wr_addr_cnt), .din(din0_d),
        .rd_addr0(rd_addr0_0), .dout0(rd_data0_0),
        .rd_addr1(rd_addr0_1), .dout1(rd_data0_1),  
        .rd_addr2(rd_addr0_2), .dout2(rd_data0_2)   
    );

    bram #(.DATA_WIDTH(RESULT_WIDTH), .DEPTH(OUTPUT_SIZE)) bram1 (
        .clk(clk), .we(we_d), .wr_addr(wr_addr_cnt), .din(din1_d),
        .rd_addr0(rd_addr1_0), .dout0(rd_data1_0),
        .rd_addr1(rd_addr1_1), .dout1(rd_data1_1),
        .rd_addr2(rd_addr1_2), .dout2(rd_data1_2)
    );

    bram #(.DATA_WIDTH(RESULT_WIDTH), .DEPTH(OUTPUT_SIZE)) bram2 (
        .clk(clk), .we(we_d), .wr_addr(wr_addr_cnt), .din(din2_d),
        .rd_addr0(rd_addr2_0), .dout0(rd_data2_0),
        .rd_addr1(rd_addr2_1), .dout1(rd_data2_1),
        .rd_addr2(rd_addr2_2), .dout2(rd_data2_2)
    );

endmodule
