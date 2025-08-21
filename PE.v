`timescale 1ns / 1ps

module PE #(
    parameter DATA_WIDTH = 8
)(
    input  wire                      clk,
    input  wire                      rst,
    input  wire [DATA_WIDTH-1:0] data_in,     // Activation input
    input  wire [DATA_WIDTH-1:0] psum_in,     // Partial sum input
    input  wire [DATA_WIDTH-1:0] weight_in,   // Weight to be loaded
    input  wire                      load_weight,    // Control signal to load weight

    output reg [DATA_WIDTH-1:0] data_out,     // Forwarded activation
    output reg [2*DATA_WIDTH-1:0] psum_out    // Output partial sum
);

    // Internal register
    reg [DATA_WIDTH-1:0] weight;

    always @(posedge clk or posedge rst) begin
        if (rst)
            weight <= 0;
        else if (load_weight)
            weight <= weight_in;
            
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            psum_out <= 0;
            data_out <= 0;
        end else begin
            psum_out <= data_in * weight ;
            data_out <= data_in;
            

            // Debugging statement
        end
        //$display("Time: %0t | PE: data_in=%0d, weight=%0d, psum_out=%0d", $time, data_in, weight, psum_out);

    end

endmodule