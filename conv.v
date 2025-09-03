`timescale 1ns / 1ps

module conv #(
    parameter DATA_WIDTH = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,
    
    input  wire [9*DATA_WIDTH-1:0] input_col,       // 3 values per clock: one column
    input  wire [9*DATA_WIDTH-1:0] filter_weights,  // 3x3 kernel weights

    output reg  [2*DATA_WIDTH+3:0] conv_out,        // final output
    output reg conv_valid
);

    // Weights (for now all 1)
    wire [DATA_WIDTH-1:0] weights[0:2][0:2];
    genvar i, j;
    generate
        for (i = 0; i < 3; i = i + 1) begin 
            for (j = 0; j < 3; j = j + 1) begin 
                assign weights[i][j] = 8'd1;
            end
        end
    endgenerate

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out       <= 0;
            conv_valid     <= 0;
            
        end else begin
        
            conv_out   <= (input_col[DATA_WIDTH-1:0]*weights[0][0]) + (input_col[2*DATA_WIDTH-1:DATA_WIDTH]*weights[0][1]) + (input_col[3*DATA_WIDTH-1:2*DATA_WIDTH]*weights[0][2]) + (input_col[4*DATA_WIDTH-1:3*DATA_WIDTH]*weights[1][0]) + (input_col[5*DATA_WIDTH-1:4*DATA_WIDTH]*weights[1][1]) + (input_col[6*DATA_WIDTH-1:5*DATA_WIDTH]*weights[1][2]) + (input_col[7*DATA_WIDTH-1:6*DATA_WIDTH]*weights[2][0]) + (input_col[8*DATA_WIDTH-1:7*DATA_WIDTH]*weights[2][1]) + (input_col[9*DATA_WIDTH-1:8*DATA_WIDTH]*weights[2][2]);
            conv_valid <= 1;
            
        end
    end

endmodule
