`timescale 1ns / 1ps

module systolic_array_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter OUTPUT_CYCLES=222
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,
    
    input  wire col,
    input  wire [3*DATA_WIDTH-1:0] input_col,       // 3 values per clock: one column
    input  wire [9*DATA_WIDTH-1:0] filter_weights,  // 3x3 kernel weights

    output reg  [2*DATA_WIDTH+3:0] conv_out,        // final output
    output reg  conv_out_valid
);

    // Warmup, output, stall
    localparam WARMUP_CYCLES = 3;
    localparam STALL_CYCLES  = 2;

    reg [3:0] warmup_count;
    reg [7:0] output_count;
    reg [2:0] stall_count;

    // Input unpack
    wire [DATA_WIDTH-1:0] in_val [0:2];
    assign in_val[0] = input_col[3*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val[1] = input_col[2*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val[2] = input_col[1*DATA_WIDTH-1 -: DATA_WIDTH];

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

    // Interconnects
    wire [DATA_WIDTH-1:0]   data_wires [0:2][0:2];
    wire [2*DATA_WIDTH-1:0] psum_wires [0:2][0:2];

    // PE instantiation
    generate
        for (i = 0; i < 3; i = i + 1) begin : row
            for (j = 0; j < 3; j = j + 1) begin : col_j
                wire [DATA_WIDTH-1:0] data_in = (j == 0) ? in_val[i] : data_wires[i][j-1];

                PE #(.DATA_WIDTH(DATA_WIDTH)) pe (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_in),
                    .psum_in(0), 
                    .weight_in(weights[i][j]),
                    .load_weight(load_weight),
                    .data_out(data_wires[i][j]),
                    .psum_out(psum_wires[i][j])
                );
            end
        end
    endgenerate


    // FSM for warmup/output/stall cycles
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out       <= 0;
            conv_out_valid <= 0;
            warmup_count   <= 0;
            output_count   <= 0;
            stall_count    <= 0;
        end else if (col) begin
            // First wait for warmup cycles
            if (warmup_count < WARMUP_CYCLES) begin
                warmup_count   <= warmup_count + 1;
                conv_out_valid <= 0;
            end
            // Then produce outputs
            else if (stall_count != 0) begin
                // we are in stall mode
                stall_count    <= stall_count - 1;
                conv_out_valid <= 0;
            end else begin
                // Normal output
                conv_out <= psum_wires[0][2] + psum_wires[1][2] + psum_wires[2][2] +
                            psum_wires[0][1] + psum_wires[1][1] + psum_wires[2][1] +
                            psum_wires[0][0] + psum_wires[1][0] + psum_wires[2][0];
                conv_out_valid <= 1;

                if (output_count == OUTPUT_CYCLES-1) begin
                    output_count <= 0;
                    stall_count  <= STALL_CYCLES; // enter stall after 3 outputs
                end else begin
                    output_count <= output_count + 1;
                end
            end
        end
    end

endmodule
