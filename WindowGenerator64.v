`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// WindowGenerator64 (parameterized KERNEL_SIZE)
// Generates NUM_FILTERS × (KERNEL_SIZE × 1) vertical column per cycle
// Inputs: one pixel per filter per clock (packed)
// -----------------------------------------------------------------------------
module WindowGenerator64 #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_SIZE   = 224,
    parameter NUM_FILTERS  = 3,
    parameter KERNEL_SIZE  = 10
)(
    input  wire                             clk,
    input  wire                             rst,

    // One pixel per filter per clock (packed bus)
    input  wire [NUM_FILTERS*DATA_WIDTH-1:0] pixel_in,
    input  wire                             pixel_valid,

    // Output: NUM_FILTERS × (KERNEL_SIZE × 1 column)
    output reg [NUM_FILTERS*KERNEL_SIZE*DATA_WIDTH-1:0] output_col,

    // Control signals
    output reg                              start_conv,
    output reg                              done,
    output reg                              col_valid,
    output reg                              take_col
);

    // Require KERNEL_SIZE >= 1
    localparam LINE_BUFFERS = (KERNEL_SIZE > 0) ? (KERNEL_SIZE - 1) : 0;

    // Line buffers: [filter][line_index][column_index]
    // NOTE: LINE_BUFFERS must be > 0 for the middle dimension to be valid.
    // In practice KERNEL_SIZE >= 2 for windowed convs (10x10 etc).
    reg [DATA_WIDTH-1:0] shift_reg [0:NUM_FILTERS-1][0:LINE_BUFFERS-1][0:IMAGE_SIZE-1];

    integer f, i, j;
    reg [31:0] pixel_count;

    // Reset / main logic
    always @(posedge clk) begin
        if (rst) begin
            // Clear line buffers
            for (f = 0; f < NUM_FILTERS; f = f + 1) begin
                for (i = 0; i < LINE_BUFFERS; i = i + 1) begin
                    for (j = 0; j < IMAGE_SIZE; j = j + 1) begin
                        shift_reg[f][i][j] <= {DATA_WIDTH{1'b0}};
                    end
                end
            end

            pixel_count <= 32'd0;
            output_col  <= {(NUM_FILTERS*KERNEL_SIZE*DATA_WIDTH){1'b0}};
            col_valid   <= 1'b0;
            start_conv  <= 1'b0;
            done        <= 1'b0;
            take_col    <= 1'b0;
        end else begin
            // Default: deassert col_valid unless a valid pixel drives it
            if (!pixel_valid)
                col_valid <= 1'b0;

            if (pixel_valid) begin
                // Shift vertical line buffers and horizontal shift within each line
                for (f = 0; f < NUM_FILTERS; f = f + 1) begin
                    // Insert current pixel into the first line buffer position (column 0)
                    if (LINE_BUFFERS > 0)
                        shift_reg[f][0][0] <= pixel_in[f*DATA_WIDTH +: DATA_WIDTH];

                    // Propagate newest column into deeper line buffers (take oldest column from prev line)
                    for (i = 1; i < LINE_BUFFERS; i = i + 1) begin
                        shift_reg[f][i][0] <= shift_reg[f][i-1][IMAGE_SIZE-1];
                    end

                    // Shift every line buffer horizontally (right shift)
                    for (i = 0; i < LINE_BUFFERS; i = i + 1) begin
                        for (j = 1; j < IMAGE_SIZE; j = j + 1) begin
                            shift_reg[f][i][j] <= shift_reg[f][i][j-1];
                        end
                    end
                end

                // Advance pixel counter
                pixel_count <= pixel_count + 1'b1;

                // Warm-up: require (KERNEL_SIZE-1) full rows buffered
                if (pixel_count >= (LINE_BUFFERS * IMAGE_SIZE)) begin
                    col_valid <= 1'b1;

                    // Build output_col for each filter:
                    // output_col per filter is packed as [ (KERNEL_SIZE-1) .. 0 ] rows,
                    // where index 0 is current pixel, index KERNEL_SIZE-1 is oldest buffered row.
                    for (f = 0; f < NUM_FILTERS; f = f + 1) begin
                        // Older buffered rows: line buffers hold rows 0..LINE_BUFFERS-1
                        if (LINE_BUFFERS > 0) begin
                            for (i = 0; i < LINE_BUFFERS; i = i + 1) begin
                                output_col[
                                    f*KERNEL_SIZE*DATA_WIDTH + (KERNEL_SIZE-1 - i)*DATA_WIDTH +: DATA_WIDTH
                                ] <= shift_reg[f][i][IMAGE_SIZE-1];
                            end
                        end

                        // Current pixel -> output position 0
                        output_col[
                            f*KERNEL_SIZE*DATA_WIDTH + 0*DATA_WIDTH +: DATA_WIDTH
                        ] <= pixel_in[f*DATA_WIDTH +: DATA_WIDTH];
                    end

                    // Simple timing signals (kept similar to original)
                    if (pixel_count >= (LINE_BUFFERS * IMAGE_SIZE) + 4)
                        start_conv <= 1'b1;
                    if (pixel_count >= (LINE_BUFFERS * IMAGE_SIZE) + 8)
                        take_col <= 1'b1;
                end

                // Frame done
                if (pixel_count == IMAGE_SIZE * IMAGE_SIZE) begin
                    done <= 1'b1;
                end
            end
        end
    end

endmodule
