`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// TB_SingleSecondLayer_RGB.v
// Testbench for SingleSecondLayer with RGB input (3 channels)
// Reads each channel from a separate hex file and feeds the DUT
// -----------------------------------------------------------------------------
module TB_SingleSecondLayer_RGB;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH   = 8;
    parameter IMAGE_SIZE   = 224;    // assume square image
    parameter NUM_CHANNELS = 3;      // RGB
    parameter NUM_FILTERS  = 3;      // example
    localparam NUM_PIXELS  = IMAGE_SIZE * IMAGE_SIZE;
    localparam VEC_WIDTH   = NUM_CHANNELS * DATA_WIDTH;
    localparam OUT_WIDTH   = 2*DATA_WIDTH + 8;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------
    reg clk;
    reg rst;
    reg load_weight;
    reg pixel_valid;
    reg [DATA_WIDTH-1:0] R_mem [0:NUM_PIXELS-1];
    reg [DATA_WIDTH-1:0] G_mem [0:NUM_PIXELS-1];
    reg [DATA_WIDTH-1:0] B_mem [0:NUM_PIXELS-1];
    reg [VEC_WIDTH-1:0] pixels_in;

    wire [NUM_FILTERS*OUT_WIDTH-1:0] conv_out;
    wire conv_valid;

    integer r_file, g_file, b_file;
    integer out_file;
    integer i, status;

    // -------------------------------------------------------------------------
    // Clock generation (100 MHz)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    SingleSecondLayer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMAGE_SIZE(IMAGE_SIZE),
        .NUM_CHANNELS(NUM_CHANNELS),
        .NUM_FILTERS(NUM_FILTERS),
        .KERNEL_SIZE(10)          // match your kernel size
    ) dut (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .pixels_in(pixels_in),
        .pixel_valid(pixel_valid),
        .conv_out(conv_out),
        .conv_out_valid(conv_valid)
    );

    // -------------------------------------------------------------------------
    // Testbench procedure
    // -------------------------------------------------------------------------
    initial begin
        // -----------------------------
        // Reset
        // -----------------------------
        rst = 1;
        load_weight = 0;
        pixel_valid = 0;
        pixels_in = {VEC_WIDTH{1'b0}};
        repeat (4) @(posedge clk);
        rst = 0;

        // -----------------------------
        // Load RGB hex files
        // -----------------------------
        r_file = $fopen("R_channel.mem", "r");
        g_file = $fopen("G_channel.mem", "r");
        b_file = $fopen("B_channel.mem", "r");

        if (r_file == 0 || g_file == 0 || b_file == 0) begin
            $display("ERROR: Cannot open one or more RGB files.");
            $finish;
        end

        for (i = 0; i < NUM_PIXELS; i = i + 1) begin
            status = $fscanf(r_file, "%h\n", R_mem[i]);
            status = $fscanf(g_file, "%h\n", G_mem[i]);
            status = $fscanf(b_file, "%h\n", B_mem[i]);
        end

        $fclose(r_file);
        $fclose(g_file);
        $fclose(b_file);

        $display("INFO: Loaded RGB pixel data (%0d pixels)", NUM_PIXELS);

        // -----------------------------
        // Load weights (if required)
        // -----------------------------
        @(posedge clk);
        load_weight = 1'b1;
        @(posedge clk);
        load_weight = 1'b0;
        repeat (5) @(posedge clk);

        // -----------------------------
        // Open output file
        // -----------------------------
        out_file = $fopen("cnn_output.txt", "w");
        if (out_file == 0) begin
            $display("ERROR: Cannot open output file.");
            $finish;
        end

        // -----------------------------
        // Feed pixels to DUT
        // -----------------------------
        for (i = 0; i < NUM_PIXELS; i = i + 1) begin
            @(posedge clk);
            pixels_in <= {R_mem[i], G_mem[i], B_mem[i]};
            pixel_valid <= 1'b1;

            // Capture output if valid
            if (conv_valid)
                $fwrite(out_file, "%h\n", conv_out);
        end

        // Stop feeding pixels
        @(posedge clk);
        pixel_valid <= 1'b0;
        pixels_in <= {VEC_WIDTH{1'b0}};

        // -----------------------------
        // Drain pipeline
        // -----------------------------
        repeat (1000) @(posedge clk) begin
            if (conv_valid) $fwrite(out_file, "%h\n", conv_out);
        end

        $fclose(out_file);
        $display("INFO: Simulation complete. Outputs saved to cnn_output.txt");
        $finish;
    end

endmodule
