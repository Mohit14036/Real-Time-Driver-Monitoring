`timescale 1ns / 1ps

module rgb_conv #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL_SIZE = 10,
    parameter INPUT_CHANNELS = 3
)(
     (* keep = "true" *)input wire clk,
     (* keep = "true" *)input wire rst,
     (* keep = "true" *)input wire load_weight,
     (* keep = "true" *)input wire start_conv,

     (* keep = "true" *)input wire [INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_flat,

    (* keep = "true" *) input wire [INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_flat,

    (* keep = "true" *) output reg [(2*DATA_WIDTH+9)-1:0] conv_outs_rgb,
    (* keep = "true" *) output reg start_fifo
);

    wire [2*DATA_WIDTH+6:0] conv_out [INPUT_CHANNELS-1:0];
    wire [INPUT_CHANNELS-1:0] conv_valid;

    genvar i;
    generate
        for (i = 0; i < INPUT_CHANNELS; i = i + 1) begin : conv_channels
            // Extract per-channel window and weights from flattened input
            wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] input_channel = 
                input_win_flat[(i+1)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];
            wire [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weight_channel = 
                weights_flat[(i+1)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH];

            // Instantiate single-channel convolution
              (* dont_touch = "true" *)  conv #(
                .DATA_WIDTH(DATA_WIDTH),
                .KERNEL_SIZE(KERNEL_SIZE)
            ) conv_unit (
                .clk(clk),
                .rst(rst),
                .load_weight(load_weight),
                .input_col(input_channel),
                .filter_weights(weight_channel),
                .conv_out(conv_out[i]),
                .conv_valid(conv_valid[i])
            );
        end
    endgenerate

    integer j;
    always @(posedge clk) begin
        start_fifo <= start_conv;

        // Only output when all channels are valid
        if (&conv_valid) begin
            conv_outs_rgb <= 0;
            for (j = 0; j < INPUT_CHANNELS; j = j + 1) begin
                conv_outs_rgb <= conv_outs_rgb + conv_out[j];
            end
        end
    end

endmodule
