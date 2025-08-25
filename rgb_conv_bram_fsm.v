`timescale 1ns / 1ps

module rgb_conv_bram_fsm #(
    parameter DATA_WIDTH  = 8,
    parameter NUM_FILTERS = 3,
    parameter IMG_H = 224,
    parameter IMG_W = 224
)(
    input  wire clk,
    input  wire rst,
    input  wire load_weight,

    // streaming 3-row column input (per clock)
    input  wire [3*DATA_WIDTH-1:0] input_col_r,
    input  wire [3*DATA_WIDTH-1:0] input_col_g,
    input  wire [3*DATA_WIDTH-1:0] input_col_b,

    output reg done,
    // flattened final output (layer2)
    output wire [(NUM_FILTERS*(IMG_H-4)*(IMG_W-4)*(2*DATA_WIDTH+12))-1:0] conv_outs
);
    // local params
    localparam DATA_W_L1 = 2*DATA_WIDTH + 6;   // per-filter first-layer output width (signed)
    localparam DATA_W_L2 = 2*DATA_W_L1 + 6;   // per-filter second-layer output width
    integer zz;
    integer ff;
    // BRAM parameters: store layer1 per-filter values sequentially
    localparam PIXELS_L1 = (IMG_H-2)*(IMG_W-2);
    localparam BRAM_DEPTH = NUM_FILTERS * PIXELS_L1;
    localparam BRAM_ADDR_W = $clog2(BRAM_DEPTH);
    localparam BRAM_DATA_W = DATA_W_L1;

    // instantiate BRAM
    wire [BRAM_DATA_W-1:0] bram_dout;
    reg  [BRAM_ADDR_W-1:0] bram_addr;
    reg  [BRAM_DATA_W-1:0] bram_din;
    reg                    bram_we;

    bram_simple #(
        .DATA_WIDTH(BRAM_DATA_W),
        .ADDR_WIDTH(BRAM_ADDR_W)
    ) u_bram (
        .clk(clk),
        .we(bram_we),
        .addr(bram_addr),
        .din(bram_din),
        .dout(bram_dout)
    );

    // FSM states
    localparam IDLE   = 2'd0,
               L1_RUN = 2'd1,
               L2_RUN = 2'd2,
               DONE   = 2'd3;
    reg [1:0] state, next_state;

    // layer1 conv outputs (parallel units)
    wire signed [DATA_W_L1-1:0] conv_out_l1 [0:NUM_FILTERS-1];

    genvar fi;
    generate
        for (fi = 0; fi < NUM_FILTERS; fi = fi + 1) begin : L1_UNITS
            rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_WIDTH)) conv1 (
                .clk(clk), .rst(rst), .load_weight(load_weight),
                .input_col_r(input_col_r), .input_col_g(input_col_g), .input_col_b(input_col_b),
                .weights_r({9{8'd1}}), .weights_g({9{8'd1}}), .weights_b({9{8'd1}}),
                .conv_out_rgb(conv_out_l1[fi])
            );
        end
    endgenerate

    // Storage for final layer2 outputs (packed per filter per pixel)
    localparam PIXELS_L2 = (IMG_H-4)*(IMG_W-4);
    // memory to store layer2 outputs sequentially
    reg signed [DATA_W_L2-1:0] layer2_mem [0:NUM_FILTERS*PIXELS_L2-1];

    // second-layer conv units - expect input columns sized for DATA_W_L1 per element
    // we will feed input_col_r2/g2/b2 built from bram_dout values
    wire [3*DATA_W_L1-1:0] input_col_r2, input_col_g2, input_col_b2;
    // We build these concatenations in read logic below

    wire signed [DATA_W_L2-1:0] conv_out_l2 [0:NUM_FILTERS-1];
    generate
        for (fi = 0; fi < NUM_FILTERS; fi = fi + 1) begin : L2_UNITS
            rgb_systolic_array_3x3 #(.DATA_WIDTH(DATA_W_L1)) conv2 (
                .clk(clk), .rst(rst), .load_weight(load_weight),
                .input_col_r(input_col_r2), .input_col_g(input_col_g2), .input_col_b(input_col_b2),
                .weights_r({9{ { {(BRAM_DATA_W-1){1'b0}}, 1'b1 } }}),
                .weights_g({9{ { {(BRAM_DATA_W-1){1'b0}}, 1'b1 } }}),
                .weights_b({9{ { {(BRAM_DATA_W-1){1'b0}}, 1'b1 } }}),
                .conv_out_rgb(conv_out_l2[fi])
            );
        end
    endgenerate

    // counters
    reg [BRAM_ADDR_W-1:0] write_addr;
    reg [BRAM_ADDR_W-1:0] read_addr;
    reg [$clog2(NUM_FILTERS)-1:0] write_fidx; // filter index for writes (0..NUM_FILTERS-1)
    reg [$clog2(NUM_FILTERS)-1:0] read_fidx;

    // temporary registers to build second-layer input columns
    reg [BRAM_DATA_W-1:0] readbuf0, readbuf1, readbuf2;

    // flatten output assignment (layer2_mem -> conv_outs)
    genvar k;
    generate
        for (k = 0; k < NUM_FILTERS*PIXELS_L2; k = k + 1) begin : FLATTEN_L2
            assign conv_outs[
                ((k+1)*DATA_W_L2)-1 -: DATA_W_L2
            ] = layer2_mem[k];
        end
    endgenerate

    // FSM sequential
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            bram_we <= 0;
            bram_addr <= 0;
            write_addr <= 0;
            read_addr <= 0;
            write_fidx <= 0;
            read_fidx <= 0;
            done <= 0;
            // clear layer2_mem (optional for sim hygiene)
            
            for (zz = 0; zz < NUM_FILTERS*PIXELS_L2; zz = zz + 1) layer2_mem[zz] <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 0;
                    // start Layer1
                    write_addr <= 0;
                    write_fidx <= 0;
                    bram_addr <= 0;
                    bram_we <= 0;
                end

                L1_RUN: begin
                    // sequentially write all conv_out_l1 into BRAM
                    // write per-filter per-pixel: address = write_addr*NUM_FILTERS + write_fidx
                    bram_din <= conv_out_l1[write_fidx];
                    bram_we <= 1;
                    bram_addr <= write_addr * NUM_FILTERS + write_fidx;

                    // next indices
                    if (write_fidx == NUM_FILTERS - 1) begin
                        write_fidx <= 0;
                        write_addr <= write_addr + 1;
                    end else begin
                        write_fidx <= write_fidx + 1;
                    end
                end

                L2_RUN: begin
                   
                    bram_we <= 0;

                    // Perform synchronous read: set address and capture bram_dout next cycle.
                    bram_addr <= read_addr; // read first
                    // We will assemble input_col_* using a small three-cycle pipeline
                    // To keep things simple, here we run a 3-cycle microstate:
                end

                DONE: begin
                    bram_we <= 0;
                    done <= 1;
                end
            endcase
        end
    end

    // FSM combinational next-state logic (simple)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = L1_RUN;
            L1_RUN: begin
                // when we've written all BRAM entries (BRAM_DEPTH entries written)
                // write_addr will have advanced PIXELS_L1 times (each pixel wrote NUM_FILTERS words)
                if ( (write_addr == PIXELS_L1) && (write_fidx == 0) )
                    next_state = L2_RUN;
                else
                    next_state = L1_RUN;
            end
            L2_RUN: begin
                // We'll implement a read-driven termination: when read_addr reaches necessary count
                if (read_addr == NUM_FILTERS*PIXELS_L2) // approximate condition
                    next_state = DONE;
                else
                    next_state = L2_RUN;
            end
            DONE: next_state = DONE;
        endcase
    end

    reg [2:0] l2_phase;
    reg [BRAM_ADDR_W-1:0] l2_pixel_idx; // index of pixel for layer2 (0..PIXELS_L2-1)
    reg [BRAM_ADDR_W-1:0] l2_read_base;

    // drivers for conv2 input columns (shared for all conv2 instances in this simplified model)
    reg [3*DATA_W_L1-1:0] conv2_in_r_r, conv2_in_g_r, conv2_in_b_r;
    assign input_col_r2 = conv2_in_r_r;
    assign input_col_g2 = conv2_in_g_r;
    assign input_col_b2 = conv2_in_b_r;

    // We'll use a small temporary place to store conv_out_l2 per filter before writing to layer2_mem
    integer write_l2_index;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            l2_phase <= 0;
            l2_pixel_idx <= 0;
            read_addr <= 0;
            read_fidx <= 0;
            l2_read_base <= 0;
            write_l2_index <= 0;
        end else begin
            if (state == L2_RUN) begin
                case (l2_phase)
                    0: begin
                        // Initiate read: set bram_addr to base (synchronous read will produce bram_dout next clock)
                        bram_addr <= l2_read_base;
                        l2_phase <= 1;
                    end
                    1: begin
                        // capture first read
                        readbuf0 <= bram_dout;
                        bram_addr <= l2_read_base + 1;
                        l2_phase <= 2;
                    end
                    2: begin
                        readbuf1 <= bram_dout;
                        bram_addr <= l2_read_base + 2;
                        l2_phase <= 3;
                    end
                    3: begin
                        readbuf2 <= bram_dout;
                        // now we have three words, build conv2 inputs and let conv2 units compute next cycle
                        // pack into 3*DATA_W_L1 bits each channel: we put same value into r/g/b fields for simplicity.
                        conv2_in_r_r <= {readbuf2, readbuf1, readbuf0};
                        conv2_in_g_r <= {readbuf2, readbuf1, readbuf0};
                        conv2_in_b_r <= {readbuf2, readbuf1, readbuf0};
                        // advance for next pixel base (we choose a simple stride of 1 BRAM word for demo)
                        l2_read_base <= l2_read_base + NUM_FILTERS; // move to next pixel's base
                        l2_phase <= 4;
                    end
                    4: begin
                        // conv_out_l2 are valid (behavioral model produces output after shifting 3 columns in its internal regs)
                        // write conv_out_l2 sequentially into layer2_mem using write_l2_index
                        
                        for (ff = 0; ff < NUM_FILTERS; ff = ff + 1) begin
                            layer2_mem[write_l2_index] <= conv_out_l2[ff];
                            write_l2_index <= write_l2_index + 1;
                        end
                        // increment pixel count; simple stop condition:
                        if (write_l2_index >= NUM_FILTERS*PIXELS_L2) begin
                            // done
                            read_addr <= write_l2_index;
                        end
                        l2_phase <= 0;
                    end
                endcase
            end
        end
    end

endmodule
