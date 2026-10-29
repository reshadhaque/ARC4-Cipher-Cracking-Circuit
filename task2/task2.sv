`timescale 1ps / 1ps
// Board I/O (DE10-Lite): CLOCK_50 is the 50 MHz clock and KEY[1] is the
// active-low reset (KEY[0] is unused). Keep these port names: the provided
// settings/DE10_Lite.qsf assigns them to the board's pins.
module task2(input logic CLOCK_50, input logic [1:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // Signals going into the S memory (driven by the mux below)
    logic wren;
    logic [7:0] addr, wrdata, rddata;

    // init's signals
    logic init_en, init_rdy, init_wren;
    logic [7:0] init_addr, init_wrdata;

    // ksa's signals
    logic ksa_en, ksa_rdy, ksa_wren;
    logic [7:0] ksa_addr, ksa_wrdata;

    // Key: only the switches are used, upper bits are 0 (Tasks 2 and 3)
    logic [23:0] key;
    assign key = {14'b0, SW};

    // Controller states
    typedef enum logic [2:0] {START_INIT, WAIT_INIT, START_KSA, WAIT_KSA, DONE} state_type;
    state_type state, next_state;


    s_mem s(.address(addr), .clock(CLOCK_50), .data(wrdata), .wren(wren), .q(rddata));

    init i(.clk(CLOCK_50), .rst_n(KEY[1]),
           .en(init_en), .rdy(init_rdy),
           .addr(init_addr), .wrdata(init_wrdata), .wren(init_wren));

    ksa k(.clk(CLOCK_50), .rst_n(KEY[1]),
          .en(ksa_en), .rdy(ksa_rdy),
          .key(key),
          .addr(ksa_addr), .rddata(rddata), .wrdata(ksa_wrdata), .wren(ksa_wren));


    // State register
    always_ff @(posedge CLOCK_50, negedge KEY[1]) begin
        if (!KEY[1])
            state <= START_INIT;
        else
            state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = state;
        case (state)
            START_INIT: if (init_rdy) next_state = WAIT_INIT;   // en goes out this cycle
            WAIT_INIT:  if (init_rdy) next_state = START_KSA;   // init finished
            START_KSA:  if (ksa_rdy)  next_state = WAIT_KSA;    // en goes out this cycle
            WAIT_KSA:   if (ksa_rdy)  next_state = DONE;        // ksa finished
            DONE:       next_state = DONE;                      // stay here until reset
            default:    next_state = START_INIT;
        endcase
    end

    // Enables: one-cycle request, only while the module is ready
    assign init_en = (state == START_INIT) && init_rdy;
    assign ksa_en  = (state == START_KSA)  && ksa_rdy;

    // Memory mux: init drives S during its phase, ksa drives it afterwards
    always_comb begin
        case (state)
            START_INIT:
                begin                       // init is about to start: init drives S
                    addr   = init_addr;
                    wrdata = init_wrdata;
                    wren   = init_wren;
                end
            WAIT_INIT:
                begin                       // init is filling S: init drives S
                    addr   = init_addr;
                    wrdata = init_wrdata;
                    wren   = init_wren;
                end
            START_KSA:
                begin                       // ksa is about to start: ksa drives S
                    addr   = ksa_addr;
                    wrdata = ksa_wrdata;
                    wren   = ksa_wren;
                end
            WAIT_KSA:
                begin                       // ksa is shuffling S: ksa drives S
                    addr   = ksa_addr;
                    wrdata = ksa_wrdata;
                    wren   = ksa_wren;
                end
            DONE:
                begin                       // both finished: ksa is idle, so wren = 0 and S is untouched
                    addr   = ksa_addr;
                    wrdata = ksa_wrdata;
                    wren   = ksa_wren;
                end
            default:
                begin                       // unused encodings: no memory access
                    addr   = 8'd0;
                    wrdata = 8'd0;
                    wren   = 1'b0;
                end
        endcase
    end

    // Unused outputs
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign LEDR = 10'b0;

endmodule: task2