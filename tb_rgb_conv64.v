`timescale 1ns / 1ps

module tb_rgb_conv64;

    parameter DATA_WIDTH = 8;
    parameter HEIGHT = 224;
    parameter WIDTH =224;
    parameter NUM_FILTERS = 3;

    reg clk, rst, load_weight;
    reg [DATA_WIDTH-1:0] pixel_in_r, pixel_in_g, pixel_in_b;
    reg pixel_valid_r, pixel_valid_g, pixel_valid_b;
    //reg [9*DATA_WIDTH-1:0] weights_r, weights_g, weights_b;
    wire [3*(2*(2*DATA_WIDTH+6)+6)-1:0] conv_outs_f;
    //wire [3*(2*DATA_WIDTH+6)-1:0] conv_outs_f;
    wire conv_valid;
    reg [7:0] image_r [0:WIDTH*HEIGHT-1];
    reg [7:0] image_g [0:WIDTH*HEIGHT-1];
    reg [7:0] image_b [0:WIDTH*HEIGHT-1];

    integer out_file, i,f;

    // Clock generation
    always #5 clk = ~clk;

    // Generate 64 identical filters (with weights_r, weights_g, weights_b)
    //wire [64*9*DATA_WIDTH-1:0] weights_r_all, weights_g_all, weights_b_all;

    //genvar i;
    /*generate
        for (i = 0; i < NUM_FILTERS; i = i + 1) begin : weight_copy
            assign weights_r_all[(i+1)*9*DATA_WIDTH-1 -: 9*DATA_WIDTH] = weights_r;
            assign weights_g_all[(i+1)*9*DATA_WIDTH-1 -: 9*DATA_WIDTH] = weights_g;
            assign weights_b_all[(i+1)*9*DATA_WIDTH-1 -: 9*DATA_WIDTH] = weights_b;
        end
    endgenerate
*/
    // DUT instantiation
    rgb_conv_layer_64 #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .load_weight(load_weight),
        .pixel_in_r(pixel_in_r),
        .pixel_in_g(pixel_in_g),
        .pixel_in_b(pixel_in_b),
        .pixel_valid_r(pixel_valid_r),
        .pixel_valid_g(pixel_valid_g),
        .pixel_valid_b(pixel_valid_b),
        //.weights_r_all(weights_r_all),
        //.weights_g_all(weights_g_all),
        //.weights_b_all(weights_b_all),
        .conv_outs_2(conv_outs_f),
        .conv_outs_2_valid(conv_valid)
    );

    // Initial block
    initial begin
        clk = 0; rst = 1; load_weight = 0;

        // Set all weights to 1
        /*for (f = 0; f < 9; f = f + 1) begin
            weights_r[f*DATA_WIDTH +: DATA_WIDTH] = 8'd1;
            weights_g[f*DATA_WIDTH +: DATA_WIDTH] = 8'd1;
            weights_b[f*DATA_WIDTH +: DATA_WIDTH] = 8'd1;
        end*/

        // Wait and release reset
        #20 rst = 0;
        
        pixel_valid_r = 0;
        pixel_valid_g = 0;
        pixel_valid_b = 0;
        
        // Load image from memory files
        $readmemh("/home/mohit/Downloads/image_r.mem", image_r);
        $readmemh("/home/mohit/Downloads/image_g.mem", image_g);
        $readmemh("/home/mohit/Downloads/image_b.mem", image_b);
       @(posedge clk);
        // Load weights
        load_weight = 1;
        @(posedge clk);
        load_weight = 0;
        
        

        // Wait a few cycles to stabilize weights inside systolic array
        repeat (5) @(posedge clk);

        // Open output file
        out_file = $fopen("/home/mohit/Downloads/testing1.txt", "w");

        
        for(i = 0; i < WIDTH*HEIGHT; i=i+1) begin
        
            @(posedge clk);
        
            pixel_in_r = image_r[i];
            pixel_in_g = image_g[i];
            pixel_in_b = image_b[i];
            
            pixel_valid_r = 1;
            pixel_valid_g = 1;
            pixel_valid_b = 1;
         for (f = 0; f < NUM_FILTERS; f = f + 1) begin
                if(conv_valid) begin    
                //$fwrite(out_file, "%0d ", conv_outs_f[(f+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)]);
                $fwrite(out_file, "%0d ", conv_outs_f[(f+1)*(2*(2*DATA_WIDTH+6)+6)-1 -: (2*(2*DATA_WIDTH+6)+6)]);
                end
            end
            $fwrite(out_file, "\n");
        end
        

        $fclose(out_file);
        $display("Output written to output_112x112x64.txt");
        $finish;
    end

endmodule