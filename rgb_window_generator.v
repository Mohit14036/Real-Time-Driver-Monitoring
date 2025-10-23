`timescale 1ns / 1ps

module rgb_window_generator #(
    
    parameter DATA_WIDTH = 8,
    parameter IMAGE_SIZE = 224,
    parameter KERNEL_SIZE = 7
    
    )(
    
    (* keep = "true" *) input clk, 
    (* keep = "true" *) input rst,
    
    (* keep = "true" *) input [DATA_WIDTH-1:0] pixel_in_r,
    (* keep = "true" *) input [DATA_WIDTH-1:0] pixel_in_g,
    (* keep = "true" *) input [DATA_WIDTH-1:0] pixel_in_b,
    
    (* keep = "true" *) input pixel_valid_r,
    (* keep = "true" *) input pixel_valid_g,
    (* keep = "true" *) input pixel_valid_b,
    
    (* keep = "true" *) output reg [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] output_win_r,
    (* keep = "true" *) output reg [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] output_win_g,
    (* keep = "true" *) output reg [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] output_win_b,
    
    (* keep = "true" *) output reg start_conv,
    (* keep = "true" *) output reg done
    
    );
    
    localparam IDLE        = 2'b00;
    localparam STREAM      = 2'b01;
    localparam PAUSE       = 2'b10;
    localparam DONE        = 2'b11;
 
    (* keep = "true" *) reg [1:0] state, next_state;

    
     //declaring line buffers and shift registers for three channels
    (* keep = "true" *)reg [DATA_WIDTH-1:0] shift_reg_r [KERNEL_SIZE-2:0][IMAGE_SIZE-1:0];
    (* keep = "true" *)reg [DATA_WIDTH-1:0] shift_reg_g [KERNEL_SIZE-2:0][IMAGE_SIZE-1:0];
    (* keep = "true" *)reg [DATA_WIDTH-1:0] shift_reg_b [KERNEL_SIZE-2:0][IMAGE_SIZE-1:0];
    
    (* keep = "true" *) reg [DATA_WIDTH-1:0] data_reg_r [KERNEL_SIZE-2:0][KERNEL_SIZE-1:0];
    (* keep = "true" *) reg [DATA_WIDTH-1:0] data_reg_g [KERNEL_SIZE-2:0][KERNEL_SIZE-1:0];
    (* keep = "true" *) reg [DATA_WIDTH-1:0] data_reg_b [KERNEL_SIZE-2:0][KERNEL_SIZE-1:0];
    
    //minimum number of pixels that should arrive to start window generation for a kernel size of 3 for a prepadded image
    (* keep = "true" *) integer start_window_pixel_count  = ((KERNEL_SIZE-1)*IMAGE_SIZE)+KERNEL_SIZE-2; 
    
    //counters
    (* KEEP = "TRUE" *) reg [$clog2(IMAGE_SIZE*IMAGE_SIZE):0]   pixel_count;
    (* keep = "true" *) integer  count            = 0;
    (* keep = "true" *) reg      [8:0] col_cnt;
    (* keep = "true" *) reg      [7:0] row_cnt; 
    
    //loop variables
    (* keep = "true" *) integer i, j; 
    

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
        
            for (i = 0; i < KERNEL_SIZE-1; i = i+1) begin
                for (j = 0; j < IMAGE_SIZE; j = j+1) begin
                   shift_reg_r[i][j] <= 0;
                   shift_reg_g[i][j] <= 0;
                   shift_reg_b[i][j] <= 0;
                end
            end
           
            
            for (i = 0; i < KERNEL_SIZE-1; i = i+1) begin
                for (j = 0; j < KERNEL_SIZE; j = j+1) begin
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
                    shift_reg_r[0][0] <= pixel_in_r;
                    shift_reg_g[0][0] <= pixel_in_g;
                    shift_reg_b[0][0] <= pixel_in_b; 
                
                end
            
            end
            
            STREAM: begin
            
                start_conv <= 0;
            
                if (col_cnt == IMAGE_SIZE-1 && row_cnt == IMAGE_SIZE-1) begin
                
                    state <= DONE; 
                    
                end else if (col_cnt < KERNEL_SIZE-1 || col_cnt == IMAGE_SIZE-1) begin
                
                    state <= PAUSE;
                
                end
            
                
                         
                //r channel
                       
                    //Incoming pixel
                    shift_reg_r[0][0] <= pixel_in_r;
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg_r[i][0] <= shift_reg_r[i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg_r[i][j] <= shift_reg_r[i][j-1];
                        end
                    end          
                    
                    data_reg_r[KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in_r; 
                    
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        data_reg_r[KERNEL_SIZE-2][i] <= shift_reg_r[KERNEL_SIZE-2-i][IMAGE_SIZE-1];
                    end      
                    
                    for(i=0; i<KERNEL_SIZE-2; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            data_reg_r[i][j]<=data_reg_r[i+1][j];
                        end
                    end
                    
                            
                    
                //g channel
                
                    //Incoming pixel
                    shift_reg_g[0][0] <= pixel_in_g;
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg_g[i][0] <= shift_reg_g[i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg_g[i][j] <= shift_reg_g[i][j-1];
                        end
                    end          
                    
                    data_reg_g[KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in_g; 
                    
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        data_reg_g[KERNEL_SIZE-2][i] <= shift_reg_g[KERNEL_SIZE-2-i][IMAGE_SIZE-1];
                    end      
                    
                    for(i=0; i<KERNEL_SIZE-2; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            data_reg_g[i][j]<=data_reg_g[i+1][j];
                        end
                    end
                    
                //b channel
                
                    //Incoming pixel
                    shift_reg_b[0][0] <= pixel_in_b;
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg_b[i][0] <= shift_reg_b[i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg_b[i][j] <= shift_reg_b[i][j-1];
                        end
                    end          
                    
                    data_reg_b[KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in_b; 
                    
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        data_reg_b[KERNEL_SIZE-2][i] <= shift_reg_b[KERNEL_SIZE-2-i][IMAGE_SIZE-1];
                    end      
                    
                    for(i=0; i<KERNEL_SIZE-2; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            data_reg_b[i][j]<=data_reg_b[i+1][j];
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
                
                if(pixel_count >= start_window_pixel_count && (col_cnt>=KERNEL_SIZE-2 && col_cnt<=IMAGE_SIZE-2)) begin
                
                    if (col_cnt>=KERNEL_SIZE-2) begin 
                
                        start_conv <= 1;
                    
                    end else if (col_cnt == IMAGE_SIZE-1 || col_cnt < 1) begin
                    
                        start_conv <= 0;
                    
                    end
                
                    output_win_r[(KERNEL_SIZE*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_r;
                    output_win_g[(KERNEL_SIZE*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_g;
                    output_win_b[(KERNEL_SIZE*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_b;
                    
                    //count = KERNEL_SIZE*KERNEL_SIZE-2;
                    for(i=0; i<(KERNEL_SIZE-1); i=i+1) begin
                    
                        output_win_r[(KERNEL_SIZE*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r[i][IMAGE_SIZE-1];
                        output_win_g[(KERNEL_SIZE*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g[i][IMAGE_SIZE-1];
                        output_win_b[(KERNEL_SIZE*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b[i][IMAGE_SIZE-1];
                        
                        //count = count - 1;
                        
                    end
                     //count = KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1;
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            output_win_r[(KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1-(KERNEL_SIZE*i+j))*DATA_WIDTH +: DATA_WIDTH] <= data_reg_r[KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                            output_win_g[(KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1-(KERNEL_SIZE*i+j))*DATA_WIDTH +: DATA_WIDTH] <= data_reg_g[KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                            output_win_b[(KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1-(KERNEL_SIZE*i+j))*DATA_WIDTH +: DATA_WIDTH] <= data_reg_b[KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                            
                            //count = count - 1;
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
                
                if (col_cnt>= KERNEL_SIZE-2 && pixel_count >= start_window_pixel_count) begin 
                
                    start_conv <= 1;
                
                end else if ((col_cnt == IMAGE_SIZE-1 || col_cnt < KERNEL_SIZE-2) || pixel_count < start_window_pixel_count) begin
                
                    start_conv <= 0;
                
                end
                
                //r channel
                       
                    //Incoming pixel
                    shift_reg_r[0][0] <= pixel_in_r;
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg_r[i][0] <= shift_reg_r[i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg_r[i][j] <= shift_reg_r[i][j-1];
                        end
                    end          
                    
                    data_reg_r[KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in_r; 
                    
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        data_reg_r[KERNEL_SIZE-2][i] <= shift_reg_r[KERNEL_SIZE-2-i][IMAGE_SIZE-1];
                    end      
                    
                    for(i=0; i<KERNEL_SIZE-2; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            data_reg_r[i][j]<=data_reg_r[i+1][j];
                        end
                    end
                    
                            
                    
                //g channel
                
                    //Incoming pixel
                    shift_reg_g[0][0] <= pixel_in_g;
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg_g[i][0] <= shift_reg_g[i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg_g[i][j] <= shift_reg_g[i][j-1];
                        end
                    end          
                    
                    data_reg_g[KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in_g; 
                    
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        data_reg_g[KERNEL_SIZE-2][i] <= shift_reg_g[KERNEL_SIZE-2-i][IMAGE_SIZE-1];
                    end      
                    
                    for(i=0; i<KERNEL_SIZE-2; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            data_reg_g[i][j]<=data_reg_g[i+1][j];
                        end
                    end
                    
                //b channel
                
                    //Incoming pixel
                    shift_reg_b[0][0] <= pixel_in_b;
                        
                    for (i=1; i<KERNEL_SIZE-1; i=i+1)  begin
                        shift_reg_b[i][0] <= shift_reg_b[i-1][IMAGE_SIZE-1];
                    end
                    
                    
                    for(i=0; i < KERNEL_SIZE-1; i=i+1) begin
                        for(j=1; j < IMAGE_SIZE; j=j+1) begin
                            shift_reg_b[i][j] <= shift_reg_b[i][j-1];
                        end
                    end          
                    
                    data_reg_b[KERNEL_SIZE-2][KERNEL_SIZE-1] <= pixel_in_b; 
                    
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        data_reg_b[KERNEL_SIZE-2][i] <= shift_reg_b[KERNEL_SIZE-2-i][IMAGE_SIZE-1];
                    end      
                    
                    for(i=0; i<KERNEL_SIZE-2; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            data_reg_b[i][j]<=data_reg_b[i+1][j];
                        end
                    end
                    
                pixel_count <= pixel_count+1;    
                
                if (col_cnt >= KERNEL_SIZE-2) begin 
                
                    state <= STREAM;               
                
                end else if (col_cnt == IMAGE_SIZE-1 && row_cnt == IMAGE_SIZE-1) begin
    
                    state <= DONE;                
                
                end
                
                if(pixel_count == start_window_pixel_count || (col_cnt == KERNEL_SIZE-2 && pixel_count >= start_window_pixel_count)) begin
                
                    output_win_r[(KERNEL_SIZE*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_r;
                    output_win_g[(KERNEL_SIZE*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_g;
                    output_win_b[(KERNEL_SIZE*KERNEL_SIZE-1)*DATA_WIDTH +: DATA_WIDTH] <= pixel_in_b;
                    
                    for(i=0; i<(KERNEL_SIZE-1); i=i+1) begin
                    
                        output_win_r[(KERNEL_SIZE*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_r[i][IMAGE_SIZE-1];
                        output_win_g[(KERNEL_SIZE*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_g[i][IMAGE_SIZE-1];
                        output_win_b[(KERNEL_SIZE*KERNEL_SIZE-2-i)*DATA_WIDTH +: DATA_WIDTH] <= shift_reg_b[i][IMAGE_SIZE-1];
                        
                        //count = count - 1;
                        
                    end
                    //count = KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1;
                    for(i=0; i<KERNEL_SIZE-1; i=i+1) begin
                        for(j=0; j<KERNEL_SIZE; j=j+1) begin
                            output_win_r[(KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1-(KERNEL_SIZE*i+j))*DATA_WIDTH +: DATA_WIDTH] <= data_reg_r[KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                            output_win_g[(KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1-(KERNEL_SIZE*i+j))*DATA_WIDTH +: DATA_WIDTH] <= data_reg_g[KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                            output_win_b[(KERNEL_SIZE*KERNEL_SIZE-KERNEL_SIZE-1-(KERNEL_SIZE*i+j))*DATA_WIDTH +: DATA_WIDTH] <= data_reg_b[KERNEL_SIZE-2-i][KERNEL_SIZE-1-j];
                            
                            //count = count - 1;
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
