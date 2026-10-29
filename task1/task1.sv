`timescale 1ps / 1ps
// Board I/O (DE10-Lite): CLOCK_50 is the 50 MHz clock and KEY[1] is the
// active-low reset (KEY[0] is unused). Keep these port names: the provided
// settings/DE10_Lite.qsf assigns them to the board's pins.
module task1(input logic CLOCK_50, input logic [1:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);


    logic wren;
    logic [7:0] addr, wrdata;
    logic rdy;
    logic en;
    logic started;


    s_mem s(.address(addr), .clock(CLOCK_50), .data(wrdata), .wren(wren), .q());

    init dut(.clk(CLOCK_50), .rst_n(KEY[1]),
           .en(en), .rdy(rdy),
           .addr(addr), .wrdata(wrdata), .wren(wren));



    always_ff @(posedge CLOCK_50, negedge KEY[1]) begin
        if (!KEY[1])
            started <= 1'b0;
        else if (rdy && !started)
            started <= 1'b1;
    end

    assign en = rdy & ~started;

    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign LEDR = 10'b0;

endmodule: task1
