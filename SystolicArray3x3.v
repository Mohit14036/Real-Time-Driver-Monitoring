`timescale 1ns / 1ps

module systolic_array_3x3 #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire load_weight,

    input wire [3*DATA_WIDTH-1:0] input_col,       // 3 values per clock: one column
    input wire [9*DATA_WIDTH-1:0] filter_weights,  // 3x3 kernel weights

    output reg [2*DATA_WIDTH+3:0] conv_out  // final output
);

    // Input unpack: each row gets one value
    wire [DATA_WIDTH-1:0] in_val [0:2];
    assign in_val[0] = input_col[3*DATA_WIDTH-1 -: DATA_WIDTH];      // Row 0
    assign in_val[1] = input_col[2*DATA_WIDTH-1 -: DATA_WIDTH];      // Row 1
    assign in_val[2] = input_col[1*DATA_WIDTH-1 -: DATA_WIDTH];      // Row 2

    // Weight unpacking
    wire [DATA_WIDTH-1:0] weights[0:2][0:2];
    genvar i, j;
    generate
        for (i = 0; i < 3; i = i + 1) begin 
            for (j = 0; j < 3; j = j + 1) begin 
                assign weights[i][j] = 8'd1;//filter_weights[((i*3 + j + 1)*DATA_WIDTH - 1) -: DATA_WIDTH];
            end
        end
    endgenerate

    // Interconnects
    wire [DATA_WIDTH-1:0] data_wires [0:2][0:2];     // internal activations per PE
    wire [2*DATA_WIDTH-1:0] psum_wires [0:2][0:2];   // internal partial sums per PE

    // PE instantiation
    generate
        for (i = 0; i < 3; i = i + 1) begin : row
            for (j = 0; j < 3; j = j + 1) begin : col
                wire [DATA_WIDTH-1:0] data_in = (j == 0) ? in_val[i] : data_wires[i][j-1];

                PE #(.DATA_WIDTH(DATA_WIDTH)) pe (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_in),
                    .psum_in(0),  // vertical connections not used here
                    .weight_in(weights[i][j]),
                    .load_weight(load_weight),
                    .data_out(data_wires[i][j]),
                    .psum_out(psum_wires[i][j])
                );
            end
        end
    endgenerate

    // Output accumulation from last column only (PE[0][2], PE[1][2], PE[2][2])
    always @(posedge clk or posedge rst) begin
        if (rst)
            conv_out <= 0;
        else begin
            conv_out <= psum_wires[0][2] + psum_wires[1][2] + psum_wires[2][2]+psum_wires[0][1] + psum_wires[1][1] + psum_wires[2][1]+psum_wires[0][0] + psum_wires[1][0] + psum_wires[2][0];
            //$display("Time: %0t | Convolution Output: %0d", $time, conv_out);
        end
    end

endmodule
