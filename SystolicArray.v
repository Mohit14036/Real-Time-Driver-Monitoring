`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// SystolicArray - fixed / Verilog-2001 friendly version
// - Parameterized KERNEL
// - Avoids genvar / procedural-name collisions
// - Uses integer loop indices inside procedural blocks
// -----------------------------------------------------------------------------
module SystolicArray #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL     = 10,
    parameter PSUM_MARGIN = 4,
    parameter PSUM_WIDTH  = 2*DATA_WIDTH + PSUM_MARGIN,
    parameter CONV_MARGIN = 4,
    parameter CONV_OUT_WIDTH = PSUM_WIDTH + CONV_MARGIN,
    parameter WARMUP_CYCLES = KERNEL,
    parameter STALL_CYCLES  = 2,
    parameter OUTPUT_CYCLES = KERNEL
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          load_weight,
    input  wire                          col,                     // valid input column
    input  wire [KERNEL*DATA_WIDTH-1:0]  input_col,               // KERNEL activations per column
    input  wire [KERNEL*KERNEL*DATA_WIDTH-1:0] filter_weights,    // KERNEL x KERNEL weights

    output reg  [CONV_OUT_WIDTH-1:0]     conv_out,
    output reg                           conv_valid
);

    // generate indices
    genvar gi, gj;

    // procedural loop indices
    integer i, j, r;

    // counters
    reg [31:0] warmup_count;
    reg [31:0] output_count;
    reg [31:0] stall_count;

    // --------------------------
    // Unpack input column into an array in_val[0..KERNEL-1]
    // --------------------------
    wire [DATA_WIDTH-1:0] in_val [0:KERNEL-1];
    generate
        for (gi = 0; gi < KERNEL; gi = gi + 1) begin : UNPACK_INPUT
            // in_val[0] is the top-most element of the column (MSB side)
            assign in_val[gi] = input_col[(KERNEL-gi)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    // --------------------------
    // Unpack weights into weights[row][col] (row-major)
    // --------------------------
    wire [DATA_WIDTH-1:0] weights [0:KERNEL-1][0:KERNEL-1];
    generate
        for (gi = 0; gi < KERNEL; gi = gi + 1) begin : UNPACK_W_ROW
            for (gj = 0; gj < KERNEL; gj = gj + 1) begin : UNPACK_W_COL
                localparam integer IDX = (gi*KERNEL + gj);
                assign weights[gi][gj] = filter_weights[(IDX+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end
    endgenerate

    // --------------------------
    // Interconnect wires
    // --------------------------
    wire [DATA_WIDTH-1:0]   data_wires [0:KERNEL-1][0:KERNEL-1];
    wire [PSUM_WIDTH-1:0]   psum_wires  [0:KERNEL-1][0:KERNEL-1];

    // --------------------------
    // Instantiate the grid of PEs
    // --------------------------
    generate
        for (gi = 0; gi < KERNEL; gi = gi + 1) begin : ROWS
            for (gj = 0; gj < KERNEL; gj = gj + 1) begin : COLS
                // data_in: left neighbor's data_out or in_val[row] if first column
                wire [DATA_WIDTH-1:0] data_in_wire;
                assign data_in_wire = (gj == 0) ? in_val[gi] : data_wires[gi][gj-1];

                // psum_in: top neighbor's psum_out or zero if first row
                wire [PSUM_WIDTH-1:0] psum_in_wire;
                assign psum_in_wire = (gi == 0) ? {PSUM_WIDTH{1'b0}} : psum_wires[gi-1][gj];

                PE #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .PSUM_WIDTH(PSUM_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_in_wire),
                    .psum_in(psum_in_wire),
                    .weight_in(weights[gi][gj]),
                    .load_weight(load_weight),
                    .data_out(data_wires[gi][gj]),
                    .psum_out(psum_wires[gi][gj])
                );
            end
        end
    endgenerate

    // reduction accumulator (declared at module scope for Verilog-2001)
    reg [CONV_OUT_WIDTH-1:0] sum_reg;

    // --------------------------
    // FSM to produce conv_out from the last-column psums
    // conv_out = sum_{r=0..KERNEL-1} psum_wires[r][KERNEL-1]
    // --------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out       <= {CONV_OUT_WIDTH{1'b0}};
            conv_valid <= 1'b0;
            warmup_count   <= 32'd0;
            output_count   <= 32'd0;
            stall_count    <= 32'd0;
            sum_reg        <= {CONV_OUT_WIDTH{1'b0}};
        end else if (col) begin
            // warmup: wait until pipeline filled
            if (warmup_count < WARMUP_CYCLES) begin
                warmup_count <= warmup_count + 1;
                conv_valid <= 1'b0;
            end
            else if (stall_count != 0) begin
                stall_count <= stall_count - 1;
                conv_valid <= 1'b0;
            end
            else begin
                // compute sum of last-column psums
                sum_reg = {CONV_OUT_WIDTH{1'b0}};
                for (r = 0; r < KERNEL; r = r + 1) begin
                    sum_reg = sum_reg + {{(CONV_OUT_WIDTH-PSUM_WIDTH){1'b0}}, psum_wires[r][KERNEL-1]};
                end

                conv_out <= sum_reg;
                conv_valid <= 1'b1;

                // output pacing
                if (output_count == OUTPUT_CYCLES-1) begin
                    output_count <= 32'd0;
                    stall_count  <= STALL_CYCLES;
                end else begin
                    output_count <= output_count + 1;
                end
            end
        end else begin
            // if col is low, keep valid low
            conv_valid <= 1'b0;
        end
    end

endmodule