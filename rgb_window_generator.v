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
    
    output reg [9*DATA_WIDTH-1:0] output_win_r,
    output reg [9*DATA_WIDTH-1:0] output_win_g,
    output reg [9*DATA_WIDTH-1:0] output_win_b,
    
    output reg start_conv,
    output reg done
    
    );
    
    localparam IDLE        = 2'b00;
    localparam STREAM      = 2'b01;
    localparam PAUSE       = 2'b10;
    localparam DONE        = 2'b11;
 
    reg [1:0] state, next_state;

    
     //declaring line buffers and shift registers for three channels
    (* ram_style = "distributed", shreg_extract = "yes" *) reg [DATA_WIDTH-1:0] shift_reg_r_0 [IMAGE_SIZE-1:0];
    (* ram_style = "distributed", shreg_extract = "yes" *) reg [DATA_WIDTH-1:0] shift_reg_g_0 [IMAGE_SIZE-1:0];
    (* ram_style = "distributed", shreg_extract = "yes" *) reg [DATA_WIDTH-1:0] shift_reg_b_0 [IMAGE_SIZE-1:0];
    (* ram_style = "distributed", shreg_extract = "yes" *) reg [DATA_WIDTH-1:0] shift_reg_r_1 [IMAGE_SIZE-1:0];
    (* ram_style = "distributed", shreg_extract = "yes" *) reg [DATA_WIDTH-1:0] shift_reg_g_1 [IMAGE_SIZE-1:0];
    (* ram_style = "distributed", shreg_extract = "yes" *) reg [DATA_WIDTH-1:0] shift_reg_b_1 [IMAGE_SIZE-1:0];
    
    reg [DATA_WIDTH-1:0] data_reg_r [1:0][2:0];
    reg [DATA_WIDTH-1:0] data_reg_g [1:0][2:0];
    reg [DATA_WIDTH-1:0] data_reg_b [1:0][2:0];
    
    //minimum number of pixels that should arrive to start window generation for a kernel size of 3 for a prepadded image
    integer start_window_pixel_count  = (2*IMAGE_SIZE)+1; 
    
    //counters
    integer  pixel_count      = 0;
    integer  count            = 0;
    reg      [8:0] col_cnt;
    reg      [7:0] row_cnt; 
    
    //loop variables
    integer i, j; 
    

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
        
            for (i = 0; i < IMAGE_SIZE; i = i+1) begin
               shift_reg_r_0[i] <= 0;
               shift_reg_g_0[i] <= 0;
               shift_reg_b_0[i] <= 0;
               shift_reg_r_1[i] <= 0;
               shift_reg_g_1[i] <= 0;
               shift_reg_b_1[i] <= 0;
            end
           
            
            for (i = 0; i < 2; i = i+1) begin
                for (j = 0; j < 3; j = j+1) begin
                   data_reg_r[i][j] <= 0;
                   data_reg_g[i][j] <= 0;
                   data_reg_b[i][j] <= 0;
                end
            end
                        
            output_win_r <= 'b0 ;
            output_win_g <= 'b0 ;
            output_win_b <= 'b0 ;
            
            done         <= 0;
            pixel_count  <= 0;
            count        <= 0;
            start_conv   <= 0;
            col_cnt      <= 0;
            row_cnt      <= 0;
            state        <= IDLE;
            
        
        end
        
        else begin
        
            case(state)
            
            IDLE: begin

                done        <= 0;
                start_conv  <= 0;
                col_cnt     <= 0;
                row_cnt     <= 0;
                pixel_count <= 0;
                
                if(pixel_valid_r && pixel_valid_g && pixel_valid_b) begin
                   
                    
                    state <= STREAM;
                    col_cnt <= 0;
                    shift_reg_r_0[0] <= pixel_in_r;
                    shift_reg_g_0[0] <= pixel_in_g;
                    shift_reg_b_0[0] <= pixel_in_b; 
                
                end
            
            end
            
            STREAM: begin
            
                start_conv <= 0;
            
                if (col_cnt == IMAGE_SIZE-1 && row_cnt== IMAGE_SIZE-1) begin
                
                    state <= DONE; 
                    
                end else if (col_cnt < 2 || col_cnt == IMAGE_SIZE-1) begin
                
                    state <= PAUSE;
                
                end
            
                
                         
                //r channel
                
                    //Incoming pixel
                    shift_reg_r_0[0] <= pixel_in_r;
                    
                    shift_reg_r_1[0] <= shift_reg_r_0[IMAGE_SIZE-1];
                    
                    for(i=1; i < IMAGE_SIZE; i=i+1) begin
                        
                        shift_reg_r_0[i] <= shift_reg_r_0[i-1];
                        shift_reg_r_1[i] <= shift_reg_r_1[i-1];
                        
                    end          
                    
                    data_reg_r[1][2] <= pixel_in_r; 
                    
                    data_reg_r[1][0] <= shift_reg_r_1[IMAGE_SIZE-1];
                    data_reg_r[1][1] <= shift_reg_r_0[IMAGE_SIZE-1];
                    
                    for(i=0; i<3; i=i+1) begin
                        data_reg_r[0][i]<=data_reg_r[1][i];
                    end
                    
                            
                    
                //g channel
                
                    //Incoming pixel
                    shift_reg_g_0[0] <= pixel_in_g;
                    
                    shift_reg_g_1[0] <= shift_reg_g_0[IMAGE_SIZE-1];
                    
                    for(i=1; i < IMAGE_SIZE; i=i+1) begin
                        
                        shift_reg_g_0[i] <= shift_reg_g_0[i-1];
                        shift_reg_g_1[i] <= shift_reg_g_1[i-1];
                        
                    end 
                    
                    data_reg_g[1][2] <= pixel_in_g; 
                    data_reg_g[1][0] <= shift_reg_g_1[IMAGE_SIZE-1];
                    data_reg_g[1][1] <= shift_reg_g_0[IMAGE_SIZE-1];      
                    
                    for(i=0; i<3; i=i+1) begin
                        data_reg_g[0][i]<=data_reg_g[1][i];
                    end
                    
                //b channel
                
                    //Incoming pixel
                    shift_reg_b_0[0] <= pixel_in_b;
                    
                    shift_reg_b_1[0] <= shift_reg_b_0[IMAGE_SIZE-1];
                    
                    for(i=1; i < IMAGE_SIZE; i=i+1) begin
                        
                        shift_reg_b_0[i] <= shift_reg_b_0[i-1];
                        shift_reg_b_1[i] <= shift_reg_b_1[i-1];
                        
                    end 
                    
                    data_reg_b[1][2] <= pixel_in_b; 
                    data_reg_b[1][0] <= shift_reg_b_1[IMAGE_SIZE-1];
                    data_reg_b[1][1] <= shift_reg_b_0[IMAGE_SIZE-1];      
                    
                    for(i=0; i<3; i=i+1) begin
                        data_reg_b[0][i]<=data_reg_b[1][i];
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
                
                if(pixel_count >= start_window_pixel_count && (col_cnt>=1 && col_cnt<=IMAGE_SIZE-2)) begin
                
                    if (col_cnt>=1) begin 
                
                        start_conv <= 1;
                    
                    end else if (col_cnt == IMAGE_SIZE-1 || col_cnt < 1) begin
                    
                        start_conv <= 0;
                    
                    end
                
                    output_win_r[8*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_r;
                    output_win_g[8*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_g;
                    output_win_b[8*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_b;
                    
                    output_win_r[7*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r_0[IMAGE_SIZE-1];
                    output_win_g[7*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g_0[IMAGE_SIZE-1];
                    output_win_b[7*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b_0[IMAGE_SIZE-1];
                    
                    
                    output_win_r[6*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r_1[IMAGE_SIZE-1];
                    output_win_g[6*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g_1[IMAGE_SIZE-1];
                    output_win_b[6*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b_1[IMAGE_SIZE-1];
                    
                    count = 5;
                  
                   
                    for(i=0; i<2; i=i+1) begin
                        for(j=0; j<3; j=j+1) begin
                            output_win_r[count*DATA_WIDTH +: DATA_WIDTH] <= data_reg_r[1-i][2-j];
                            output_win_g[count*DATA_WIDTH +: DATA_WIDTH] <= data_reg_g[1-i][2-j];
                            output_win_b[count*DATA_WIDTH +: DATA_WIDTH] <= data_reg_b[1-i][2-j];
                            
                            count = count - 1;
                        end                    
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
                
                if (col_cnt>=1 && pixel_count >= start_window_pixel_count) begin 
                
                    start_conv <= 1;
                
                end else if ((col_cnt == IMAGE_SIZE-1 || col_cnt < 1) || pixel_count < start_window_pixel_count) begin
                
                    start_conv <= 0;
                
                end
                
                //r channel
                
                    //Incoming pixel
                    shift_reg_r_0[0] <= pixel_in_r;
                    
                    shift_reg_r_1[0] <= shift_reg_r_0[IMAGE_SIZE-1];
                    
                    for(i=1; i < IMAGE_SIZE; i=i+1) begin
                        
                        shift_reg_r_0[i] <= shift_reg_r_0[i-1];
                        shift_reg_r_1[i] <= shift_reg_r_1[i-1];
                        
                    end                 
                    
                    data_reg_r[1][2] <= pixel_in_r; 
                    data_reg_r[1][0] <= shift_reg_r_1[IMAGE_SIZE-1];
                    data_reg_r[1][1] <= shift_reg_r_0[IMAGE_SIZE-1];    
                    
                    for(i=0; i<3; i=i+1) begin
                        data_reg_r[0][i]<=data_reg_r[1][i];
                    end
                    
                            
                    
                //g channel
                
                    //Incoming pixel
                    shift_reg_g_0[0] <= pixel_in_g;
                    
                    shift_reg_g_1[0] <= shift_reg_g_0[IMAGE_SIZE-1];
                    
                    for(i=1; i < IMAGE_SIZE; i=i+1) begin
                        
                        shift_reg_g_0[i] <= shift_reg_g_0[i-1];
                        shift_reg_g_1[i] <= shift_reg_g_1[i-1];
                        
                    end 
                    
                    data_reg_g[1][2] <= pixel_in_g; 
                    data_reg_g[1][0] <= shift_reg_g_1[IMAGE_SIZE-1];
                    data_reg_g[1][1] <= shift_reg_g_0[IMAGE_SIZE-1];     
                    
                    for(i=0; i<3; i=i+1) begin
                        data_reg_g[0][i]<=data_reg_g[1][i];
                    end
                    
                //b channel
                
                    //Incoming pixel
                     shift_reg_b_0[0] <= pixel_in_b;
                    
                    shift_reg_b_1[0] <= shift_reg_b_0[IMAGE_SIZE-1];
                    
                    for(i=1; i < IMAGE_SIZE; i=i+1) begin
                        
                        shift_reg_b_0[i] <= shift_reg_b_0[i-1];
                        shift_reg_b_1[i] <= shift_reg_b_1[i-1];
                        
                    end 
                    
                    data_reg_b[1][2] <= pixel_in_b; 
                    data_reg_b[1][0] <= shift_reg_b_1[IMAGE_SIZE-1];
                    data_reg_b[1][1] <= shift_reg_b_0[IMAGE_SIZE-1];      
                    
                    for(i=0; i<3; i=i+1) begin
                        data_reg_b[0][i]<=data_reg_b[1][i];
                    end
                    
                pixel_count <= pixel_count+1;    
                
                if (col_cnt >= 1) begin 
                
                    state <= STREAM;               
                
                end else if (col_cnt == IMAGE_SIZE-1 && row_cnt == IMAGE_SIZE-1) begin
    
                    state <= DONE;                
                
                end
                
                if(pixel_count == start_window_pixel_count || (col_cnt == 1 && pixel_count >= start_window_pixel_count)) begin
                
                    output_win_r[8*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_r;
                    output_win_g[8*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_g;
                    output_win_b[8*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_b;
                    
                    output_win_r[7*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r_0[IMAGE_SIZE-1];
                    output_win_g[7*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g_0[IMAGE_SIZE-1];
                    output_win_b[7*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b_0[IMAGE_SIZE-1];
                    
                    
                    output_win_r[6*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r_1[IMAGE_SIZE-1];
                    output_win_g[6*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g_1[IMAGE_SIZE-1];
                    output_win_b[6*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b_1[IMAGE_SIZE-1];
                    
                    count = 5;
                  
                   
                    for(i=0; i<2; i=i+1) begin
                        for(j=0; j<3; j=j+1) begin
                            output_win_r[count*DATA_WIDTH +: DATA_WIDTH] <= data_reg_r[1-i][2-j];
                            output_win_g[count*DATA_WIDTH +: DATA_WIDTH] <= data_reg_g[1-i][2-j];
                            output_win_b[count*DATA_WIDTH +: DATA_WIDTH] <= data_reg_b[1-i][2-j];
                            
                            count = count - 1;
                        end                    
                    end
                
                
                end
            
            end
                
            DONE: begin
            
                start_conv <= 0;
                done       <= 1;
            
            end
            
            endcase 
                    
        end
         
    end 
        
endmodule
