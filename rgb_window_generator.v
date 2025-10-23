`timescale 1ns / 1ps

module rgb_window_generator #(
    parameter DATA_WIDTH    = 8,
    parameter IMAGE_SIZE    = 224,
    parameter KERNEL_SIZE   = 5,
    parameter INPUT_CHANNELS = 3
)(
   (* keep = "true" *) input clk, 
   (* keep = "true" *)input rst,

    (* keep = "true" *)input [INPUT_CHANNELS*DATA_WIDTH-1:0] pixel_in_flat,
    (* keep = "true" *)input [INPUT_CHANNELS-1:0]           pixel_valid_flat,

    (* keep = "true" *)output reg [INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] output_win_flat,

    (* keep = "true" *)output reg start_conv,
    (* keep = "true" *)output reg done
);

    localparam IDLE   = 2'b00;
    localparam STREAM = 2'b01;
    localparam PAUSE  = 2'b10;
    localparam DONE   = 2'b11;

    reg [1:0] state;

   integer i, j, ch;
    integer count;

    reg [8:0] col_cnt;
    reg [7:0] row_cnt;
    integer pixel_count;

    reg [DATA_WIDTH-1:0] shift_reg  [0:INPUT_CHANNELS-1][0:KERNEL_SIZE-2][0:IMAGE_SIZE-1];
    reg [DATA_WIDTH-1:0] data_reg   [0:INPUT_CHANNELS-1][0:KERNEL_SIZE-2][0:KERNEL_SIZE-1];
    
    wire [DATA_WIDTH-1:0] pixel_in [0:INPUT_CHANNELS-1];
    generate
        genvar gch;
        for (gch = 0; gch < INPUT_CHANNELS; gch = gch + 1) begin
            assign pixel_in[gch] = pixel_in_flat[gch*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    integer start_window_pixel_count = (KERNEL_SIZE-1)*IMAGE_SIZE + KERNEL_SIZE-2;

    // ----------------------------------------
    // Reset logic
    // ----------------------------------------
    always @(posedge clk) begin
        if(rst) begin
            state       <= IDLE;
            col_cnt     <= 0;
            row_cnt     <= 0;
            pixel_count <= 0;
            start_conv  <= 0;
            done        <= 0;
            output_win_flat <= 0;

            for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                    for(j=0; j<IMAGE_SIZE; j=j+1) begin
                        shift_reg[ch][i][j] <= 0;
                    end
                    for(j=0; j<KERNEL_SIZE; j=j+1) begin
                        data_reg[ch][i][j] <= 0;
                    end
                end
            end
        end
        else begin
            case(state)
                IDLE: begin
                    start_conv <= 0;
                    done <= 0;
                    col_cnt <= 0;
                    row_cnt <= 0;
                    pixel_count <= 0;

                    // Wait until all channels are valid
                    if(&pixel_valid_flat) begin
                        state <= STREAM;
                        col_cnt <= 0;
                        for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                            shift_reg[ch][0][0] <= pixel_in[ch];
                        end
                    end
                end

                STREAM, PAUSE: begin
                    start_conv <= 0;

                    // Update shift and data registers per channel
                    for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                        // Incoming pixel
                        shift_reg[ch][0][0] <= pixel_in[ch];

                        // Shift first column
                        for(i=1; i<KERNEL_SIZE-1; i=i+1)
                            shift_reg[ch][i][0] <= shift_reg[ch][0][IMAGE_SIZE-1];

                        // Shift rest of row
                        for(i=0; i<KERNEL_SIZE-1; i=i+1)
                            for(j=1; j<IMAGE_SIZE; j=j+1)
                                shift_reg[ch][i][j] <= shift_reg[ch][i][j-1];

                        // Update data register
                        data_reg[ch][KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in[ch];
                        for(i=0; i<KERNEL_SIZE-1; i=i+1)
                            data_reg[ch][KERNEL_SIZE-2][i] <= shift_reg[ch][1-i][IMAGE_SIZE-1];

                        for(i=0; i<KERNEL_SIZE; i=i+1)
                            for(j=0; j<KERNEL_SIZE-3; j=j+1)
                                data_reg[ch][j][i] <= data_reg[ch][j+1][i];
                    end

                    pixel_count <= pixel_count + 1;

                    // Column/row counters
                    if(col_cnt == IMAGE_SIZE-1) begin
                        col_cnt <= 0;
                        if(row_cnt < IMAGE_SIZE-1)
                            row_cnt <= row_cnt + 1;
                    end else begin
                        col_cnt <= col_cnt + 1;
                    end

                    // Start convolution when enough pixels arrived
                    if(pixel_count >= start_window_pixel_count && col_cnt >= KERNEL_SIZE-2) begin
                        start_conv <= 1;

                        // Assemble output windows per channel
                        for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                            count = KERNEL_SIZE*KERNEL_SIZE-1;

                            // Last pixel
                            output_win_flat[ch*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH + count*DATA_WIDTH +: DATA_WIDTH] <= pixel_in[ch];
                            count = count - 1;

                            // Shift registers
                            for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                                output_win_flat[ch*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH + count*DATA_WIDTH +: DATA_WIDTH] <= shift_reg[ch][i][IMAGE_SIZE-1];
                                count = count - 1;
                            end

                            // Data registers
                            for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                                for(j=0; j<KERNEL_SIZE; j=j+1) begin
                                    output_win_flat[ch*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH + count*DATA_WIDTH +: DATA_WIDTH] <= data_reg[ch][KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                                    count = count - 1;
                                end
                            end
                        end
                    end

                    // State transitions
                    if(col_cnt < KERNEL_SIZE-1 || col_cnt == IMAGE_SIZE-1)
                        state <= PAUSE;
                    if(col_cnt == IMAGE_SIZE-1 && row_cnt == IMAGE_SIZE-1)
                        state <= DONE;
                    else if(col_cnt >= KERNEL_SIZE-2)
                        state <= STREAM;
                end

                DONE: begin
                    start_conv <= 0;
                    done <= 1;
                end
            endcase
        end
    end

endmodule
