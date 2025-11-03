`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// PE: Processing Element
// - accumulates psum_in + data_in * weight
// - forwards data_in to the right (data_out)
// -----------------------------------------------------------------------------

module PE #(
    parameter DATA_WIDTH = 8,
    // PSUM_WIDTH must be wide enough to hold (DATA_WIDTH*2) product plus accumulation margin
    parameter PSUM_WIDTH  = 2*DATA_WIDTH + 4
)(
   (* keep = "true" *) input  wire                        clk,
   (* keep = "true" *)input  wire                        rst,
   (* keep = "true" *) input  wire [DATA_WIDTH-1:0]       data_in,     // activation
   (* keep = "true" *) input  wire [PSUM_WIDTH-1:0]       psum_in,     // partial sum in
   (* keep = "true" *) input  wire [DATA_WIDTH-1:0]       weight_in,   // weight to be loaded
   (* keep = "true" *) input  wire                        load_weight,

  (* keep = "true" *)  output reg  [DATA_WIDTH-1:0]       data_out,    // forwarded activation
   (* keep = "true" *) output reg  [PSUM_WIDTH-1:0]       psum_out     // accumulated partial sum out
);

    reg [DATA_WIDTH-1:0] weight;

    // product has width 2*DATA_WIDTH, extend to PSUM_WIDTH for accumulation
    wire [PSUM_WIDTH-1:0] product_ext;
    wire [2*DATA_WIDTH-1:0] product_raw;

    assign product_raw = data_in * weight;
    assign product_ext = {{(PSUM_WIDTH-2*DATA_WIDTH){1'b0}}, product_raw};

    always @(posedge clk or posedge rst) begin
        if (rst)
            weight <= 0;
        else if (load_weight)
            weight <= weight_in;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            psum_out <= {PSUM_WIDTH{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            // accumulate incoming psum with local product
            psum_out <= psum_in + product_ext;
            data_out <= data_in;
        end
    end

endmodule