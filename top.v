`timescale 1ns/1ps

module top#(
    parameter DATA_WIDTH    = 8,
    parameter OUT_W         = 222,
    parameter OUT_H         = 222,
    parameter OUTPUT_SIZE   = OUT_W*OUT_H, // 222*222
    parameter NUM_FILTERS0  = 3,
    parameter NUM_FILTERS1  = 3,
    parameter RESULT_WIDTH  = 2*DATA_WIDTH+6
)(
    input  wire clk,
    input  wire rst,

    // external image stream (into Layer-1)
    input  wire [3*DATA_WIDTH-1:0] input_col_r,
    input  wire [3*DATA_WIDTH-1:0] input_col_g,
    input  wire [3*DATA_WIDTH-1:0] input_col_b,
    input  wire                    load_weight,
    input  wire                    input_valid,

    // expose BRAM read ports for BOTH layers (for TB dumping)
    input  wire [17:0] rd_addr0_0, output wire [RESULT_WIDTH-1:0] rd_data0_0,
    input  wire [17:0] rd_addr0_1, output wire [RESULT_WIDTH-1:0] rd_data0_1,
    input  wire [17:0] rd_addr0_2, output wire [RESULT_WIDTH-1:0] rd_data0_2,

    input  wire [17:0] rd_addr1_0, output wire [(2*RESULT_WIDTH+6)-1:0] rd_data1_0,
    input  wire [17:0] rd_addr1_1, output wire [(2*RESULT_WIDTH+6)-1:0] rd_data1_1,
    input  wire [17:0] rd_addr1_2, output wire [(2*RESULT_WIDTH+6)-1:0] rd_data1_2,

    output wire done0,     // Layer-1 done
    output wire done_all   // Layer-2 done
);

    // ---------------------------
    // LAYER 1
    // ---------------------------
    rgb_conv_layer_64 #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_SIZE(OUTPUT_SIZE),
        .NUM_FILTERS(NUM_FILTERS0),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) layer0 (
        .clk(clk),
        .rst(rst),
        .input_col_r(input_col_r),
        .input_col_g(input_col_g),
        .input_col_b(input_col_b),
        .load_weight(load_weight),
        .input_valid(input_valid),

        .rd_addr0(rd_addr0_0), .rd_data0(rd_data0_0),
        .rd_addr1(rd_addr0_1), .rd_data1(rd_data0_1),
        .rd_addr2(rd_addr0_2), .rd_data2(rd_data0_2),

        .done(done0)
    );

    // ---------------------------
    // Simple streamer:
    // After done0, feed outputs of 3 BRAMs directly into Layer-2.
    // Each address produces (f0,f1,f2) → treated as (R,G,B).
    // ---------------------------
    reg [17:0] s_addr;
    reg        stream1_en;
    reg        l2_input_valid;

    reg [RESULT_WIDTH-1:0] f0, f1, f2;

    always @(posedge clk) begin
        if (rst) begin
            s_addr <= 0;
            stream1_en <= 0;
            l2_input_valid <= 0;
        end else begin
            if (done0 && !stream1_en) begin
                stream1_en <= 1'b1;
                s_addr <= 0;
            end else if (stream1_en) begin
                // read from all 3 BRAMs at once
                f0 <= rd_data0_0;
                f1 <= rd_data0_1;
                f2 <= rd_data0_2;

                l2_input_valid <= 1'b1;
                s_addr <= s_addr + 1;

                if (s_addr == OUTPUT_SIZE-1) begin
                    stream1_en <= 0;
                    l2_input_valid <= 0;
                end
            end else begin
                l2_input_valid <= 0;
            end
        end
    end

    // ---------------------------
    // LAYER 2
    // ---------------------------
    rgb_conv_layer_64 #(
        .DATA_WIDTH(RESULT_WIDTH),            // now each channel is wider
        .OUTPUT_SIZE((OUT_W-2)*(OUT_H-2)),   // 220*220
        .NUM_FILTERS(NUM_FILTERS1),
        .RESULT_WIDTH(2*RESULT_WIDTH+6)
    ) layer1 (
        .clk(clk),
        .rst(rst),
        .input_col_r({3{f0}}),   // replicate to form 3-high column
        .input_col_g({3{f1}}),
        .input_col_b({3{f2}}),
        .load_weight(load_weight),
        .input_valid(l2_input_valid),

        .rd_addr0(rd_addr1_0), .rd_data0(rd_data1_0),
        .rd_addr1(rd_addr1_1), .rd_data1(rd_data1_1),
        .rd_addr2(rd_addr1_2), .rd_data2(rd_data1_2),

        .done(done_all)
    );

endmodule
