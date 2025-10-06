`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// normal_conv.v (generalized)
// Multi-filter convolution using systolic arrays (parameterized KERNEL)
// Each filter spans all input channels
// -----------------------------------------------------------------------------
module normal_conv #(
    parameter DATA_WIDTH   = 8,
    parameter NUM_CHANNELS = 64,
    parameter NUM_FILTERS  = 64,
    parameter KERNEL_SIZE  = 10,                    // generalized kernel (e.g., 3, 5, 10...)
    parameter OUT_WIDTH    = (2*DATA_WIDTH + 12)    // safe output width
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    // Input window from WindowGenerator: NUM_CHANNELS × (KERNEL_SIZE * DATA_WIDTH)
    input  wire [NUM_CHANNELS*KERNEL_SIZE*DATA_WIDTH-1:0] input_col,

    // Weights: NUM_FILTERS × NUM_CHANNELS × (KERNEL_SIZE*KERNEL_SIZE)
    input  wire [NUM_FILTERS*NUM_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv_weights,

    // handshake
    input  wire col_valid,

    // Outputs: NUM_FILTERS × OUT_WIDTH
    output reg  [NUM_FILTERS*OUT_WIDTH-1:0] conv_out,
    output reg  conv_out_valid
);

    // -------------------------------------------------------------------------
    // Derived parameters (matches SystolicArray widths)
    // -------------------------------------------------------------------------
    localparam SA_PSUM_MARGIN    = 4;
    localparam SA_CONV_MARGIN    = 4;
    localparam SA_PSUM_WIDTH     = 2*DATA_WIDTH + SA_PSUM_MARGIN;
    localparam SA_CONV_OUT_WIDTH = SA_PSUM_WIDTH + SA_CONV_MARGIN;

    // -------------------------------------------------------------------------
    // Accumulator width: allow extra bits for summing NUM_CHANNELS terms
    // -------------------------------------------------------------------------
    localparam integer EXTRA_BITS = $clog2(NUM_CHANNELS) + 1;
    localparam integer ACC_WIDTH  = OUT_WIDTH + EXTRA_BITS;

    // -------------------------------------------------------------------------
    // Wires for SystolicArray outputs (flattened)
    // sa_out is flattened as [0 .. NUM_FILTERS*NUM_CHANNELS*SA_CONV_OUT_WIDTH-1]
    // sa_valid is one bit per (filter,channel)
    // -------------------------------------------------------------------------
    wire [NUM_FILTERS*NUM_CHANNELS*SA_CONV_OUT_WIDTH-1:0] sa_out;
    wire [NUM_FILTERS*NUM_CHANNELS-1:0]                   sa_valid;

    // -------------------------------------------------------------------------
    // Instantiate all SystolicArrays (NUM_FILTERS × NUM_CHANNELS)
    // -------------------------------------------------------------------------
    genvar fi, ci;
    generate
        for (fi = 0; fi < NUM_FILTERS; fi = fi + 1) begin : filter_loop
            for (ci = 0; ci < NUM_CHANNELS; ci = ci + 1) begin : chan_loop
                // compute per-SA weight slice base (in bits)
                localparam integer WT_PER_SA_BITS = KERNEL_SIZE * KERNEL_SIZE * DATA_WIDTH;
                localparam integer WT_IDX = (fi*NUM_CHANNELS + ci);
                wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] sa_weights;
                assign sa_weights = conv_weights[WT_IDX*WT_PER_SA_BITS + WT_PER_SA_BITS-1 -: WT_PER_SA_BITS];

                // compute per-SA output slice base (in bits)
                localparam integer SA_OUT_PER = SA_CONV_OUT_WIDTH;
                localparam integer SA_OUT_IDX = (fi*NUM_CHANNELS + ci);
                // declare a temporary wire slice for this SA's output
                wire [SA_CONV_OUT_WIDTH-1:0] sa_out_slice;

                SystolicArray #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .KERNEL(KERNEL_SIZE),
                    .WARMUP_CYCLES(KERNEL_SIZE),
                    .OUTPUT_CYCLES(KERNEL_SIZE*2)
                ) sa_inst (
                    .clk(clk),
                    .rst(rst),
                    .load_weight(load_weight),

                    .col(col_valid),
                    .input_col(input_col[(ci+1)*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*DATA_WIDTH]),
                    .filter_weights(sa_weights),

                    .conv_out(sa_out_slice),
                    .conv_out_valid(sa_valid[fi*NUM_CHANNELS + ci])
                );

                // place the slice into the flattened sa_out vector
                // left-hand side is a slice-assignment net (continuous assign)
                // create a wire alias to the correct location
                assign sa_out[SA_OUT_IDX*SA_OUT_PER + SA_OUT_PER-1 -: SA_OUT_PER] = sa_out_slice;
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Accumulate SystolicArray outputs across all channels for each filter
    // -------------------------------------------------------------------------
    integer f, c;
    reg signed [ACC_WIDTH-1:0] accum;
    reg [NUM_FILTERS-1:0] per_filter_valid;

    // temporary variables for indexing inside procedural block
    integer base_bit;
    reg signed [SA_CONV_OUT_WIDTH-1:0] sa_temp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out         <= { (NUM_FILTERS*OUT_WIDTH) {1'b0} };
            conv_out_valid   <= 1'b0;
            per_filter_valid <= {NUM_FILTERS{1'b0}};
        end else begin
            conv_out_valid <= 1'b0;

            // For each filter, check if all its channel outputs are valid
            for (f = 0; f < NUM_FILTERS; f = f + 1) begin
                per_filter_valid[f] = 1'b1;
                for (c = 0; c < NUM_CHANNELS; c = c + 1) begin
                    if (!sa_valid[f*NUM_CHANNELS + c])
                        per_filter_valid[f] = 1'b0;
                end
            end

            // Only output when *all* filters ready (optional: could output independently)
            if (&per_filter_valid) begin
                for (f = 0; f < NUM_FILTERS; f = f + 1) begin
                    accum = {ACC_WIDTH{1'b0}};
                    for (c = 0; c < NUM_CHANNELS; c = c + 1) begin
                        // compute flattened base (bit index) for (f,c) SA output
                        base_bit = (f*NUM_CHANNELS + c) * SA_CONV_OUT_WIDTH;
                        // extract the SA output slice and sign-extend into sa_temp
                        sa_temp = sa_out[base_bit + SA_CONV_OUT_WIDTH-1 -: SA_CONV_OUT_WIDTH];
                        // accumulate (sa_temp is signed? if not, adjust accordingly)
                        accum = accum + $signed(sa_temp);
                    end
                    // truncate/pack into conv_out word
                    conv_out[(f+1)*OUT_WIDTH-1 -: OUT_WIDTH] <= accum[OUT_WIDTH-1:0];
                end
                conv_out_valid <= 1'b1;
            end
        end
    end

endmodule
