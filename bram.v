`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/22/2025 03:28:20 PM
// Design Name: 
// Module Name: bram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module bram #(
    parameter DATA_WIDTH = 22,
    parameter DEPTH = 147708
)(
    input clk,

    // Write port
    input we,
    input [17:0] wr_addr,
    input [DATA_WIDTH-1:0] din,

    // Read port
    input [17:0] rd_addr,
    output reg [DATA_WIDTH-1:0] dout
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we)
            mem[wr_addr] <= din;
        dout <= mem[rd_addr];
    end
endmodule
