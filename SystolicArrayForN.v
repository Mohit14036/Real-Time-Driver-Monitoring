`timescale 1ns / 1ps

module systolic_array_for_64 #(
    parameter DATA_WIDTH    = 8,
    parameter NUM_CHANNELS  = 64,
    parameter OUTPUT_CYCLES = 222
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,
    input  wire start_conv,
    input  wire col,

    // Each channel gets 3x1 inputs per clock (3 rows)
    input  wire [NUM_CHANNELS*3*DATA_WIDTH-1:0] input_col,  

    // Each channel has its own 3x3 kernel
    input  wire [NUM_CHANNELS*9*DATA_WIDTH-1:0] weights,   

    // Final combined convolution output (sum over 64 channels)
    output reg  [2*DATA_WIDTH+$clog2(NUM_CHANNELS)+3:0] conv_out_sum,
    output reg  conv_out_valid
);

    // -----------------------------------------
    // Per-channel outputs
    // -----------------------------------------
    wire [2*DATA_WIDTH+3:0] conv_out   [0:NUM_CHANNELS-1];
    wire [NUM_CHANNELS-1:0] conv_valid;  

    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : conv_channels
            systolic_array_3x3 #(
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
                .conv_out_valid ( conv_valid[i] )   // ✅ pack into vector
            );
        end
    endgenerate

    // -----------------------------------------
    wire all_valid = &conv_valid;

    integer k;

    // -----------------------------------------
    // Accumulate across channels
    // -----------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out_sum   <= 0;
            conv_out_valid <= 0;
        end 
        else if (!start_conv) begin
            conv_out_sum   <= 0;
            conv_out_valid <= 0;
        end 
        else if (all_valid) begin
            conv_out_sum = 0; 
            for (k = 0; k < NUM_CHANNELS; k = k + 1) begin
                conv_out_sum = conv_out_sum + conv_out[k];
            end
            conv_out_valid <= 1;
        end 
        else begin
            conv_out_valid <= 0;
        end
    end

endmodule
