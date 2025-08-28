`timescale 1ns/1ps

module bram #(
    parameter DATA_WIDTH = 22,
    parameter DEPTH      = 147708
)(
    input  wire                   clk,
    input  wire                   we,
    input  wire [17:0]            wr_addr,
    input  wire [DATA_WIDTH-1:0]  din,

    input  wire [17:0]            rd_addr0,
    output reg  [DATA_WIDTH-1:0]  dout0,

    input  wire [17:0]            rd_addr1,
    output reg  [DATA_WIDTH-1:0]  dout1,

    input  wire [17:0]            rd_addr2,
    output reg  [DATA_WIDTH-1:0]  dout2
);

    // memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we)
            mem[wr_addr] <= din;
        dout0 <= mem[rd_addr0];
        dout1 <= mem[rd_addr1];
        dout2 <= mem[rd_addr2];
    end

endmodule
