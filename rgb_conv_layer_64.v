`timescale 1ns/1ps

module rgb_conv_layer_64#(
    parameter DATA_WIDTH   = 8,
    parameter OUTPUT_SIZE  = 222*222,             // one filter output size
    parameter RESULT_WIDTH = 2*DATA_WIDTH+6
)(
    input  wire clk,
    input  wire rst,
    input  wire [3*DATA_WIDTH-1:0] input_col_r,
    input  wire [3*DATA_WIDTH-1:0] input_col_g,
    input  wire [3*DATA_WIDTH-1:0] input_col_b,
    input  wire load_weight,
    input  wire input_valid,
    output reg  done,

    // BRAM read interface for testbench (separate ports for 3 BRAMs)
    input  wire [17:0] rd_addr0,
    output wire [RESULT_WIDTH-1:0] rd_data0,
    input  wire [17:0] rd_addr1,
    output wire [RESULT_WIDTH-1:0] rd_data1,
    input  wire [17:0] rd_addr2,
    output wire [RESULT_WIDTH-1:0] rd_data2
);

    
    localparam [9*DATA_WIDTH-1:0] CONST_ONES = {9{8'd1}};

    wire [RESULT_WIDTH-1:0] conv_out0, conv_out1, conv_out2;
    wire                    conv_valid0, conv_valid1, conv_valid2;

    rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_conv0 (
        .clk(clk), .rst(rst), .load_weight(load_weight), .input_valid(input_valid),
        .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
        .weights_r(CONST_ONES), .weights_g(CONST_ONES), .weights_b(CONST_ONES),
        .conv_out_rgb(conv_out0), .conv_valid(conv_valid0)
    );

    rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_conv1 (
        .clk(clk), .rst(rst), .load_weight(load_weight), .input_valid(input_valid),
        .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
        .weights_r(CONST_ONES), .weights_g(CONST_ONES), .weights_b(CONST_ONES),
        .conv_out_rgb(conv_out1), .conv_valid(conv_valid1)
    );

    rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) u_conv2 (
        .clk(clk), .rst(rst), .load_weight(load_weight), .input_valid(input_valid),
        .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
        .weights_r(CONST_ONES), .weights_g(CONST_ONES), .weights_b(CONST_ONES),
        .conv_out_rgb(conv_out2), .conv_valid(conv_valid2)
    );

    // ---------------------------------
    // 3 BRAM banks (one per filter)
    // Drive them with REGISTERED write controls (one-cycle pipeline)
    // ---------------------------------
    reg [17:0]              wr_addr_cnt;      // next free address counter
    reg [17:0]              wr_addr_q;        // address presented to BRAM on this cycle
    reg [RESULT_WIDTH-1:0]  din0_q, din1_q, din2_q; // data presented to BRAM on this cycle
    reg                     we_q;             // write enable presented to BRAM on this cycle

    wire fire = conv_valid0 & conv_valid1 & conv_valid2; // all 3 valid same cycle

    // capture stage: when fire=1, latch data & address for the *next* cycle write
    always @(posedge clk) begin
        if (rst) begin
            wr_addr_cnt <= 18'd0;
            wr_addr_q   <= 18'd0;
            din0_q      <= {RESULT_WIDTH{1'b0}};
            din1_q      <= {RESULT_WIDTH{1'b0}};
            din2_q      <= {RESULT_WIDTH{1'b0}};
            we_q        <= 1'b0;
            done        <= 1'b0;
        end else begin
            // default: no write
            we_q <= 1'b0;

            if (fire) begin
                // Latch current outputs and address to be used on the NEXT clock by BRAM
                din0_q    <= conv_out0;
                din1_q    <= conv_out1;
                din2_q    <= conv_out2;
                wr_addr_q <= wr_addr_cnt;    // write at current counter value
                we_q      <= 1'b1;           // arm a write for next cycle (BRAM sees previous value)

                // Bump the counter for the following sample
                wr_addr_cnt <= wr_addr_cnt + 18'd1;
            end

            // Assert done exactly on the cycle the LAST write is happening
            if (we_q && (wr_addr_q == OUTPUT_SIZE-3))
                done <= 1'b1;
        end
    end

    // 3 single-port synchronous BRAMs
    bram #(.DATA_WIDTH(RESULT_WIDTH), .DEPTH(OUTPUT_SIZE)) bram0 (
        .clk(clk), .we(we_q), .wr_addr(wr_addr_q), .din(din0_q),
        .rd_addr(rd_addr0), .dout(rd_data0)
    );

    bram #(.DATA_WIDTH(RESULT_WIDTH), .DEPTH(OUTPUT_SIZE)) bram1 (
        .clk(clk), .we(we_q), .wr_addr(wr_addr_q), .din(din1_q),
        .rd_addr(rd_addr1), .dout(rd_data1)
    );

    bram #(.DATA_WIDTH(RESULT_WIDTH), .DEPTH(OUTPUT_SIZE)) bram2 (
        .clk(clk), .we(we_q), .wr_addr(wr_addr_q), .din(din2_q),
        .rd_addr(rd_addr2), .dout(rd_data2)
    );

endmodule
