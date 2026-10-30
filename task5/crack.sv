`timescale 1ps / 1ps

// Task 5 version of crack.
// Same as Task 4, plus four ADDED ports (the original ports are unchanged):
//   start_key     : first key to try (doublecrack gives 0 to c1 and 1 to c2)
//   stop          : the other core found the key, so give up after the current attempt
//   rd_pt_addr    : lets doublecrack read this core's PT memory while crack is idle
//   rd_pt_rddata  : the value read from this core's PT memory
// Keys now go up by 2 (c1: 0, 2, 4, ...  c2: 1, 3, 5, ...).

module crack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
             input logic [23:0] start_key,
             input logic stop,
             input logic [7:0] rd_pt_addr, output logic [7:0] rd_pt_rddata);

    // arc4's PT signals (arc4 writes the plaintext through these)
    logic [7:0] a4_pt_addr, a4_pt_wrdata;
    logic       a4_pt_wren;

    // Signals going into the PT memory (driven by the output logic below)
    logic [7:0] pt_mem_addr, pt_rddata;

    // Handshake signals between crack (caller) and arc4 (callee)
    logic       a4_en, a4_rdy;

    // bad = 1 if the current attempt wrote a character outside 'h20..'h7E
    logic       bad;

    // Controller states
    typedef enum logic [1:0] {IDLE, START_ARC4, WAIT_ARC4, CHECK} state_type;

    state_type state, next_state;


    // this memory must have the length-prefixed plaintext if key_valid
    // (only arc4 writes it; its address comes from arc4 while searching, or from doublecrack while idle)
    pt_mem pt(.address(pt_mem_addr), .clock(clk), .data(a4_pt_wrdata), .wren(a4_pt_wren), .q(pt_rddata));

    arc4 a4(.clk(clk), .rst_n(rst_n),
            .en(a4_en), .rdy(a4_rdy),
            .key(key),
            .ct_addr(ct_addr), .ct_rddata(ct_rddata),
            .pt_addr(a4_pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(a4_pt_wrdata), .pt_wren(a4_pt_wren));

    // whatever the PT memory reads is also sent out to doublecrack
    assign rd_pt_rddata = pt_rddata;


    // State register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:       if (en)     next_state = START_ARC4;   // a request has arrived
            START_ARC4: if (a4_rdy) next_state = WAIT_ARC4;    // a4_en goes out this cycle
            WAIT_ARC4:  if (a4_rdy) next_state = CHECK;        // arc4 finished decrypting with this key
            CHECK:
                begin
                if (!bad)                       // every character was readable: key found
                    next_state = IDLE;
                else if (stop)                  // the other core found the key: give up
                    next_state = IDLE;
                else if (key >= 24'hFFFFFE)     // key + 2 would go past 'hFFFFFF: every key of ours was tried
                    next_state = IDLE;
                else                            // try the next key
                    next_state = START_ARC4;
                end
            default:    next_state = IDLE;
        endcase
    end

    // Datapath registers: key, key_valid, bad
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
             begin
                key       <= 24'd0;
                key_valid <= 1'b0;
                bad       <= 1'b0;
            end

        else
            begin
            case (state)
                IDLE:
                    begin
                        if (en)
                            begin               // start a new search from start_key (0 for c1, 1 for c2)
                                key       <= start_key;
                                key_valid <= 1'b0;
                                bad       <= bad;
                            end
                        else
                            begin               // no request: hold (key and key_valid keep the last result)
                                key       <= key;
                                key_valid <= key_valid;
                                bad       <= bad;
                            end
                    end
                START_ARC4:
                    begin                       // new attempt: nothing bad seen yet
                        key       <= key;
                        key_valid <= key_valid;
                        bad       <= 1'b0;
                    end
                WAIT_ARC4:
                    begin                       // arc4 is writing PT: watch every character it writes
                        key       <= key;
                        key_valid <= key_valid;
                        if (a4_pt_wren && (a4_pt_addr != 8'd0) && ((a4_pt_wrdata < 8'h20) || (a4_pt_wrdata > 8'h7E)))
                            bad   <= 1'b1;      // unreadable character (address 0 is the length, so it is skipped)
                        else
                            bad   <= bad;
                    end
                CHECK:
                    begin
                        if (!bad)
                            begin               // key found: keep this key, mark it valid
                                key       <= key;
                                key_valid <= 1'b1;
                                bad       <= bad;
                            end
                        else if (stop || (key >= 24'hFFFFFE))
                            begin               // told to stop, or nothing left to try: key_valid stays 0
                                key       <= key;
                                key_valid <= 1'b0;
                                bad       <= bad;
                            end
                        else
                            begin               // wrong key: skip ahead by 2 (the other core tries the keys in between)
                                key       <= key + 24'd2;
                                key_valid <= key_valid;
                                bad       <= bad;
                            end
                    end
                default:
                    begin                       // unused encodings: hold
                        key       <= key;
                        key_valid <= key_valid;
                        bad       <= bad;
                    end
            endcase
        end
    end

    // Output Logic
    always_comb begin
        case (state)
            IDLE:
                begin                              // idle: crack is ready; doublecrack may read our PT through rd_pt_addr
                    rdy         = 1'b1;
                    a4_en       = 1'b0;
                    pt_mem_addr = rd_pt_addr;
                end
            START_ARC4:
                begin                              // request arc4 for one cycle, only once it is ready
                    rdy         = 1'b0;
                    a4_en       = a4_rdy;
                    pt_mem_addr = a4_pt_addr;
                end
            WAIT_ARC4:
                begin                              // arc4 is decrypting and controls the PT memory
                    rdy         = 1'b0;
                    a4_en       = 1'b0;
                    pt_mem_addr = a4_pt_addr;
                end
            CHECK:
                begin                              // deciding: found, give up, or next key
                    rdy         = 1'b0;
                    a4_en       = 1'b0;
                    pt_mem_addr = a4_pt_addr;
                end
            default:
                begin                              // unused encodings: do nothing
                    rdy         = 1'b0;
                    a4_en       = 1'b0;
                    pt_mem_addr = a4_pt_addr;
                end
        endcase
    end

endmodule: crack
