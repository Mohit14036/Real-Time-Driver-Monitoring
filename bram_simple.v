`timescale 1ns / 1ps
module bram_simple #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16
)(
    input  wire                      clk,
    input  wire                      we,     // write enable (synchronous)
    input  wire [ADDR_WIDTH-1:0]     addr,
    input  wire [DATA_WIDTH-1:0]     din,
    output reg  [DATA_WIDTH-1:0]     dout
);
    // simple behavioral memory - synchronous write and read
    localparam DEPTH = (1 << ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr]; // synchronous read (dout gets value of addr on same clock)
    end
endmodule
