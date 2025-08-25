`timescale 1ns / 1ps

module rgb_systolic_array_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter OUT_WIDTH  = 223
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    input  wire [3*DATA_WIDTH-1:0] input_col_r,
    input  wire [3*DATA_WIDTH-1:0] input_col_g,
    input  wire [3*DATA_WIDTH-1:0] input_col_b,
    input  wire input_valid,

    input  wire [9*DATA_WIDTH-1:0] weights_r,
    input  wire [9*DATA_WIDTH-1:0] weights_g,
    input  wire [9*DATA_WIDTH-1:0] weights_b,

    output reg [2*DATA_WIDTH+5:0] conv_out_rgb,
    output reg conv_valid
);

    // internal conavolution wires
    wire [2*DATA_WIDTH+3:0] conv_r;
    wire [2*DATA_WIDTH+3:0] conv_g;
    wire [2*DATA_WIDTH+3:0] conv_b;

    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) red_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_r),
        .filter_weights(weights_r),
        .conv_out(conv_r)
    );

    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) green_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_g),
        .filter_weights(weights_g),
        .conv_out(conv_g)
    );

    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) blue_array (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .input_col(input_col_b),
        .filter_weights(weights_b),
        .conv_out(conv_b)
    );

    // ========================================================
    // VALID GENERATOR LOGIC with 6-cycle startup latency
    // ========================================================

    reg [8:0] pixel_cnt;   // counts up to OUT_WIDTH = 222
    reg [1:0] gap_cnt;     // counts the 2-cycle pause
    reg state;             // 0 = outputting, 1 = waiting gap

    reg [2:0] startup_cnt; // counts initial 6 cycles
    reg startup_done;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_out_rgb <= 0;
            conv_valid   <= 0;
            pixel_cnt    <= 0;
            gap_cnt      <= 0;
            state        <= 0;
            startup_cnt  <= 0;
            startup_done <= 0;
        end else begin
            if (input_valid) begin
                if (!startup_done) begin
                    // Wait 6 cycles before first output
                    if (startup_cnt == 3'd3) begin
                        startup_done <= 1;
                        startup_cnt  <= 0;
                    end else begin
                        startup_cnt <= startup_cnt + 1;
                    end
                    conv_valid <= 0;  // no output yet
                end else begin
                    // Normal pipeline operation
                    case (state)
                        0: begin // normal output state
                            conv_out_rgb <= conv_r + conv_g + conv_b;
                            conv_valid   <= 1'b1;
        
                            if (pixel_cnt == OUT_WIDTH-1) begin
                                pixel_cnt <= 0;
                                state     <= 1;   // go to gap
                                conv_valid<= 0;
                                gap_cnt   <= 1;
                            end else begin
                                pixel_cnt <= pixel_cnt + 1;
                            end
                        end
        
                        1: begin // gap state (2-cycle pause)
                            conv_valid <= 0;
                            if (gap_cnt == 1) begin
                                state <= 0;       // back to output
                                gap_cnt <= 1;
                            end else begin
                                gap_cnt <= gap_cnt + 1;
                            end
                        end
                    endcase
                end
            end else begin
                conv_valid <= 0; // no input, no output
            end
        end
    end

endmodule
