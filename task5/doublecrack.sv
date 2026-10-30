`timescale 1ps / 1ps

// doublecrack: runs two crack cores at the same time.
//   c1 tries keys 0, 2, 4, ...   c2 tries keys 1, 3, 5, ...
// Steps:
//   1. Copy the message from the outside CT memory into two private copies (ct1, ct2),
//      because doublecrack has only one CT port but both cores need to read CT.
//   2. Start both cores together and wait.
//   3. As soon as one core finds the key, copy the winner's plaintext from its own PT
//      into the shared PT memory. The other core is told to stop (stop = 1 in every state
//      except WAIT_CRACKS), so it gives up at the end of its current attempt.
//      We don't wait for it: its leftover attempt only touches its own memories.

module doublecrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    // Core 1 (c1) signals
    logic        c1_rdy, c1_key_valid;
    logic [23:0] c1_key;
    logic [7:0]  c1_ct_addr, c1_ct_rddata, c1_rd_pt_rddata;

    // Core 2 (c2) signals
    logic        c2_rdy, c2_key_valid;
    logic [23:0] c2_key;
    logic [7:0]  c2_ct_addr, c2_ct_rddata, c2_rd_pt_rddata;

    // Signals shared by both cores (driven by the output logic below)
    logic        crack_en;          // starts both cores at the same time
    logic        stop;              // tells a busy core to give up (1 everywhere except WAIT_CRACKS)
    logic [7:0]  rd_pt_addr;        // which byte of the cores' PT memories to read

    // Private CT copies: addresses, and one write enable for both
    logic [7:0]  ct1_addr, ct2_addr;
    logic        ctc_wren;

    // Shared PT memory signals
    logic [7:0]  pt_addr, pt_wrdata, pt_rddata;
    logic        pt_wren;

    // Datapath registers
    logic [7:0]  idx;               // which byte we are copying
    logic [7:0]  len;               // message length (byte 0 of CT / PT)
    logic        winner;            // 0 = c1 found the key, 1 = c2 found it

    // Helper signals
    logic [7:0]  winner_pt_rddata;  // byte read from the winning core's PT
    logic        ct_copy_last;      // this is the last CT byte to copy
    logic        pt_copy_last;      // this is the last PT byte to copy

    // Controller states
    typedef enum logic [2:0] {IDLE, CT_READ, CT_WRITE, START_CRACKS, WAIT_CRACKS, PT_READ, PT_WRITE} state_type;

    state_type state, next_state;


    // this memory must have the length-prefixed plaintext if key_valid
    pt_mem pt(.address(pt_addr), .clock(clk), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));

    // Private CT copies: both are written with the byte read from the outside CT (ct_rddata)
    ct_mem ct1(.address(ct1_addr), .clock(clk), .data(ct_rddata), .wren(ctc_wren), .q(c1_ct_rddata));
    ct_mem ct2(.address(ct2_addr), .clock(clk), .data(ct_rddata), .wren(ctc_wren), .q(c2_ct_rddata));

    // for this task only, you may ADD ports to crack
    crack c1(.clk(clk), .rst_n(rst_n),
             .en(crack_en), .rdy(c1_rdy),
             .key(c1_key), .key_valid(c1_key_valid),
             .ct_addr(c1_ct_addr), .ct_rddata(c1_ct_rddata),
             .start_key(24'd0),                         // c1: even keys
             .stop(stop),
             .rd_pt_addr(rd_pt_addr), .rd_pt_rddata(c1_rd_pt_rddata));

    crack c2(.clk(clk), .rst_n(rst_n),
             .en(crack_en), .rdy(c2_rdy),
             .key(c2_key), .key_valid(c2_key_valid),
             .ct_addr(c2_ct_addr), .ct_rddata(c2_ct_rddata),
             .start_key(24'd1),                         // c2: odd keys
             .stop(stop),
             .rd_pt_addr(rd_pt_addr), .rd_pt_rddata(c2_rd_pt_rddata));


    // Byte coming back from the winning core's PT memory
    assign winner_pt_rddata = (winner == 1'b0) ? c1_rd_pt_rddata : c2_rd_pt_rddata;

    // Last byte to copy: byte 0 holds the length, so we stop when idx reaches it
    // (at idx 0 the length is still arriving, so compare with the value being read right now)
    assign ct_copy_last = (idx == 8'd0) ? (ct_rddata == 8'd0)        : (idx == len);
    assign pt_copy_last = (idx == 8'd0) ? (winner_pt_rddata == 8'd0) : (idx == len);


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
            IDLE:         if (en) next_state = CT_READ;                 // a request has arrived: copy CT first
            CT_READ:      next_state = CT_WRITE;
            CT_WRITE:
                begin
                if (ct_copy_last)                                       // whole message copied: start the cores
                    next_state = START_CRACKS;
                else                                                    // copy the next byte
                    next_state = CT_READ;
                end
            START_CRACKS: if (c1_rdy && c2_rdy) next_state = WAIT_CRACKS;   // both idle (a stopped core may still be finishing): crack_en goes out this cycle
            WAIT_CRACKS:
                begin
                if ((c1_rdy && c1_key_valid) || (c2_rdy && c2_key_valid))   // one core found the key: copy its plaintext
                    next_state = PT_READ;
                else if (c1_rdy && c2_rdy)                                  // both searched everything: no key
                    next_state = IDLE;
                else                                                        // keep waiting
                    next_state = WAIT_CRACKS;
                end
            PT_READ:      next_state = PT_WRITE;
            PT_WRITE:
                begin
                if (pt_copy_last)                                       // whole plaintext copied: done
                    next_state = IDLE;
                else                                                    // copy the next byte
                    next_state = PT_READ;
                end
            default:      next_state = IDLE;
        endcase
    end

    // Datapath registers: idx, len, winner, key, key_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
             begin
                idx       <= 8'd0;
                len       <= 8'd0;
                winner    <= 1'b0;
                key       <= 24'd0;
                key_valid <= 1'b0;
            end

        else
            begin
            case (state)
                IDLE:
                    begin
                        if (en)
                            begin               // start a new search: copy CT from byte 0, forget the old result
                                idx       <= 8'd0;
                                len       <= len;
                                winner    <= winner;
                                key       <= key;
                                key_valid <= 1'b0;
                            end
                        else
                            begin               // no request: hold (key and key_valid keep the last result)
                                idx       <= idx;
                                len       <= len;
                                winner    <= winner;
                                key       <= key;
                                key_valid <= key_valid;
                            end
                    end
                CT_READ:
                    begin                       // waiting for CT[idx] to arrive: hold all the values
                        idx       <= idx;
                        len       <= len;
                        winner    <= winner;
                        key       <= key;
                        key_valid <= key_valid;
                    end
                CT_WRITE:
                    begin                       // CT[idx] is in ct_rddata and is being written to both copies
                        idx       <= idx + 8'd1;
                        if (idx == 8'd0)
                            len   <= ct_rddata; // byte 0 is the length: remember it
                        else
                            len   <= len;
                        winner    <= winner;
                        key       <= key;
                        key_valid <= key_valid;
                    end
                START_CRACKS:
                    begin                       // starting both cores: hold all the values
                        idx       <= idx;
                        len       <= len;
                        winner    <= winner;
                        key       <= key;
                        key_valid <= key_valid;
                    end
                WAIT_CRACKS:
                    begin
                        idx       <= 8'd0;      // the PT copy (if a key is found) starts from byte 0
                        len       <= len;
                        if (c1_rdy && c1_key_valid)
                            begin               // c1 found it (checked first, so c1 wins a tie: its key is smaller)
                                winner    <= 1'b0;
                                key       <= c1_key;
                                key_valid <= 1'b1;
                            end
                        else if (c2_rdy && c2_key_valid)
                            begin               // c2 found it
                                winner    <= 1'b1;
                                key       <= c2_key;
                                key_valid <= 1'b1;
                            end
                        else
                            begin               // still searching, or both gave up: key_valid stays 0
                                winner    <= winner;
                                key       <= key;
                                key_valid <= key_valid;
                            end
                    end
                PT_READ:
                    begin                       // waiting for the winner's PT[idx] to arrive: hold all the values
                        idx       <= idx;
                        len       <= len;
                        winner    <= winner;
                        key       <= key;
                        key_valid <= key_valid;
                    end
                PT_WRITE:
                    begin                       // winner's PT[idx] is being written to the shared PT
                        idx       <= idx + 8'd1;
                        len       <= len;
                        winner    <= winner;
                        key       <= key;
                        key_valid <= key_valid;
                    end
                default:
                    begin                       // unused encodings: hold
                        idx       <= idx;
                        len       <= len;
                        winner    <= winner;
                        key       <= key;
                        key_valid <= key_valid;
                    end
            endcase
        end
    end

    // Output Logic
    always_comb begin
        case (state)
            IDLE:
                begin                              // waiting for a request: doublecrack is ready
                    rdy        = 1'b1;
                    ct_addr    = 8'd0;
                    ct1_addr   = c1_ct_addr;
                    ct2_addr   = c2_ct_addr;
                    ctc_wren   = 1'b0;
                    crack_en   = 1'b0;
                    stop       = 1'b1;
                    rd_pt_addr = 8'd0;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
            CT_READ:
                begin                              // request CT[idx] from the outside CT
                    rdy        = 1'b0;
                    ct_addr    = idx;
                    ct1_addr   = idx;
                    ct2_addr   = idx;
                    ctc_wren   = 1'b0;
                    crack_en   = 1'b0;
                    stop       = 1'b1;
                    rd_pt_addr = 8'd0;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
            CT_WRITE:
                begin                              // CT[idx] is in ct_rddata: write it into both copies at idx
                    rdy        = 1'b0;
                    ct_addr    = idx;
                    ct1_addr   = idx;
                    ct2_addr   = idx;
                    ctc_wren   = 1'b1;
                    crack_en   = 1'b0;
                    stop       = 1'b1;
                    rd_pt_addr = 8'd0;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
            START_CRACKS:
                begin                              // start both cores together, once both are ready
                    rdy        = 1'b0;
                    ct_addr    = 8'd0;
                    ct1_addr   = c1_ct_addr;
                    ct2_addr   = c2_ct_addr;
                    ctc_wren   = 1'b0;
                    crack_en   = c1_rdy && c2_rdy;
                    stop       = 1'b1;
                    rd_pt_addr = 8'd0;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
            WAIT_CRACKS:
                begin                              // both cores are searching, each reading its own CT copy
                    rdy        = 1'b0;
                    ct_addr    = 8'd0;
                    ct1_addr   = c1_ct_addr;
                    ct2_addr   = c2_ct_addr;
                    ctc_wren   = 1'b0;
                    crack_en   = 1'b0;
                    stop       = 1'b0;                 // the only state where the cores may keep searching
                    rd_pt_addr = 8'd0;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
            PT_READ:
                begin                              // request PT[idx] from the cores (the winner is idle, so its PT answers rd_pt_addr)
                    rdy        = 1'b0;
                    ct_addr    = 8'd0;
                    ct1_addr   = c1_ct_addr;
                    ct2_addr   = c2_ct_addr;
                    ctc_wren   = 1'b0;
                    crack_en   = 1'b0;
                    stop       = 1'b1;
                    rd_pt_addr = idx;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
            PT_WRITE:
                begin                              // winner's PT[idx] has arrived: write it into the shared PT at idx
                    rdy        = 1'b0;
                    ct_addr    = 8'd0;
                    ct1_addr   = c1_ct_addr;
                    ct2_addr   = c2_ct_addr;
                    ctc_wren   = 1'b0;
                    crack_en   = 1'b0;
                    stop       = 1'b1;
                    rd_pt_addr = idx;
                    pt_addr    = idx;
                    pt_wrdata  = winner_pt_rddata;
                    pt_wren    = 1'b1;
                end
            default:
                begin                              // unused encodings: do nothing
                    rdy        = 1'b0;
                    ct_addr    = 8'd0;
                    ct1_addr   = c1_ct_addr;
                    ct2_addr   = c2_ct_addr;
                    ctc_wren   = 1'b0;
                    crack_en   = 1'b0;
                    stop       = 1'b1;
                    rd_pt_addr = 8'd0;
                    pt_addr    = 8'd0;
                    pt_wrdata  = 8'd0;
                    pt_wren    = 1'b0;
                end
        endcase
    end

endmodule: doublecrack