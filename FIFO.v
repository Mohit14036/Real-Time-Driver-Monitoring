`timescale 1ns / 1ps

module FIFO #(
    
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 448,
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH)
    
    )(
    
    input clk,
    input rst,

    input [DATA_WIDTH-1:0] data_in,
    input                  valid_in,

    output reg [DATA_WIDTH-1:0] data_out,
    output reg                  valid_out

    );
        
    reg [DATA_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    reg read_en;
    reg [$clog2((FIFO_DEPTH*FIFO_DEPTH)/16+1) -1 : 0] count;
    
    
    always @(posedge clk) begin
    
        if (rst) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            valid_out <= 1'b0;
            data_out  <= 0;
            read_en   <= 0;
            count     <= 0;
            
        end
        
        else begin
        
            
        
            if (valid_in) begin
                
                fifo[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr == FIFO_DEPTH-1) ? 0 : wr_ptr + 1;
                
            end

            if (read_en) begin
            
                data_out  <= fifo[rd_ptr];
                rd_ptr    <= (rd_ptr == FIFO_DEPTH-1) ? 0 : rd_ptr + 1;
                valid_out <= 1;
                count     <= count+1;
                if (count > ((FIFO_DEPTH*FIFO_DEPTH)/16) -2) begin
                    
                    //wr_ptr  <= 0;
                    read_en <= 0;
                    
                end
                
            end else begin
            
                valid_out <= 0;
            
            end
            
            if (!read_en && wr_ptr > FIFO_DEPTH/2 ) begin
                read_en   <= 1; 
                rd_ptr    <= 0;
                valid_out <= 0;
            end   
            
                
        end
    
    end
    
endmodule
