`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// SystolicArray - single-module version (PE inlined)
// -----------------------------------------------------------------------------
module SystolicArray #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL     = 10,
    parameter PSUM_MARGIN = 4,
    parameter PSUM_WIDTH  = 2*DATA_WIDTH + PSUM_MARGIN,
    parameter CONV_MARGIN = 4,
    parameter CONV_OUT_WIDTH = PSUM_WIDTH + CONV_MARGIN,
    parameter WARMUP_CYCLES = KERNEL,
    parameter STALL_CYCLES  = KERNEL-1,
    parameter OUTPUT_CYCLES = 222
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          load_weight,
    input  wire                          col,
    input  wire [KERNEL*DATA_WIDTH-1:0]  input_col,
    input  wire [KERNEL*KERNEL*DATA_WIDTH-1:0] filter_weights,

    output reg  [CONV_OUT_WIDTH-1:0]     conv_out,
    output reg                           conv_valid,
    output reg                           fifo_valid
);

    // procedural loop indices
    integer i, j, r;

    // counters
    reg [8:0] warmup_count, output_count, stall_count;

    // --------------------------
    // Unpack inputs
    // --------------------------
    wire [DATA_WIDTH-1:0] in_val [0:KERNEL-1];
    generate
        genvar gi, gj;
        for (gi = 0; gi < KERNEL; gi = gi + 1) begin : UNPACK_INPUT
            assign in_val[gi] = input_col[(KERNEL-gi)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

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
    // PE grid interconnects
    // --------------------------
    wire [DATA_WIDTH-1:0] data_wires [0:KERNEL-1][0:KERNEL-1];
    wire [PSUM_WIDTH-1:0] psum_wires [0:KERNEL-1][0:KERNEL-1];

    // --------------------------
    // Inline PE logic
    // --------------------------
    generate
        for (gi = 0; gi < KERNEL; gi = gi + 1) begin : ROWS
            for (gj = 0; gj < KERNEL; gj = gj + 1) begin : COLS

                // signals for each PE
                wire [DATA_WIDTH-1:0] data_in_wire;
                wire [PSUM_WIDTH-1:0] psum_in_wire;
                reg  [DATA_WIDTH-1:0] weight_reg;
                reg  [DATA_WIDTH-1:0] data_out_reg;
                reg  [PSUM_WIDTH-1:0] psum_out_reg;

                // connections
                assign data_in_wire = (gj == 0) ? in_val[gi] : data_wires[gi][gj-1];
                assign psum_in_wire = (gi == 0) ? {PSUM_WIDTH{1'b0}} : psum_wires[gi-1][gj];

                // Multiply-accumulate (DSP-based)
                wire [2*DATA_WIDTH-1:0] product_raw;
                assign product_raw = data_in_wire * weight_reg;

                always @(posedge clk or posedge rst) begin
                    if (rst) begin
                        weight_reg <= 0;
                    end else if (load_weight) begin
                        weight_reg <= weights[gi][gj];
                    end
                end

                always @(posedge clk or posedge rst) begin
                    if (rst) begin
                        psum_out_reg <= {PSUM_WIDTH{1'b0}};
                        data_out_reg <= {DATA_WIDTH{1'b0}};
                    end else begin
                        // multiply + accumulate
                        psum_out_reg <= psum_in_wire + product_raw;
                        data_out_reg <= data_in_wire;
                    end
                end

                // Outputs to next stage
                assign data_wires[gi][gj] = data_out_reg;
                assign psum_wires[gi][gj] = psum_out_reg;

            end
        end
    endgenerate

    // --------------------------
    // Output accumulation FSM
    // --------------------------
    reg [CONV_OUT_WIDTH-1:0] sum_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out     <= {CONV_OUT_WIDTH{1'b0}};
            conv_valid   <= 1'b0;
            fifo_valid   <= 1'b0;
            warmup_count <= 0;
            output_count <= 0;
            stall_count  <= 0;
            sum_reg      <= 0;
        end else if (col) begin
            if (warmup_count < WARMUP_CYCLES) begin
                warmup_count <= warmup_count + 1;
                conv_valid   <= 1'b0;
                fifo_valid   <= 1'b1;
            end
            else if (stall_count != 0) begin
                stall_count  <= stall_count - 1;
                conv_valid   <= 1'b0;
                fifo_valid   <= 1'b0;
            end
            else begin
                sum_reg = 0;
                for (r = 0; r < KERNEL; r = r + 1) begin
                    sum_reg = sum_reg + {{(CONV_OUT_WIDTH-PSUM_WIDTH){1'b0}}, psum_wires[r][KERNEL-1]};
                end
                conv_out   <= sum_reg;
                conv_valid <= 1'b1;
                fifo_valid <= 1'b1;

                if (output_count == OUTPUT_CYCLES-1) begin
                    output_count <= 0;
                    stall_count  <= STALL_CYCLES;
                end else begin
                    output_count <= output_count + 1;
                end
            end
        end else begin
            conv_valid <= 1'b0;
            fifo_valid <= 1'b0;
        end
    end
endmodule
