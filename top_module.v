`timescale 1ns / 1ps

module top #(
    parameter DATA_WIDTH = 8,
    parameter KERNEL_SIZE = 5,
    parameter INPUT_CHANNELS_LAYER1 = 3,    
    parameter FILTERS_LAYER1 = 32,          
    parameter INPUT_CHANNELS_LAYER2 = FILTERS_LAYER1,
    parameter FILTERS_LAYER2 = 1    
    
)(
    (* keep = "true" *) input wire clk,
    (* keep = "true" *) input wire rst,
    (* keep = "true" *) input wire load_weight,

    // Shared input pixels for R, G, B
    (* keep = "true" *)input wire [INPUT_CHANNELS_LAYER1*DATA_WIDTH-1:0] pixel_in_flat,
    (* keep = "true" *)input wire [INPUT_CHANNELS_LAYER1-1:0] pixel_valid_flat,

    // Output of 64 parallel convolutions
    (* keep = "true" *) output wire [(FILTERS_LAYER2*(2*(2*DATA_WIDTH+8)+8))-1:0] conv_outs_rgb_2
  
);

    // Constant 9x1s vector for weights per channel (72 bits if DATA_WIDTH = 8)
    //localparam [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] CONST_ONES         = {KERNEL_SIZE*KERNEL_SIZE{8'd1}};  // 9 weights of value 1
    //localparam [KERNEL_SIZE*KERNEL_SIZE*(2*DATA_WIDTH+8)-1:0] CONST_ONES_2 = {KERNEL_SIZE*KERNEL_SIZE{22'd1}};  // 9 weights of value 1
    
    (* keep = "true" *) wire total_window_done;
    (* keep = "true" *) wire start_conv;
    (* keep = "true" *) wire col;
    (* keep = "true" *) wire [KERNEL_SIZE*INPUT_CHANNELS_LAYER1*DATA_WIDTH-1:0] input_win_layer1;
    
    
    (* keep = "true" *) wire start_fifo[2:0];
    (* keep = "true" *) reg fifo_valid [2:0];
 
    (* dont_touch = "true" *) rgb_window_generator #(.DATA_WIDTH(DATA_WIDTH),.IMAGE_SIZE(224),.KERNEL_SIZE(KERNEL_SIZE), 
        .INPUT_CHANNELS(INPUT_CHANNELS_LAYER1)) window (
            
                .clk(clk),
                .rst(rst),
                .pixel_in_flat(pixel_in_flat),           // Flattened input
                .pixel_valid_flat(pixel_valid_flat),
                .output_win_flat(input_win_layer1),
                .done(total_window_done),
                .start_conv(start_conv)
            );
    (* keep = "true" *) wire  [(FILTERS_LAYER1*(2*DATA_WIDTH+8))-1:0] conv_outs_rgb;
    
   genvar i;
   generate
       for (i = 0; i < FILTERS_LAYER1; i = i + 1) begin : conv_filters
            (* keep = "true" *) wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER1*DATA_WIDTH-1:0] weights_flat = 
                {KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER1{8'd1}};

            
            (* dont_touch = "true" *) rgb_conv #(.DATA_WIDTH(DATA_WIDTH), .KERNEL_SIZE(KERNEL_SIZE), .INPUT_CHANNELS(INPUT_CHANNELS_LAYER1)) conv_unit (
                .clk(clk),
                .rst(rst),
                .start_conv(start_conv),
            
                .load_weight(load_weight),
                .input_win_flat(input_win_layer1),
                .weights_flat(weights_flat),
                .conv_outs_rgb(conv_outs_rgb[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
                .start_fifo(start_fifo[i])
                
            );
            
            always @(posedge clk) begin 
            
                fifo_valid[i] <= start_fifo[i];
            
          end
            //assign conv_outs_2[(i+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i;
       end
   endgenerate
   
//    (* keep = "true" *) wire [INPUT_CHANNELS_LAYER2*(2*DATA_WIDTH+8)-1:0] layer2_pixel_flat;
//    (* keep = "true" *) wire [INPUT_CHANNELS_LAYER2-1:0] layer2_pixel_valid_flat;
//    (* keep = "true" *) wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER2*(2*DATA_WIDTH+8)-1:0] input_win_layer2;
    
//    (* keep = "true" *) wire total_window_done_2;
//    (* keep = "true" *) wire start_conv_2;
  


//    generate 
//        for (i = 0; i < FILTERS_LAYER1; i = i + 1) begin : fifo_layer1_gen
//            (* dont_touch = "true" *) FIFO #(.DATA_WIDTH(2*DATA_WIDTH+8), .FIFO_DEPTH(222*2*(KERNEL_SIZE-1))) fifo_inst (
            
//                        .clk(clk),
//                        .rst(rst),
                        
//                        .data_in(conv_outs_rgb[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
//                        .valid_in(fifo_valid[0]),
                        
//                        .data_out(layer2_pixel_flat[(i+1)*(2*DATA_WIDTH+8)-1 -: (2*DATA_WIDTH+8)]),
//                        .valid_out(layer2_pixel_valid_flat[i])
                    
//                    );
//        end 
//   endgenerate         
  

            
//    /*always @(posedge clk) begin
//        if (rst) begin
//            pixel_in_r_2 <= 0;
//            pixel_in_g_2 <= 0;
//            pixel_in_b_2 <= 0;
//            pixel_valid_r_2 <= 0;
//            pixel_valid_g_2 <= 0;
//            pixel_valid_b_2 <= 0;
//        end else if (conv_outs_2_valid) begin
            
            
            
//            pixel_in_r_2 <= conv_outs[(1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)];
//            pixel_in_g_2 <= conv_outs[(2)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)];
//            pixel_in_b_2 <= conv_outs[(3)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)];
    
//            // Set valid flags
//            pixel_valid_r_2 <= 1;
//            pixel_valid_g_2 <= 1;
//            pixel_valid_b_2 <= 1;
//        end else begin
//            pixel_valid_r_2 <= 0;
//            pixel_valid_g_2 <= 0;
//            pixel_valid_b_2 <= 0;
//        end
//    end*/

    
//    (* dont_touch = "true" *) rgb_window_generator #(.DATA_WIDTH((2*DATA_WIDTH+8)),.IMAGE_SIZE(220), .KERNEL_SIZE(KERNEL_SIZE), .INPUT_CHANNELS(INPUT_CHANNELS_LAYER2)) window1 (
            
//                .clk(clk),
//                .rst(rst),
//                .pixel_in_flat(layer2_pixel_flat),
//                .pixel_valid_flat(layer2_pixel_valid_flat),
//                .output_win_flat(input_win_layer2),
//                .done(total_window_done_2),
//                .start_conv(start_conv_2)
               
//            );
//    (* keep = "true" *) wire [(2*(2*DATA_WIDTH+8)+8)*FILTERS_LAYER2-1:0] conv_outs_layer2_full;
//    (* keep = "true" *) wire start_fifo_layer2[FILTERS_LAYER2-1:0];
//    (* keep = "true" *) reg fifo_valid_layer2[FILTERS_LAYER2-1:0];
    
//    genvar j;
//    generate
//        for (j = 0; j < FILTERS_LAYER2; j = j + 1) begin : conv_filters1
//            (* keep = "true" *)  wire [KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER2*(2*DATA_WIDTH+8)-1:0] weights_flat = 
//                {KERNEL_SIZE*KERNEL_SIZE*INPUT_CHANNELS_LAYER2{22'd1}};

            

//            (* dont_touch = "true" *) rgb_conv #(.DATA_WIDTH((2*DATA_WIDTH+8)), .KERNEL_SIZE(KERNEL_SIZE), .INPUT_CHANNELS(INPUT_CHANNELS_LAYER2)) conv_unit1 (
//                .clk(clk),
//                .rst(rst),
//                .start_conv(start_conv_2),
//                .load_weight(load_weight),
//                .input_win_flat(input_win_layer2),
//                .weights_flat(weights_flat),
//                .conv_outs_rgb(conv_outs_rgb_2[(j+1)*(2*(2*DATA_WIDTH+8)+8)-1 -: (2*(2*DATA_WIDTH+8)+8)]),
//                .start_fifo(start_fifo_layer2[j])
//            );
            
//            always @(posedge clk) begin 
            
//                fifo_valid_layer2[j] <= start_fifo_layer2[j];
            
//            end
//            //assign conv_outs_2[(j+1)*(2*DATA_WIDTH+6)-1 -: (2*DATA_WIDTH+6)] = conv_out_i_2;
//        end
//    endgenerate
    

endmodule