`timescale 1ns / 1ps

module FIFO #(
    
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 448,
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH)
    
    )(
    
    (* keep = "true" *) input clk,
    (* keep = "true" *) input rst,

    (* keep = "true" *) input [DATA_WIDTH-1:0] data_in,
    (* keep = "true" *) input                  valid_in,

    (* keep = "true" *) output reg [DATA_WIDTH-1:0] data_out,
    (* keep = "true" *) output reg                  valid_out

    );
        
    (* keep = "true" *) reg [DATA_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];
    (* keep = "true" *) reg [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    (* keep = "true" *) reg read_en;
    (* keep = "true" *) reg [$clog2((FIFO_DEPTH*FIFO_DEPTH)/16+1) -1 : 0] count;
    
    
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