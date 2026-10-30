`timescale 1ps / 1ps
// Board I/O (DE10-Lite): CLOCK_50 is the 50 MHz clock and KEY[1] is the
// active-low reset (KEY[0] is unused). Keep these port names: the provided
// settings/DE10_Lite.qsf assigns them to the board's pins.
module task3(input logic CLOCK_50, input logic [1:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // CT memory signals (arc4 only reads CT)
    logic [7:0] ct_addr, ct_rddata;

    // PT memory signals (arc4 writes the plaintext here)
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic       pt_wren;

    // Handshake signals between task3 (caller) and arc4 (callee)
    logic       en, rdy;
    logic       started;        // 1 once we've issued our single request

    // Key: only the switches are used, upper 14 bits are 0 (in the toplevel only)
    logic [23:0] key;
    assign key = {14'b0, SW};


    ct_mem ct(.address(ct_addr), .clock(CLOCK_50), .data(8'd0), .wren(1'b0), .q(ct_rddata));

    pt_mem pt(.address(pt_addr), .clock(CLOCK_50), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));

    arc4 a4(.clk(CLOCK_50), .rst_n(KEY[1]),
            .en(en), .rdy(rdy),
            .key(key),
            .ct_addr(ct_addr), .ct_rddata(ct_rddata),
            .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));


    // One-shot start: request arc4 exactly once after each reset
    always_ff @(posedge CLOCK_50, negedge KEY[1]) begin
        if (!KEY[1])
            started <= 1'b0;
        else if (rdy && !started)
            started <= 1'b1;
    end

    // en is high for exactly one cycle: the first cycle arc4 is ready
    assign en = rdy & ~started;

    // Unused outputs
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign LEDR = 10'b0;

endmodule: task3