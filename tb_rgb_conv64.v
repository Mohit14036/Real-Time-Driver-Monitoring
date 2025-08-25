`timescale 1ns / 1ps

module tb_conv_layer1;

    parameter DATA_WIDTH    = 8;
    parameter HEIGHT        = 224;
    parameter WIDTH         = 224;

    parameter OUT_HEIGHT    = 222;
    parameter OUT_WIDTH     = 222;
    parameter OUTPUT_SIZE   = OUT_HEIGHT*OUT_WIDTH; // 222*222

    parameter NUM_FILTERS0  = 3;
    parameter NUM_FILTERS1  = 3;

    parameter RESULT_WIDTH  = 2*DATA_WIDTH+6;

    reg clk, rst, load_weight;
    reg input_valid;

    reg [3*DATA_WIDTH-1:0] input_col_r, input_col_g, input_col_b;

    // Layer-1 BRAM read ports (explicit per filter, no arrays)
    reg  [17:0] rd_addr0_0, rd_addr0_1, rd_addr0_2;
    wire [RESULT_WIDTH-1:0] rd_data0_0, rd_data0_1, rd_data0_2;

    // Layer-2 BRAM read ports
    reg  [17:0] rd_addr1_0, rd_addr1_1, rd_addr1_2;
    wire [RESULT_WIDTH-1:0] rd_data1_0, rd_data1_1, rd_data1_2;

    wire done0, done_all;

    reg [7:0] image_r [0:WIDTH*HEIGHT-1];
    reg [7:0] image_g [0:WIDTH*HEIGHT-1];
    reg [7:0] image_b [0:WIDTH*HEIGHT-1];

    integer out_file0_0, out_file0_1, out_file0_2;
    integer out_file1_0, out_file1_1, out_file1_2;

    integer row, col, idx;

    always #5 clk = ~clk;

    top #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUT_W(OUT_WIDTH),
        .OUT_H(OUT_HEIGHT),
        .OUTPUT_SIZE(OUTPUT_SIZE),
        .NUM_FILTERS0(NUM_FILTERS0),
        .NUM_FILTERS1(NUM_FILTERS1),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .input_col_r(input_col_r),
        .input_col_g(input_col_g),
        .input_col_b(input_col_b),
        .load_weight(load_weight),
        .input_valid(input_valid),

        .rd_addr0_0(rd_addr0_0), .rd_data0_0(rd_data0_0),
        .rd_addr0_1(rd_addr0_1), .rd_data0_1(rd_data0_1),
        .rd_addr0_2(rd_addr0_2), .rd_data0_2(rd_data0_2),

        .rd_addr1_0(rd_addr1_0), .rd_data1_0(rd_data1_0),
        .rd_addr1_1(rd_addr1_1), .rd_data1_1(rd_data1_1),
        .rd_addr1_2(rd_addr1_2), .rd_data1_2(rd_data1_2),

        .done0(done0),
        .done_all(done_all)
    );

    initial begin
        // init
        clk = 0;
        rst = 1;
        load_weight = 0;
        input_valid = 0;
        rd_addr0_0 = 0; rd_addr0_1 = 0; rd_addr0_2 = 0;
        rd_addr1_0 = 0; rd_addr1_1 = 0; rd_addr1_2 = 0;

        #20 rst = 0;

        // load input planes
        $readmemh("/home/mohit/Downloads/image_r.mem", image_r);
        $readmemh("/home/mohit/Downloads/image_g.mem", image_g);
        $readmemh("/home/mohit/Downloads/image_b.mem", image_b);

        @(posedge clk);
        load_weight = 1;
        @(posedge clk);
        load_weight = 0;

        repeat (5) @(posedge clk);

        // Feed pixels (3-high column per cycle)
        for (row = 0; row < HEIGHT-2; row = row + 1) begin
            for (col = 0; col < WIDTH; col = col + 1) begin
                @(posedge clk);
                input_valid <= 1'b1;
                input_col_r <= {image_r[row*WIDTH + col],
                                image_r[(row+1)*WIDTH + col],
                                image_r[(row+2)*WIDTH + col]};
                input_col_g <= {image_g[row*WIDTH + col],
                                image_g[(row+1)*WIDTH + col],
                                image_g[(row+2)*WIDTH + col]};
                input_col_b <= {image_b[row*WIDTH + col],
                                image_b[(row+1)*WIDTH + col],
                                image_b[(row+2)*WIDTH + col]};
            end
        end

        @(posedge clk);
        input_valid <= 0;

        wait(done0);

        $display("Dumping Layer-1 outputs...");
        out_file0_0 = $fopen("/home/mohit/Downloads/layer1_out_f0.txt", "w");
        out_file0_1 = $fopen("/home/mohit/Downloads/layer1_out_f1.txt", "w");
        out_file0_2 = $fopen("/home/mohit/Downloads/layer1_out_f2.txt", "w");

        for (idx = 0; idx < OUTPUT_SIZE; idx = idx + 1) begin
            @(posedge clk);
            rd_addr0_0 = idx;
            rd_addr0_1 = idx;
            rd_addr0_2 = idx;
            @(posedge clk);
            $fwrite(out_file0_0, "%0d\n", rd_data0_0);
            $fwrite(out_file0_1, "%0d\n", rd_data0_1);
            $fwrite(out_file0_2, "%0d\n", rd_data0_2);
        end

        $fclose(out_file0_0);
        $fclose(out_file0_1);
        $fclose(out_file0_2);

        wait(done_all);

        $display("Dumping Layer-2 outputs...");
        out_file1_0 = $fopen("/home/mohit/Downloads/layer2_out_f0.txt", "w");
        out_file1_1 = $fopen("/home/mohit/Downloads/layer2_out_f1.txt", "w");
        out_file1_2 = $fopen("/home/mohit/Downloads/layer2_out_f2.txt", "w");

        for (idx = 0; idx < OUTPUT_SIZE; idx = idx + 1) begin
            @(posedge clk);
            rd_addr1_0 = idx;
            rd_addr1_1 = idx;
            rd_addr1_2 = idx;
            @(posedge clk);
            $fwrite(out_file1_0, "%0d\n", rd_data1_0);
            $fwrite(out_file1_1, "%0d\n", rd_data1_1);
            $fwrite(out_file1_2, "%0d\n", rd_data1_2);
        end

        $fclose(out_file1_0);
        $fclose(out_file1_1);
        $fclose(out_file1_2);

        $display("Both layers written to files.");
        #50;
        $finish;
    end

endmodule
