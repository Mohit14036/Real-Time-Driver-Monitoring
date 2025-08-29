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
    
    input  wire [17:0] rd_addr2_0, output wire [(2*RESULT_WIDTH+6)-1:0] rd_data2_0,
    input  wire [17:0] rd_addr2_1, output wire [(2*RESULT_WIDTH+6)-1:0] rd_data2_1,
    input  wire [17:0] rd_addr2_2, output wire [(2*RESULT_WIDTH+6)-1:0] rd_data2_2,

    output wire done0,     // Layer-1 done
    output wire done_all   // Layer-2 done
);
    reg [17:0] addr0_0, addr1_0, addr2_0;
    reg [17:0] addr0_1, addr1_1, addr2_1;
    reg [17:0] addr0_2, addr1_2, addr2_2;
    
    wire [RESULT_WIDTH-1:0] data0_0,data0_1,data0_2;
    wire [RESULT_WIDTH-1:0] data1_0,data1_1,data1_2;
    wire [RESULT_WIDTH-1:0] data2_0,data2_1,data2_2;

    
    // ---------------------------
    // LAYER 1
    // ---------------------------
    rgb_conv_layer_64 #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUTPUT_SIZE(OUTPUT_SIZE),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) layer0 (
        .clk(clk),
        .rst(rst),
        .input_col_r(input_col_r),
        .input_col_g(input_col_g),
        .input_col_b(input_col_b),
        .load_weight(load_weight),
        .input_valid(input_valid),

        .rd_addr0_0(addr0_0), .rd_data0_0(data0_0),
        .rd_addr1_0(addr1_0), .rd_data1_0(data1_0),
        .rd_addr2_0(addr2_0), .rd_data2_0(data2_0),
        
        
        .rd_addr0_1(addr0_1), .rd_data0_1(data0_1),
        .rd_addr1_1(addr1_1), .rd_data1_1(data1_1),
        .rd_addr2_1(addr2_1), .rd_data2_1(data2_1),
        
        
        .rd_addr0_2(addr0_2), .rd_data0_2(data0_2),
        .rd_addr1_2(addr1_2), .rd_data1_2(data1_2),
        .rd_addr2_2(addr2_2), .rd_data2_2(data2_2),
        
        
        

        .done(done0)
    );

   
    reg [17:0] row, col;
    reg        stream1_en, bram_valid_d;
    reg        l2_input_valid;


    reg [RESULT_WIDTH-1:0] f0 [0:2];
    reg [RESULT_WIDTH-1:0] f1 [0:2];
    reg [RESULT_WIDTH-1:0] f2 [0:2];

    // pack into Layer-2 inputs
    wire [3*RESULT_WIDTH-1:0] f0_col = {f0[0], f0[1], f0[2]};
    wire [3*RESULT_WIDTH-1:0] f1_col = {f1[0], f1[1], f1[2]};
    wire [3*RESULT_WIDTH-1:0] f2_col = {f2[0], f2[1], f2[2]};

    
    
    

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            row           <= 0;
            col           <= 0;
            addr0_0         <= 0+1;
            addr0_1         <= OUT_W+1;
            addr0_2         <= 2*OUT_W+1;
            
            addr1_0         <= 0+1;
            addr1_1         <= OUT_W+1;
            addr1_2         <= 2*OUT_W+1;
            
            
            addr2_0         <= 0+1;
            addr2_1         <= OUT_W+1;
            addr2_2         <= 2*OUT_W+1;
            
            stream1_en    <= 0;
            bram_valid_d  <= 0;
            l2_input_valid<= 0;
        end else begin
            if (done0 && !stream1_en) begin
                stream1_en   <= 1;
                row          <= 0;
                col          <= 0;
                
                addr0_0         <= 0+1;
                addr0_1         <= OUT_W+1;
                addr0_2         <= 2*OUT_W+1;
                
                addr1_0         <= 0+1;
                addr1_1         <= OUT_W+1;
                addr1_2         <= 2*OUT_W+1;
                
                
                addr2_0         <= 0+1;
                addr2_1         <= OUT_W+1;
                addr2_2         <= 2*OUT_W+1;
                
                
                
                bram_valid_d <= 0;
            end else if (stream1_en) begin
                
                    // latch BRAM outputs
                    f0[0] <= data0_0; 
                    f0[1] <= data0_1; 
                    f0[2] <= data0_2; 

                    f1[0] <= data1_0; 
                    f1[1] <= data1_1; 
                    f1[2] <= data1_2; 

                    f2[0] <= data2_0; 
                    f2[1] <= data2_1; 
                    f2[2] <= data2_2; 

                    l2_input_valid <= 1;

                    // update column/row
                    if (col < OUT_W-1) begin
                        col   <= col + 1;
                        addr0_0 <= row*OUT_W     + (col+1);
                        addr0_1 <= (row+1)*OUT_W + (col+1);
                        addr0_2 <= (row+2)*OUT_W + (col+1);
                        
                        
                        addr1_0 <= row*OUT_W     + (col+1);
                        addr1_1 <= (row+1)*OUT_W + (col+1);
                        addr1_2 <= (row+2)*OUT_W + (col+1);
                        
                        
                        addr2_0 <= row*OUT_W     + (col+1);
                        addr2_1 <= (row+1)*OUT_W + (col+1);
                        addr2_2 <= (row+2)*OUT_W + (col+1);
                    end else begin
                        col   <= 0;
                        row   <= row + 1;
                        addr0_0 <= (row+1)*OUT_W;
                        addr0_1 <= (row+2)*OUT_W;
                        addr0_2 <= (row+3)*OUT_W;
                        
                        
                        addr1_0 <= (row+1)*OUT_W;
                        addr1_1 <= (row+2)*OUT_W;
                        addr1_2 <= (row+3)*OUT_W;
                        
                        
                        addr2_0 <= (row+1)*OUT_W;
                        addr2_1 <= (row+2)*OUT_W;
                        addr2_2 <= (row+3)*OUT_W;
                    end

                    // stop when rows exhausted
                    if (row >= OUT_H-3) begin
                        stream1_en     <= 0;
                        l2_input_valid <= 0;
                    end
                    bram_valid_d <= 0;
                end
             else begin
                l2_input_valid <= 0;
            end
        end
    end

    // ---------------------------
    // LAYER 2
    // ---------------------------
    rgb_conv_layer_64 #(
        .DATA_WIDTH(RESULT_WIDTH),
        .OUTPUT_SIZE((OUT_W-2)*(OUT_H-2)),   // 220*220
        .RESULT_WIDTH(2*RESULT_WIDTH+6)
    ) layer1 (
        .clk(clk),
        .rst(rst),
        .input_col_r(f0_col),
        .input_col_g(f1_col),
        .input_col_b(f2_col),
        .load_weight(load_weight),
        .input_valid(l2_input_valid),

        .rd_addr0_0(rd_addr0_0), .rd_data0_0(rd_data0_0),
        .rd_addr1_0(rd_addr1_0), .rd_data1_0(rd_data1_0),
        .rd_addr2_0(rd_addr2_0), .rd_data2_0(rd_data2_0),
        
        
        .rd_addr0_1(rd_addr0_1), .rd_data0_1(rd_data0_1),
        .rd_addr1_1(rd_addr1_1), .rd_data1_1(rd_data1_1),
        .rd_addr2_1(rd_addr2_1), .rd_data2_1(rd_data2_1),
        
        
        .rd_addr0_2(rd_addr0_2), .rd_data0_2(rd_data0_2),
        .rd_addr1_2(rd_addr1_2), .rd_data1_2(rd_data1_2),
        .rd_addr2_2(rd_addr2_2), .rd_data2_2(rd_data2_2),

        .done(done_all)
    );

endmodule
