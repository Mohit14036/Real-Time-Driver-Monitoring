`timescale 1ns / 1ps

module rgb_window_generator #(
    
    parameter DATA_WIDTH = 8,
    parameter IMAGE_SIZE = 224
    
    )(
    
    input clk, 
    input rst,
    
    input [DATA_WIDTH-1:0] pixel_in_r,
    input [DATA_WIDTH-1:0] pixel_in_g,
    input [DATA_WIDTH-1:0] pixel_in_b,
    
    input pixel_valid_r,
    input pixel_valid_g,
    input pixel_valid_b,
    
    output reg [3*DATA_WIDTH-1:0] output_col_r,
    output reg [3*DATA_WIDTH-1:0] output_col_g,
    output reg [3*DATA_WIDTH-1:0] output_col_b,
    
    output reg start_conv,
    output reg done,
    output reg col,
    output reg take_col
    );
    
     //declaring line buffers and shift registers for three channels
    reg [DATA_WIDTH-1:0] shift_reg_r [1:0][IMAGE_SIZE-1:0];
    reg [DATA_WIDTH-1:0] shift_reg_g [1:0][IMAGE_SIZE-1:0];
    reg [DATA_WIDTH-1:0] shift_reg_b [1:0][IMAGE_SIZE-1:0];
    
    //minimum number of pixels that should arrive to start window generation for a kernel size of 3 for a prepadded image
    integer start_window_pixel_count  = (2*IMAGE_SIZE); 
    
    //counters
    integer  pixel_count = 0;
    integer        count = 0;
    
    //loop variables
    integer i, j; 
    
    always @(posedge clk) begin
    
        if (rst) begin
        
            for (i = 0; i < 2; i = i+1) begin
                for (j = 0; j < IMAGE_SIZE; j = j+1) begin
                   shift_reg_r[i][j] <= 0;
                end
            end
            for (i = 0; i < 2; i = i+1) begin
                for (j = 0; j < IMAGE_SIZE; j = j+1) begin
                   shift_reg_g[i][j] <= 0;
                end
            end
            for (i = 0; i < 2; i = i+1) begin
                for (j = 0; j < IMAGE_SIZE; j = j+1) begin
                   shift_reg_b[i][j] <= 0;
                end
            end
            
            output_col_r <= 'b0 ;
            output_col_g <= 'b0 ;
            output_col_b <= 'b0 ;
            
            done         <= 0;
            
            pixel_count  <= 0;
            count        <= 0;
            col<=0;
            start_conv <= 0;
            take_col<=0;
        
        end
        
        else if(pixel_valid_r && pixel_valid_g && pixel_valid_b) begin
            
            //r channel
            
                //Incoming pixel
                shift_reg_r[0][0] <= pixel_in_r;
                
                shift_reg_r[1][0] <= shift_reg_r[0][IMAGE_SIZE-1];
                
                for(i=0; i < 2; i=i+1) begin
                    for(j=1; j < IMAGE_SIZE; j=j+1) begin
                        shift_reg_r[i][j] <= shift_reg_r[i][j-1];
                    end
                end                
                
                        
                
            //g channel
            
                //Incoming pixel
                shift_reg_g[0][0] <= pixel_in_g;
                
                for(i=0; i < 2; i=i+1) begin
                    for(j=1; j < IMAGE_SIZE; j=j+1) begin
                        shift_reg_g[i][j] <= shift_reg_g[i][j-1];
                    end
                end
                
                //cascaded shift registers
                shift_reg_g[1][0] <= shift_reg_g[0][IMAGE_SIZE-1];
                
            //b channel
            
                //Incoming pixel
                shift_reg_b[0][0] <= pixel_in_b;
                
                for(i=0; i < 2; i=i+1) begin
                    for(j=1; j < IMAGE_SIZE; j=j+1) begin
                        shift_reg_b[i][j] <= shift_reg_b[i][j-1];
                    end
                end
                
                //cascaded shift registers
                shift_reg_b[1][0] <= shift_reg_b[0][IMAGE_SIZE-1];
                
            pixel_count <= pixel_count+1;
            
            if(pixel_count >= start_window_pixel_count) begin
                col<=1;
                output_col_r[2*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_r;
                output_col_g[2*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_g;
                output_col_b[2*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_b;
                
                count = 1;
                for(i=0; i<2; i=i+1) begin
                
                    output_col_r[count*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r[i][IMAGE_SIZE-1];
                    output_col_g[count*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g[i][IMAGE_SIZE-1];
                    output_col_b[count*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b[i][IMAGE_SIZE-1];
                    
                    count = count - 1;
                    
                end
                /*if(pixel_count >= start_window_pixel_count+1) begin
                start_conv<=1;
                end*/
                if(pixel_count >= start_window_pixel_count+4) begin
                
                    start_conv <= 1;
                    done<=1;
                end
                if(pixel_count >= start_window_pixel_count+7) begin
                    take_col<=1;
                    end
        
            end
            
            if(pixel_count == IMAGE_SIZE*IMAGE_SIZE) begin
            
                done <= 1;           
                 
            end
            
                    
        end
        
        
    end 
        
endmodule