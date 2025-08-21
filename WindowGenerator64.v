`timescale 1ns / 1ps

module WindowGenerator64 #(
    parameter DATA_WIDTH   = 8,
    parameter IMAGE_SIZE   = 222,
    parameter NUM_FILTERS  = 64
)(
    input  wire clk,
    input  wire rst,

    // One pixel per filter per clock (packed bus)
    input  wire [NUM_FILTERS*DATA_WIDTH-1:0] pixel_in,
    input  wire pixel_valid,

    // Output: 64 filters × (3×1 column)
    output reg [NUM_FILTERS*3*DATA_WIDTH-1:0] output_col,

    output reg start_conv,
    output reg done,
    output reg col_valid,
    output reg take_col
);

    // Shift registers for each filter (2 previous rows per filter)
    reg [DATA_WIDTH-1:0] shift_reg [0:NUM_FILTERS-1][0:1][0:IMAGE_SIZE-1];

    integer i, j, f;
    integer pixel_count;

    always @(posedge clk) begin
        if (rst) begin
            for (f=0; f<NUM_FILTERS; f=f+1) begin
                for (i=0; i<2; i=i+1) begin
                    for (j=0; j<IMAGE_SIZE; j=j+1) begin
                        shift_reg[f][i][j] <= 0;
                    end
                end
            end
            pixel_count <= 0;
            output_col  <= 0;
            col_valid   <= 0;
            start_conv  <= 0;
            done        <= 0;
            take_col    <= 0;
        end 
        else if (pixel_valid) begin
            // === Update all filters in parallel ===
            for (f=0; f<NUM_FILTERS; f=f+1) begin
                // Current pixel
                shift_reg[f][0][0] <= pixel_in[f*DATA_WIDTH +: DATA_WIDTH];
                // Cascade into 2nd row buffer
                shift_reg[f][1][0] <= shift_reg[f][0][IMAGE_SIZE-1];

                // Shift register movement
                for (j=1; j<IMAGE_SIZE; j=j+1) begin
                    shift_reg[f][0][j] <= shift_reg[f][0][j-1];
                    shift_reg[f][1][j] <= shift_reg[f][1][j-1];
                end
            end

            pixel_count <= pixel_count + 1;

            // === Start outputting after warm-up ===
            if (pixel_count >= (2*IMAGE_SIZE)) begin
                col_valid <= 1;

                for (f=0; f<NUM_FILTERS; f=f+1) begin
                    // Pack each filter's 3×1 column in output_col
                    output_col[f*3*DATA_WIDTH + 2*DATA_WIDTH +: DATA_WIDTH] <= 
                        pixel_in[f*DATA_WIDTH +: DATA_WIDTH]; // current row
                    output_col[f*3*DATA_WIDTH + 1*DATA_WIDTH +: DATA_WIDTH] <= 
                        shift_reg[f][0][IMAGE_SIZE-1];       // prev row
                    output_col[f*3*DATA_WIDTH + 0*DATA_WIDTH +: DATA_WIDTH] <= 
                        shift_reg[f][1][IMAGE_SIZE-1];       // prev-prev row
                end

                if (pixel_count >= (2*IMAGE_SIZE)+4)
                    start_conv <= 1;
                if (pixel_count >= (2*IMAGE_SIZE)+7)
                    take_col <= 1;
            end

            // Frame done
            if (pixel_count == IMAGE_SIZE*IMAGE_SIZE) begin
                done <= 1;
            end
        end
    end

endmodule
