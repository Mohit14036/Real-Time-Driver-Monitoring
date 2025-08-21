`timescale 1ns / 1ps

module SystolicArrayForN #(
    parameter DATA_WIDTH    = 8,
    parameter NUM_CHANNELS  = 64,
    parameter OUTPUT_CYCLES = 220
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,
    input  wire start_conv,
    input  wire col,

    input  wire [NUM_CHANNELS*3*DATA_WIDTH-1:0] input_col,  
    input  wire [NUM_CHANNELS*9*DATA_WIDTH-1:0] weights,   

    output reg [2*DATA_WIDTH*NUM_CHANNELS-1:0] conv_out_sum,
    output reg  conv_out_valid
);

    // -----------------------------------------
    wire [2*DATA_WIDTH-1:0] conv_out   [0:NUM_CHANNELS-1];
    wire [NUM_CHANNELS-1:0] conv_valid;  

    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : conv_channels
            SystolicArray #(
                .DATA_WIDTH(DATA_WIDTH),
                .OUTPUT_CYCLES(OUTPUT_CYCLES)
            ) conv_array (
                .clk(clk),
                .rst(rst),
                .load_weight(load_weight),
                .col(col),
                .input_col      ( input_col [(i+1)*3*DATA_WIDTH-1 -: 3*DATA_WIDTH] ),
                .filter_weights ( weights    [(i+1)*9*DATA_WIDTH-1 -: 9*DATA_WIDTH] ),
                .conv_out       ( conv_out[i] ),
                .conv_out_valid ( conv_valid[i] )
            );
        end
    endgenerate

    // -----------------------------------------
    reg [NUM_CHANNELS-1:0] conv_valid_d;
    always @(posedge clk or posedge rst) begin
        if (rst)
            conv_valid_d <= 0;
        else
            conv_valid_d <= conv_valid;
    end

    wire all_valid = &conv_valid_d;

    // Accumulate outputs
    integer k;
    reg [2*DATA_WIDTH*NUM_CHANNELS-1:0] acc_sum;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out_sum   <= 0;
            conv_out_valid <= 0;
            acc_sum        <= 0;
        end else if (start_conv) begin
            if (all_valid) begin
                acc_sum = 0;
                for (k = 0; k < NUM_CHANNELS; k = k + 1)
                    acc_sum = acc_sum + conv_out[k];
                conv_out_sum   <= acc_sum;
                conv_out_valid <= 1;
            end else begin
                conv_out_valid <= 0;
            end
        end else begin
            conv_out_sum   <= 0;
            conv_out_valid <= 0;
            acc_sum        <= 0;
        end
    end

endmodule
