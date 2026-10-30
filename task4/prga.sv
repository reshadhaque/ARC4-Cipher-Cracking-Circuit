`timescale 1ps / 1ps

module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // your code here

      typedef enum logic [3:0] {IDLE, READ_LEN, WRITE_LEN, READ_SI, CALC_J, READ_SJ, WRITE_SI, WRITE_SJ, READ_PAD, WRITE_PT} state_type;
 
    state_type state, next_state;
 
    logic [7:0] i, j;       // PRGA's own indices (separate from ksa's)
    logic [7:0] si;         // Saved copy of s[i]
    logic [7:0] sj;         // Saved copy of s[j]
    logic [7:0] k;          // Which character we are on (0 .. len-1)
    logic [7:0] len;        // Message length, read from CT[0]
 
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
            IDLE: if (en) next_state = READ_LEN;
            READ_LEN:  next_state = WRITE_LEN;
            WRITE_LEN:
                begin
                if (ct_rddata == 8'd0)          // empty message: nothing to decrypt
                    next_state = IDLE;
                else
                    next_state = READ_SI;
                end
            READ_SI:   next_state = CALC_J;
            CALC_J:    next_state = READ_SJ;
            READ_SJ:   next_state = WRITE_SI;
            WRITE_SI:  next_state = WRITE_SJ;
            WRITE_SJ:  next_state = READ_PAD;
            READ_PAD:  next_state = WRITE_PT;
            WRITE_PT:
                begin
                if (k == len - 8'd1)            // last character written
                    next_state = IDLE;
                else
                    next_state = READ_SI;
                end
            default:next_state = IDLE;
        endcase
    end
 
     // Datapath registers: i, j, si, sj, k, len
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
             begin
                i   <= 8'd0;
                j   <= 8'd0;
                si  <= 8'd0;
                sj  <= 8'd0;
                k   <= 8'd0;
                len <= 8'd0;
            end
 
        else
            begin
            case (state)
                IDLE:
                    begin
                        if (en)
                            begin               // start a new run
                                i   <= 8'd0;
                                j   <= 8'd0;
                                si  <= si;
                                sj  <= sj;
                                k   <= 8'd0;
                                len <= len;
                            end
                        else
                            begin               // no request: hold
                                i   <= i;
                                j   <= j;
                                si  <= si;
                                sj  <= sj;
                                k   <= k;
                                len <= len;
                            end
                    end
                READ_LEN:
                    begin                       // waiting for CT[0] to arrive: hold all the values
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= len;
                    end
                WRITE_LEN:
                    begin
                        i   <= 8'd1;            // the algorithm does i = i+1 before using i, so the first i is 1
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= ct_rddata;       // ct_rddata = CT[0] (the length) in this clock cycle, so len saves it
                    end
                READ_SI:
                    begin                       // waiting for s[i] to arrive: hold all the values
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= len;
                    end
                CALC_J:
                    begin
                        i   <= i;
                        j   <= j + s_rddata;    // j = (j + s[i]) mod 256  (no key in PRGA)
                        si  <= s_rddata;        // s_rddata = s[i] in this clock cycle, so si saves it for later use
                        sj  <= sj;              // The calculation of j and the saving of si happen in the same cycle
                        k   <= k;
                        len <= len;
                    end
                READ_SJ:
                    begin                       // waiting for s[j] to arrive: hold all the values
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= len;
                    end
                WRITE_SI:
                    begin                       // writing s[i] = s[j]
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= s_rddata;        // s_rddata = s[j] in this clock cycle, so sj saves it for the pad address
                        k   <= k;
                        len <= len;
                    end
                WRITE_SJ:
                    begin                       // writing s[j] = old s[i]: hold all the values
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= len;
                    end
                READ_PAD:
                    begin                       // waiting for the pad byte and CT[k+1] to arrive: hold all the values
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= len;
                    end
                WRITE_PT:
                    begin                       // character done: move to the next one
                        i   <= i + 8'd1;        // i = (i+1) mod 256 for the next character
                        j   <= j;               // j carries over to the next character
                        si  <= si;
                        sj  <= sj;
                        k   <= k + 8'd1;
                        len <= len;
                    end
                default:
                    begin                       // unused encodings: hold
                        i   <= i;
                        j   <= j;
                        si  <= si;
                        sj  <= sj;
                        k   <= k;
                        len <= len;
                    end
            endcase
        end
    end
 
    // Output Logic
    always_comb begin
        case (state)
            IDLE:
                begin                              // Idle state: no memory access
                    s_addr    = 8'd0;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            READ_LEN:
                begin                              // Request CT[0] (the length)
                    s_addr    = 8'd0;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            WRITE_LEN:
                begin                              // CT[0] is now in ct_rddata. Copy it to PT[0] (the length is not encrypted)
                    s_addr    = 8'd0;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = ct_rddata;
                    pt_wren   = 1'b1;
                end
            READ_SI:
                begin                              // Request s[i]
                    s_addr    = i;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            CALC_J:
                begin                              // s[i] arrives on s_rddata, no memory access. Keep address the same. (at the next clock edge, si will be remembered)
                    s_addr    = i;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            READ_SJ:
                begin                              // Request s[j] since j has been computed
                    s_addr    = j;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            WRITE_SI:                              // s[j] is now in s_rddata, so set s_addr to i, copy it to s_wrdata, and enable s_wren so the memory can write it
                begin                              // s[i] = s[j]
                    s_addr    = i;
                    s_wrdata  = s_rddata;
                    s_wren    = 1'b1;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            WRITE_SJ:
                begin                              // set s_addr to j, and set s[j] = old s[i] (which we remembered before)
                    s_addr    = j;
                    s_wrdata  = si;
                    s_wren    = 1'b1;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            READ_PAD:
                begin                              // Request the pad byte s[s[i]+s[j]] AND the ciphertext byte CT[k+1] (different memories, so both in one cycle)
                    s_addr    = si + sj;           // 8 bits, so mod 256 is automatic
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = k + 8'd1;          // +1 skips the length byte
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
            WRITE_PT:
                begin                              // pad is now in s_rddata and CT[k+1] in ct_rddata: write PT[k+1] = pad xor CT[k+1]
                    s_addr    = si + sj;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = k + 8'd1;
                    pt_addr   = k + 8'd1;          // +1 skips the length byte
                    pt_wrdata = s_rddata ^ ct_rddata;
                    pt_wren   = 1'b1;
                end
            default:
                begin                              // unused encodings: do nothing
                    s_addr    = 8'd0;
                    s_wrdata  = 8'd0;
                    s_wren    = 1'b0;
                    ct_addr   = 8'd0;
                    pt_addr   = 8'd0;
                    pt_wrdata = 8'd0;
                    pt_wren   = 1'b0;
                end
        endcase
    end
 
    assign rdy = (state == IDLE);

endmodule: prga
