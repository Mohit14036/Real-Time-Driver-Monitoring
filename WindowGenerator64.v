`timescale 1ns / 1ps

module window_generator_64 #(
    parameter DATA_WIDTH  = 8,
    parameter IMAGE_SIZE  = 222,
    parameter NUM_CHANNELS= 64
)(
    input  wire clk,
    input  wire rst,

    // 64-channel pixel input (1 pixel per channel per clk)
    input  wire [NUM_CHANNELS*DATA_WIDTH-1:0] pixel_in,
    input  wire pixel_valid,

    // 64-channel 3x3 window output (flattened: 9*DATA_WIDTH per channel)
    output reg  [NUM_CHANNELS*9*DATA_WIDTH-1:0] output_win,

    output reg start_conv,
    output reg done
);

    // Line buffers: 2 previous rows per channel
    reg [DATA_WIDTH-1:0] linebuf0 [0:NUM_CHANNELS-1][0:IMAGE_SIZE-1];
    reg [DATA_WIDTH-1:0] linebuf1 [0:NUM_CHANNELS-1][0:IMAGE_SIZE-1];

    // Pixel counters
    integer row, col, ch;

    integer pixel_count;

    always @(posedge clk) begin
        if (rst) begin
            output_win <= 0;
            start_conv <= 0;
            done       <= 0;
            pixel_count<= 0;
        end
        else if (pixel_valid) begin
            // Increment pixel counter
            pixel_count <= pixel_count + 1;

            // Determine row,col of incoming pixel
            row = pixel_count / IMAGE_SIZE;
            col = pixel_count % IMAGE_SIZE;

            // For each channel, shift line buffers
            for (ch = 0; ch < NUM_CHANNELS; ch = ch+1) begin
                // push current pixel into linebuf0
                linebuf0[ch][col] <= pixel_in[(ch+1)*DATA_WIDTH-1 -: DATA_WIDTH];

                // push previous linebuf0 into linebuf1
                linebuf1[ch][col] <= linebuf0[ch][col];
            end

            // Valid 3x3 window only if row >= 2 and col >= 2
            if (row >= 2 && col >= 2) begin
                for (ch = 0; ch < NUM_CHANNELS; ch = ch+1) begin
                    // pick 3x3 window for this channel
                    output_win[ch*9*DATA_WIDTH + 0*DATA_WIDTH +: DATA_WIDTH] <= linebuf1[ch][col-2]; // row-2,col-2
                    output_win[ch*9*DATA_WIDTH + 1*DATA_WIDTH +: DATA_WIDTH] <= linebuf1[ch][col-1]; // row-2,col-1
                    output_win[ch*9*DATA_WIDTH + 2*DATA_WIDTH +: DATA_WIDTH] <= linebuf1[ch][col];   // row-2,col

                    output_win[ch*9*DATA_WIDTH + 3*DATA_WIDTH +: DATA_WIDTH] <= linebuf0[ch][col-2]; // row-1,col-2
                    output_win[ch*9*DATA_WIDTH + 4*DATA_WIDTH +: DATA_WIDTH] <= linebuf0[ch][col-1]; // row-1,col-1
                    output_win[ch*9*DATA_WIDTH + 5*DATA_WIDTH +: DATA_WIDTH] <= linebuf0[ch][col];   // row-1,col

                    output_win[ch*9*DATA_WIDTH + 6*DATA_WIDTH +: DATA_WIDTH] <= pixel_in[(ch+1)*DATA_WIDTH-1 -: DATA_WIDTH]; // row,col
                    output_win[ch*9*DATA_WIDTH + 7*DATA_WIDTH +: DATA_WIDTH] <= linebuf0[ch][col-1]; // NOTE: need register for current row col-1
                    output_win[ch*9*DATA_WIDTH + 8*DATA_WIDTH +: DATA_WIDTH] <= linebuf0[ch][col-2]; // NOTE: need register for current row col-2
                end
                start_conv <= 1;
            end

            if (pixel_count == IMAGE_SIZE*IMAGE_SIZE) begin
                done <= 1;
            end
        end
    end

endmodule
