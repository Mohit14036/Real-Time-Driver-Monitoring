`timescale 1ns / 1ps

module rgb_window_generator #(
    
    parameter DATA_WIDTH = 8,
    parameter IMAGE_SIZE = 224,
    parameter KERNEL_SIZE = 7,
    parameter INPUT_CHANNELS = 3
    
    )(
    
    (* keep = "true" *) input clk, 
    (* keep = "true" *) input rst,
    
    (* keep = "true" *) input [INPUT_CHANNELS*DATA_WIDTH-1:0] pixel_in_flat,
    (* keep = "true" *) input [INPUT_CHANNELS-1:0]            pixel_valid_flat,
    
    (* keep = "true" *)output reg [INPUT_CHANNELS*KERNEL_SIZE*DATA_WIDTH-1:0] output_win_flat,
    
    (* keep = "true" *) output reg start_conv,
    (* keep = "true" *) output reg done,
    (* keep = "true" *) output reg col
    
    );
    
    localparam IDLE        = 2'b00;
    localparam STREAM      = 2'b01;
    localparam PAUSE       = 2'b10;
    localparam DONE        = 2'b11;
 
    (* keep = "true" *) reg [1:0] state, next_state;

    
     //declaring line buffers and shift registers for three channels
    (* keep = "true" *) reg [DATA_WIDTH-1:0] shift_reg [0:INPUT_CHANNELS-1][KERNEL_SIZE-2:0][IMAGE_SIZE-1:0];
    
    
    //minimum number of pixels that should arrive to start window generation for a kernel size of 3 for a prepadded image
    (* keep = "true" *) integer start_window_pixel_count  = ((KERNEL_SIZE-1)*IMAGE_SIZE)+1; 
    
    //counters
    (* KEEP = "TRUE" *) reg [$clog2(IMAGE_SIZE*IMAGE_SIZE):0]   pixel_count;
    (* keep = "true" *) integer  count            = 0;
    (* keep = "true" *) reg      [8:0] col_cnt;
    (* keep = "true" *) reg      [7:0] row_cnt; 
    
    //loop variables
    (* keep = "true" *) integer i, j, ch; 
    
    (* keep = "true" *) reg done_delayed,done_delayed1;
    
/*    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (pixel_valid_r && pixel_valid_g && pixel_valid_b)
                    next_state = STREAM;
            end

            STREAM: begin
                if (col_cnt == IMAGE_SIZE && row_cnt == IMAGE_SIZE) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end */

    
    always @(posedge clk) begin
    
        if (rst) begin
        
            for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                    for(j=0; j<IMAGE_SIZE; j=j+1) begin
                        shift_reg[ch][i][j] <= 0;
                    end
                   
                end
            end
                        
            output_win_flat <= 0;
            
            done         <= 0;
            pixel_count  <= 0;
            count        <= 0;
            start_conv   <= 0;
            col_cnt      <= 0;
            row_cnt      <= 0;
            col          <= 0;
            state        <= IDLE;
            done_delayed <= 0;
            done_delayed1 <= 0;
            
        
        end
        
        else begin
        
            case(state)
            
            IDLE: begin

                done        <= 0;
                start_conv  <= 0;
                col_cnt     <= 0;
                row_cnt     <= 0;
                pixel_count <= 0;
                col         <= 0;
                
                if(&pixel_valid_flat) begin
                   
                    
                    state <= STREAM;
                    col_cnt <= 0;
                    for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                            shift_reg[ch][0][0] <= pixel_in_flat[ch*DATA_WIDTH +: DATA_WIDTH];
                    end
                
                end
            
            end
            
            STREAM: begin
            
                start_conv <= 0;
            
                if (col_cnt == IMAGE_SIZE-1 && row_cnt == IMAGE_SIZE-1) begin
                
                    state <= DONE; 
                    
                end else if (col_cnt < KERNEL_SIZE-1 || col_cnt == IMAGE_SIZE-1) begin
                
                    state <= PAUSE;
                
                end
            
                for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin                  
                    //Incoming pixel
                    shift_reg[ch][0][0] <= pixel_in_flat[ch*DATA_WIDTH +: DATA_WIDTH];
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg[ch][i][0] <= shift_reg[ch][i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg[ch][i][j] <= shift_reg[ch][i][j-1];
                        end
                    end          
                    
                    
                    
                end
                            
                    
                
                    
                pixel_count <= pixel_count+1;  
                
                if (col_cnt == IMAGE_SIZE-1) begin
                    col_cnt <= 0;
                    if (row_cnt < IMAGE_SIZE-1) begin
                        row_cnt <= row_cnt + 1;
                    end 
                end else begin
                    col_cnt <= col_cnt + 1;
                end
                
                if(pixel_count >= start_window_pixel_count-2 && (col_cnt>=KERNEL_SIZE-2 && col_cnt<=IMAGE_SIZE-1)) begin
                    
                    col <= 1;
                    
                    if (pixel_count >= start_window_pixel_count+2) begin 
                
                        start_conv <= 1;
                    
                    end
                    for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                        output_win_flat[((ch+1)*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_flat[ch*DATA_WIDTH +: DATA_WIDTH];
                        
                        //count = KERNEL_SIZE*KERNEL_SIZE-2;
                        for(i=0; i<(KERNEL_SIZE-1); i=i+1) begin
                        
                            output_win_flat[((ch+1)*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg[ch][i][IMAGE_SIZE-1]; 
                            //count = count - 1;
                            
                        end
                         //count = KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1;
                        
                    end
                end
                 
            end
            
            PAUSE: begin 

                if (col_cnt == IMAGE_SIZE-1) begin
                    col_cnt <= 0;
                    if (row_cnt < IMAGE_SIZE-1) begin
                        row_cnt <= row_cnt + 1;
                    end
                end else begin
                    col_cnt <= col_cnt + 1;
                end
                
                if (pixel_count >= start_window_pixel_count+2) begin 
                
                    start_conv <= 1;
                
                end
                
                for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin                  
                        //Incoming pixel
                        shift_reg[ch][0][0] <= pixel_in_flat[ch*DATA_WIDTH +: DATA_WIDTH];
                            
                        for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                            shift_reg[ch][i][0] <= shift_reg[ch][i-1][IMAGE_SIZE-1];
                        end
                        
                        
                        for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                            for(j=1; j < IMAGE_SIZE; j=j+1) begin
                                shift_reg[ch][i][j] <= shift_reg[ch][i][j-1];
                            end
                        end          
                        
                           
                        
                       
                    end
                    
                pixel_count <= pixel_count+1;    
                
                if (col_cnt >= KERNEL_SIZE-2) begin 
                
                    state <= STREAM;               
                
                end else if (col_cnt == IMAGE_SIZE-1 && row_cnt == IMAGE_SIZE-1) begin
    
                    state <= DONE;                
                
                end
                
                if(pixel_count >= start_window_pixel_count-2) begin
                    
                    col <= 1;
                    
                    for(ch=0; ch<INPUT_CHANNELS; ch=ch+1) begin
                        output_win_flat[((ch+1)*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_flat[ch*DATA_WIDTH +: DATA_WIDTH];
                        
                        //count = KERNEL_SIZE*KERNEL_SIZE-2;
                        for(i=0; i<(KERNEL_SIZE-1); i=i+1) begin
                        
                            output_win_flat[((ch+1)*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg[ch][i][IMAGE_SIZE-1]; 
                            //count = count - 1;
                            
                        end
                         //count = KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1;
                        
                    end
                
                
                end
            
            end
                
            DONE: begin
            
                done         <= 1;
                done_delayed <= done;
                done_delayed1<=done_delayed;
                if (done_delayed1) begin 
                    col        <= 0;
                end
            
            end
            
            endcase 
                    
        end
         
    end 
        
endmodule
