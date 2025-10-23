`timescale 1ns / 1ps

module top #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL_SIZE = 5,
    parameter INPUT_CHANNELS_LAYER1 = 3,    
    parameter FILTERS_LAYER1 = 3,          
    parameter INPUT_CHANNELS_LAYER2 = FILTERS_LAYER1,
    parameter FILTERS_LAYER2 = 1            
)(
    (* keep = "true" *)input wire clk,
    (* keep = "true" *)input wire rst,
    (* keep = "true" *)input wire load_weight,

    (* keep = "true" *)input wire [INPUT_CHANNELS_LAYER1*DATA_WIDTH-1:0] pixel_in_flat,
    (* keep = "true" *)input wire [INPUT_CHANNELS_LAYER1-1:0] pixel_valid_flat,

   (* keep = "true" *) output wire [(FILTERS_LAYER2*(2*DATA_WIDTH+9))-1:0] conv_outs_layer2
);

    wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER1*DATA_WIDTH-1:0] input_win_layer1;
    wire start_conv_layer1;
    wire done_layer1;

    (* dont_touch = "true" *) rgb_window_generator #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMAGE_SIZE(224),
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_CHANNELS(INPUT_CHANNELS_LAYER1)
    ) window1 (
        .clk(clk),
        .rst(rst),
        .pixel_in_flat(pixel_in_flat),           // Flattened input
        .pixel_valid_flat(pixel_valid_flat),
        .output_win_flat(input_win_layer1),
        .done(done_layer1),
        .start_conv(start_conv_layer1)
    );

    wire [(2*DATA_WIDTH+8)*FILTERS_LAYER1-1:0] conv_outs_layer1;
    wire start_fifo_layer1[FILTERS_LAYER1-1:0];
    reg fifo_valid_layer1[FILTERS_LAYER1-1:0];

    genvar i;
    generate
        for (i = 0; i < FILTERS_LAYER1; i = i + 1) begin : conv1_filters
            // Weights for this filter: all ones for demo
            wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER1*DATA_WIDTH-1:0] weights_flat = 
                {KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER1{8'd1}};

            (* dont_touch = "true" *) rgb_conv #(
                .DATA_WIDTH(DATA_WIDTH),
                .KERNEL_SIZE(KERNEL_SIZE),
                .INPUT_CHANNELS(INPUT_CHANNELS_LAYER1)
            ) conv_unit (
                .clk(clk),
                .rst(rst),
                .load_weight(load_weight),
                .start_conv(start_conv_layer1),
                .input_win_flat(input_win_layer1),
                .weights_flat(weights_flat),
                .conv_outs_rgb(conv_outs_layer1[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .start_fifo(start_fifo_layer1[i])
            );

            always @(posedge clk) begin
                fifo_valid_layer1[i] <= start_fifo_layer1[i];
            end
        end
    endgenerate

    // ---------- Layer 2 ----------
    wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER2*(2*DATA_WIDTH+8)-1:0] input_win_layer2;
    wire start_conv_layer2;
    wire done_layer2;

    // Instantiate FIFOs to feed layer 2, one per filter from layer1
    wire [(2*DATA_WIDTH+8)-1:0] fifo_out_layer1[FILTERS_LAYER1-1:0];
    wire fifo_valid_out_layer1[FILTERS_LAYER1-1:0];

    generate
        for (i = 0; i < FILTERS_LAYER1; i = i + 1) begin : fifo_layer1_gen
            (* dont_touch = "true" *) FIFO #(
                .DATA_WIDTH(2*DATA_WIDTH+8),
                .FIFO_DEPTH(224*2*(KERNEL_SIZE-1))
            ) fifo_inst (
                .clk(clk),
                .rst(rst),
                .data_in(conv_outs_layer1[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .valid_in(fifo_valid_layer1[i]),
                .data_out(fifo_out_layer1[i]),
                .valid_out(fifo_valid_out_layer1[i])
            );
        end
    endgenerate

    // Flatten FIFO outputs to feed layer2 window generator
    wire [INPUT_CHANNELS_LAYER2*(2*DATA_WIDTH+8)-1:0] layer2_pixel_flat;
    generate
        for (i = 0; i < INPUT_CHANNELS_LAYER2; i = i + 1) begin : flatten_layer2_pixels
            assign layer2_pixel_flat[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)] = fifo_out_layer1[i];
        end
    endgenerate

    wire [INPUT_CHANNELS_LAYER2-1:0] layer2_pixel_valid_flat;
    generate
        for (i = 0; i < INPUT_CHANNELS_LAYER2; i = i + 1) begin
            assign layer2_pixel_valid_flat[i] = fifo_valid_out_layer1[i];
        end
    endgenerate

    (* dont_touch = "true" *) rgb_window_generator #(
        .DATA_WIDTH(2*DATA_WIDTH+8),
        .IMAGE_SIZE(222),
        .KERNEL_SIZE(KERNEL_SIZE),
        .INPUT_CHANNELS(INPUT_CHANNELS_LAYER2)
    ) window2 (
        .clk(clk),
        .rst(rst),
        .pixel_in_flat(layer2_pixel_flat),
        .pixel_valid_flat(layer2_pixel_valid_flat),
        .output_win_flat(input_win_layer2),
        .done(done_layer2),
        .start_conv(start_conv_layer2)
    );

    wire [(2*(2*DATA_WIDTH+8)+8)*FILTERS_LAYER2-1:0] conv_outs_layer2_full;
    wire start_fifo_layer2[FILTERS_LAYER2-1:0];
    reg fifo_valid_layer2[FILTERS_LAYER2-1:0];

    generate
        for (i = 0; i < FILTERS_LAYER2; i = i + 1) begin : conv2_filters
            // Weights all ones for demo
            wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER2*(2*DATA_WIDTH+8)-1:0] weights_flat = 
                {KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER2{22'd1}};

            (* dont_touch = "true" *) rgb_conv #(
                .DATA_WIDTH(2*DATA_WIDTH+8),
                .KERNEL_SIZE(KERNEL_SIZE),
                .INPUT_CHANNELS(INPUT_CHANNELS_LAYER2)
            ) conv_unit (
                .clk(clk),
                .rst(rst),
                .load_weight(load_weight),
                .start_conv(start_conv_layer2),
                .input_win_flat(input_win_layer2),
                .weights_flat(weights_flat),
                .conv_outs_rgb(conv_outs_layer2_full[(i+1)*(2*(2*DATA_WIDTH+8)+8)-1 -: (2*(2*DATA_WIDTH+8)+8)]),
                .start_fifo(start_fifo_layer2[i])
            );

            always @(posedge clk) begin
                fifo_valid_layer2[i] <= start_fifo_layer2[i];
            end

            assign conv_outs_layer2[(i+1)*(2*DATA_WIDTH+9)-1 -: (2*DATA_WIDTH+9)] =
                conv_outs_layer2_full[(i+1)*(2*(2*DATA_WIDTH+8)+8)-1 -: (2*DATA_WIDTH+9)];
        end
    endgenerate

endmodule
