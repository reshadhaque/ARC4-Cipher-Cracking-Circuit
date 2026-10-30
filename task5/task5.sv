`timescale 1ps / 1ps
// Board I/O (DE10-Lite): CLOCK_50 is the 50 MHz clock and KEY[1] is the
// active-low reset (KEY[0] is unused). Keep these port names: the provided
// settings/DE10_Lite.qsf assigns them to the board's pins.
module task5(input logic CLOCK_50, input logic [1:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // CT memory signals (doublecrack only reads CT)
    logic [7:0] ct_addr, ct_rddata;

    // Handshake signals between task5 (caller) and doublecrack (callee)
    logic       en, rdy;
    logic       started;        // 1 once we've issued our single request

    // doublecrack's results
    logic [23:0] key;
    logic        key_valid;

    // done = doublecrack was started and has finished (it is ready again)
    logic        done;

    // 7-segment patterns (active-low: 0 = segment on), bit order {g, f, e, d, c, b, a}
    localparam logic [6:0] BLANK = 7'b1111111;     // all segments off
    localparam logic [6:0] DASH  = 7'b0111111;     // only the middle segment (g) on


    ct_mem ct(.address(ct_addr), .clock(CLOCK_50), .data(8'd0), .wren(1'b0), .q(ct_rddata));

    doublecrack dc(.clk(CLOCK_50), .rst_n(KEY[1]),
                   .en(en), .rdy(rdy),
                   .key(key), .key_valid(key_valid),
                   .ct_addr(ct_addr), .ct_rddata(ct_rddata));


    // One-shot start: request doublecrack exactly once after each reset
    always_ff @(posedge CLOCK_50, negedge KEY[1]) begin
        if (!KEY[1])
            started <= 1'b0;
        else if (rdy && !started)
            started <= 1'b1;
    end

    // en is high for exactly one cycle: the first cycle doublecrack is ready
    assign en = rdy & ~started;

    // doublecrack is finished once it has been started and is ready again
    assign done = started & rdy;


    // Hex digit (0..F) to 7-segment pattern, matching the digits in the handout
    function automatic logic [6:0] hex_to_7seg(input logic [3:0] digit);
        case (digit)
            4'h0:    hex_to_7seg = 7'b1000000;     // 0
            4'h1:    hex_to_7seg = 7'b1111001;     // 1
            4'h2:    hex_to_7seg = 7'b0100100;     // 2
            4'h3:    hex_to_7seg = 7'b0110000;     // 3
            4'h4:    hex_to_7seg = 7'b0011001;     // 4
            4'h5:    hex_to_7seg = 7'b0010010;     // 5
            4'h6:    hex_to_7seg = 7'b0000010;     // 6
            4'h7:    hex_to_7seg = 7'b1111000;     // 7
            4'h8:    hex_to_7seg = 7'b0000000;     // 8
            4'h9:    hex_to_7seg = 7'b0010000;     // 9
            4'hA:    hex_to_7seg = 7'b0001000;     // A
            4'hB:    hex_to_7seg = 7'b0000011;     // b (lowercase)
            4'hC:    hex_to_7seg = 7'b1000110;     // C
            4'hD:    hex_to_7seg = 7'b0100001;     // d (lowercase)
            4'hE:    hex_to_7seg = 7'b0000110;     // E
            4'hF:    hex_to_7seg = 7'b0001110;     // F
            default: hex_to_7seg = BLANK;
        endcase
    endfunction


    // Display logic
    always_comb begin
        if (!done)
            begin                                   // still searching: displays blank
                HEX5 = BLANK;
                HEX4 = BLANK;
                HEX3 = BLANK;
                HEX2 = BLANK;
                HEX1 = BLANK;
                HEX0 = BLANK;
            end
        else if (key_valid)
            begin                                   // key found: show it in hex, HEX5 = most significant digit
                HEX5 = hex_to_7seg(key[23:20]);
                HEX4 = hex_to_7seg(key[19:16]);
                HEX3 = hex_to_7seg(key[15:12]);
                HEX2 = hex_to_7seg(key[11:8]);
                HEX1 = hex_to_7seg(key[7:4]);
                HEX0 = hex_to_7seg(key[3:0]);
            end
        else
            begin                                   // searched every key, none worked: dashes
                HEX5 = DASH;
                HEX4 = DASH;
                HEX3 = DASH;
                HEX2 = DASH;
                HEX1 = DASH;
                HEX0 = DASH;
            end
    end

    // Unused outputs
    assign LEDR = 10'b0;

endmodule: task5
