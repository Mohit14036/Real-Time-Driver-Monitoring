`timescale 1ns / 1ps

module rgb_conv #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL_SIZE = 3,
    parameter INPUT_CHANNELS = 3,
    parameter IMAGE_SIZE = 224

)(
    (* keep = "true" *) input wire clk,
    (* keep = "true" *) input wire rst,
    (* keep = "true" *) input wire load_weight,
    (* keep = "true" *) input wire start_conv,
    (* keep = "true" *) input wire col,
    
    // Each color has 3x1 inputs per clock (3 rows)
    (* keep = "true" *)input wire [INPUT_CHANNELS*KERNEL_SIZE*DATA_WIDTH-1:0] input_win_flat,

    (* keep = "true" *) input wire [INPUT_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_flat,

    (* keep = "true" *) output reg [DATA_WIDTH-1:0] conv_outs_rgb,
    (* keep = "true" *) output reg start_fifo
    // Final combined convolution output
    
);

     (* keep = "true" *) wire [2*DATA_WIDTH+7:0] conv_out [INPUT_CHANNELS-1:0];
     (* keep = "true" *) wire [INPUT_CHANNELS-1:0] conv_valid;
     (* keep = "true" *) wire [INPUT_CHANNELS-1:0] fifo_valid;
     (* keep = "true" *) reg [(2*DATA_WIDTH+8):0] conv_outs;
     (* keep = "true" *) reg [DATA_WIDTH-1:0] scaled;
     (* keep = "true" *) reg start_conv_delayed;
     
    genvar i;
    generate
        for (i = 0; i < INPUT_CHANNELS; i = i + 1) begin : conv_channels
            
            // Instantiate single-channel convolution
              (* dont_touch = "true" *)  SystolicArray #(
                .DATA_WIDTH(DATA_WIDTH),
                .KERNEL(KERNEL_SIZE), 
                .OUTPUT_CYCLES (IMAGE_SIZE-KERNEL_SIZE+1)
            ) conv_unit (
                .clk(clk),
                .rst(rst),
                .load_weight(load_weight),
                .input_col(input_win_flat[(i+1)*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*DATA_WIDTH]),
                .filter_weights(weights_flat[(i+1)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1 -: KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH]),
                .col(col),
                .conv_out(conv_out[i]),
                .conv_valid(conv_valid[i]),
                .fifo_valid(fifo_valid[i])
            );
        end
    endgenerate
    
    integer j;
    always@ (posedge clk) begin 
        start_conv_delayed <= start_conv;
        start_fifo <= start_conv_delayed && fifo_valid[0];
        if(rst) begin
            conv_outs = 0;
            scaled <= 0;
            conv_outs_rgb <= 0;
        end
        
        else if(&conv_valid && start_conv) begin
            conv_outs = 0;
            for (j = 0; j < INPUT_CHANNELS; j = j + 1) begin
                    conv_outs = conv_outs + conv_out[j];
            end 
            scaled <= (conv_outs * 1638 + (1<<13)) >> 14;  
            
            if(scaled > 255)
                conv_outs_rgb <= 8'd255;
            else if(scaled < 0)
                conv_outs_rgb <= 8'd0;
            else
                conv_outs_rgb <= scaled[7:0];        
        end 
        
//        else begin
        
//            conv_outs = 0;
//            scaled <= 0;
//            conv_outs_rgb <= 0;
            
//        end
    
    end

endmodule
