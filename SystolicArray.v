`timescale 1ns / 1ps

module SystolicArray #(
    parameter DATA_WIDTH    = 8,
    parameter OUTPUT_CYCLES = 220
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,
    
    input  wire col,                              // valid input column
    input  wire [3*DATA_WIDTH-1:0] input_col,     // 3 pixels per column
    input  wire [9*DATA_WIDTH-1:0] filter_weights,// 3x3 kernel weights

    output reg  [2*DATA_WIDTH+3:0] conv_out,      // convolution result
    output reg  conv_out_valid
);

    // FSM control parameters
    localparam WARMUP_CYCLES = 3;
    localparam STALL_CYCLES  = 2;

    reg [3:0] warmup_count;
    reg [7:0] output_count;
    reg [2:0] stall_count;

    // --------------------------
    // Unpack inputs
    // --------------------------
    wire [DATA_WIDTH-1:0] in_val [0:2];
    assign in_val[0] = input_col[3*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val[1] = input_col[2*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val[2] = input_col[1*DATA_WIDTH-1 -: DATA_WIDTH];

    wire [DATA_WIDTH-1:0] weights[0:2][0:2];
    genvar i, j;
    generate
        for (i = 0; i < 3; i = i + 1) begin : unpack_w_row
            for (j = 0; j < 3; j = j + 1) begin : unpack_w_col
                assign weights[i][j] = filter_weights[((3*i+j)+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end
    endgenerate

    // --------------------------
    // Interconnects
    // --------------------------
    wire [DATA_WIDTH-1:0]   data_wires [0:2][0:2];
    wire [2*DATA_WIDTH-1:0] psum_wires [0:2][0:2];

    // --------------------------
    // PE grid instantiation
    // --------------------------
    generate
        for (i = 0; i < 3; i = i + 1) begin : row
            for (j = 0; j < 3; j = j + 1) begin : col_j
                wire [DATA_WIDTH-1:0] data_in = (j == 0) ? in_val[i] : data_wires[i][j-1];
                wire [2*DATA_WIDTH-1:0] psum_in = (i == 0) ? 0 : psum_wires[i-1][j];

                PE #(.DATA_WIDTH(DATA_WIDTH)) pe (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_in),
                    .psum_in(psum_in),
                    .weight_in(weights[i][j]),
                    .load_weight(load_weight),
                    .data_out(data_wires[i][j]),
                    .psum_out(psum_wires[i][j])
                );
            end
        end
    endgenerate

    // --------------------------
    // FSM for warmup/output/stall
    // --------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out       <= 0;
            conv_out_valid <= 0;
            warmup_count   <= 0;
            output_count   <= 0;
            stall_count    <= 0;
        end 
        else if (col) begin
            if (warmup_count < WARMUP_CYCLES) begin
                warmup_count   <= warmup_count + 1;
                conv_out_valid <= 0;
            end 
            else if (stall_count != 0) begin
                stall_count    <= stall_count - 1;
                conv_out_valid <= 0;
            end 
            else begin
                conv_out <= psum_wires[0][2] + psum_wires[1][2] + psum_wires[2][2];
                conv_out_valid <= 1;

                if (output_count == OUTPUT_CYCLES-1) begin
                    output_count <= 0;
                    stall_count  <= STALL_CYCLES;
                end 
                else begin
                    output_count <= output_count + 1;
                end
            end
        end
    end

endmodule
