`timescale 1ns / 1ps

module rgb_systolic_array_3x3 #(
    parameter DATA_WIDTH = 8,
    parameter OUTPUT_CYCLES=222
)(
    input wire clk,
    input wire rst,
    input wire load_weight,
    input wire start_conv,

    // Each color has 3x1 inputs per clock (3 rows)
    input wire [3*DATA_WIDTH-1:0] input_win_r,
    input wire [3*DATA_WIDTH-1:0] input_win_g,
    input wire [3*DATA_WIDTH-1:0] input_win_b,

    // Each color has its own 3x3 kernel
    input wire [9*DATA_WIDTH-1:0] weights_r,
    input wire [9*DATA_WIDTH-1:0] weights_g,
    input wire [9*DATA_WIDTH-1:0] weights_b,

    (* keep = "true" *)output reg [(2*DATA_WIDTH+6)-1:0] conv_outs_rgb,
    output reg start_fifo
    // Final combined convolution output
    
);
    localparam WARMUP_CYCLES = 2;
    localparam STALL_CYCLES  = 1;
    
    
    reg [3:0] warmup_count;
    reg [7:0] output_count;
    reg [2:0] stall_count;
    
    
    reg [2*DATA_WIDTH+3:0] conv_r;
    reg [2*DATA_WIDTH+3:0] conv_g;
    reg [2*DATA_WIDTH+3:0] conv_b;
    
    wire [DATA_WIDTH-1:0] in_val_r [0:2];
    assign in_val_r[0] = input_win_r[3*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val_r[1] = input_win_r[2*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val_r[2] = input_win_r[1*DATA_WIDTH-1 -: DATA_WIDTH];
    
    wire [DATA_WIDTH-1:0] in_val_g [0:2];
    assign in_val_g[0] = input_win_g[3*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val_g[1] = input_win_g[2*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val_g[2] = input_win_g[1*DATA_WIDTH-1 -: DATA_WIDTH];
    
    wire [DATA_WIDTH-1:0] in_val_b [0:2];
    assign in_val_b[0] = input_win_b[3*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val_b[1] = input_win_b[2*DATA_WIDTH-1 -: DATA_WIDTH];
    assign in_val_b[2] = input_win_b[1*DATA_WIDTH-1 -: DATA_WIDTH];
    
    
    wire [DATA_WIDTH-1:0] weights[0:2][0:2];
    genvar ir, jr,ig,jg,ib,jb,i,j;
    generate
        for (i = 0; i < 3; i = i + 1) begin 
            for (j = 0; j < 3; j = j + 1) begin 
                assign weights[i][j] = 8'd1;
            end
        end
    endgenerate

    wire [DATA_WIDTH-1:0]   data_wires_r [0:2][0:2];
    wire [2*DATA_WIDTH-1:0] psum_wires_r [0:2][0:2];
    
    wire [DATA_WIDTH-1:0]   data_wires_g [0:2][0:2];
    wire [2*DATA_WIDTH-1:0] psum_wires_g [0:2][0:2];
    
    wire [DATA_WIDTH-1:0]   data_wires_b [0:2][0:2];
    wire [2*DATA_WIDTH-1:0] psum_wires_b [0:2][0:2];



    generate
        for (ir = 0; ir < 3; ir = ir + 1) begin : rowr
            for (jr = 0; jr < 3; jr = jr + 1) begin : colr_j
                wire [DATA_WIDTH-1:0] data_inr = (jr == 0) ? in_val_r[ir] : data_wires_r[ir][jr-1];

                PE #(.DATA_WIDTH(DATA_WIDTH)) pe (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_inr),
                    .psum_in(0), 
                    .weight_in(weights[ir][jr]),
                    .load_weight(load_weight),
                    .data_out(data_wires_r[ir][jr]),
                    .psum_out(psum_wires_r[ir][jr])
                );
            end
        end
    endgenerate
    
    
    
    generate
        for (ig = 0; ig < 3; ig = ig + 1) begin : rowg
            for (jg = 0; jg < 3; jg = jg + 1) begin : colg_j
                wire [DATA_WIDTH-1:0] data_ing = (jg == 0) ? in_val_g[ig] : data_wires_g[ig][jg-1];

                PE #(.DATA_WIDTH(DATA_WIDTH)) pe (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_ing),
                    .psum_in(0), 
                    .weight_in(weights[ig][jg]),
                    .load_weight(load_weight),
                    .data_out(data_wires_g[ig][jg]),
                    .psum_out(psum_wires_g[ig][jg])
                );
            end
        end
    endgenerate
    
    
    
    generate
        for (ib = 0; ib < 3; ib = ib + 1) begin : rowb
            for (jb = 0; jb < 3; jb = jb + 1) begin : colb_j
                wire [DATA_WIDTH-1:0] data_inb = (jb == 0) ? in_val_b[ib] : data_wires_b[ib][jb-1];

                PE #(.DATA_WIDTH(DATA_WIDTH)) pe (
                    .clk(clk),
                    .rst(rst),
                    .data_in(data_inb),
                    .psum_in(0), 
                    .weight_in(weights[ib][jb]),
                    .load_weight(load_weight),
                    .data_out(data_wires_b[ib][jb]),
                    .psum_out(psum_wires_b[ib][jb])
                );
            end
        end
    endgenerate
    
    reg conv_valid_r,conv_valid_g,conv_valid_b;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_r       <= 0;
            conv_valid_r <= 0;
            
            conv_g       <= 0;
            conv_valid_g <= 0;
            
            
            conv_b       <= 0;
            conv_valid_b <= 0;
            
            warmup_count   <= 0;
            output_count   <= 0;
            stall_count    <= 0;
        end else begin
            start_fifo <= 0;
            if(start_conv) begin
            // First wait for warmup cycles
//                if (warmup_count < WARMUP_CYCLES) begin
//                    warmup_count   <= warmup_count + 1;
//                    conv_valid_r <= 0;
//                    conv_valid_g <= 0;
//                    conv_valid_b <= 0;
//                end
//                // Then produce outputs
//                else 
                    if (stall_count != 0) begin
                    // we are in stall mode
                    stall_count    <= stall_count - 1;
                    conv_valid_r <= 0;
                    conv_valid_g <= 0;
                    conv_valid_b <= 0;
                end else begin
                    // Normal output
                    conv_r <= psum_wires_r[0][2] + psum_wires_r[1][2] + psum_wires_r[2][2] +
                                psum_wires_r[0][1] + psum_wires_r[1][1] + psum_wires_r[2][1] +
                                psum_wires_r[0][0] + psum_wires_r[1][0] + psum_wires_r[2][0];
                    conv_valid_r <= 1;
    
    
                    
                    conv_g <= psum_wires_g[0][2] + psum_wires_g[1][2] + psum_wires_g[2][2] +
                                psum_wires_g[0][1] + psum_wires_g[1][1] + psum_wires_g[2][1] +
                                psum_wires_g[0][0] + psum_wires_g[1][0] + psum_wires_g[2][0];
                    conv_valid_g <= 1;
                    
                    
                    
                    conv_b <= psum_wires_b[0][2] + psum_wires_b[1][2] + psum_wires_b[2][2] +
                                psum_wires_b[0][1] + psum_wires_b[1][1] + psum_wires_b[2][1] +
                                psum_wires_b[0][0] + psum_wires_b[1][0] + psum_wires_b[2][0];
                    conv_valid_b <= 1;
                    
            
                    if(conv_valid_r && conv_valid_g && conv_valid_b) begin
                        start_fifo <= 1;

                        conv_outs_rgb[1*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
              //  conv_outs_rgb[2*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
                //conv_outs_rgb[3*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
                
                        end 
                    
                    if (output_count == OUTPUT_CYCLES) begin
                        output_count <= 0;
                        stall_count  <= STALL_CYCLES;
                    end else begin
                        output_count <= output_count + 1;
                    end
                end
            end
        end
    end
    
    
    
    
    
    
    
     

//    // Instantiate systolic array for Red channel
//    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) red_array (
//        .clk(clk),
//        .rst(rst),
//        .load_weight(load_weight),
//        .input_col(input_win_r),
//        .filter_weights(weights_r),
//        .valid(start_conv),
//        .conv_out(conv_r),
//        .conv_valid(conv_valid_r)
//    );

//    // Instantiate systolic array for Green channel
//    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) green_array (
//        .clk(clk),
//        .rst(rst),
//        .load_weight(load_weight),
//        .input_col(input_win_g),
//        .filter_weights(weights_g),
//        .valid(start_conv),
//        .conv_out(conv_g),
//        .conv_valid(conv_valid_g)
//    );

//    // Instantiate systolic array for Blue channel
//    systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) blue_array (
//        .clk(clk),
//        .rst(rst),
//        .load_weight(load_weight),
//        .input_col(input_win_b),
//        .filter_weights(weights_b),
//        .valid(start_conv),
//        .conv_out(conv_b),
//        .conv_valid(conv_valid_b)
//    );
    
//    always@ (posedge clk) begin 
//        start_fifo <= conv_valid_r && conv_valid_g && conv_valid_b;
        
//        if(conv_valid_r && conv_valid_g && conv_valid_b) begin
        
//            conv_outs_rgb[1*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
//          //  conv_outs_rgb[2*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
//            //conv_outs_rgb[3*(2*DATA_WIDTH+6)-1 -: 2*DATA_WIDTH+6] <= conv_r + conv_g + conv_b;
            
//        end 
    
//    end

endmodule