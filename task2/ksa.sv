`timescale 1ps / 1ps

module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

    typedef enum logic [2:0] {IDLE, READ_SI, CALC_J, READ_SJ, WRITE_SI, WRITE_SJ} state_type;

    state_type state, next_state;

    logic [7:0] i, j;       //Loop index and running index
    logic [7:0] si;         //Saved copy of s[i]
    logic [1:0] imod3;      // i mod 3: can only be 0,1,2
    logic [7:0] key_byte;   // key[i mod 3]

    // key[0] is the MSB (Big Endian)
    always_comb begin
        case (imod3)
            2'd0:    key_byte = key[23:16];
            2'd1:    key_byte = key[15:8];
            default: key_byte = key[7:0];
        endcase
    end

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
            IDLE: if (en) next_state = READ_SI;
            READ_SI:  next_state = CALC_J;
            CALC_J:   next_state = READ_SJ;
            READ_SJ:  next_state = WRITE_SI;
            WRITE_SI: next_state = WRITE_SJ;
            WRITE_SJ: 
                begin
                if (i == 8'd255) 
                    next_state = IDLE;
                else
                    next_state = READ_SI;
                end
            default:next_state = IDLE;
        endcase
    end

     // Datapath registers: i, j, si, imod3
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
             begin
                i     <= 8'd0;
                j     <= 8'd0;
                si    <= 8'd0;
                imod3 <= 2'd0;
            end 
            
        else 
            begin
            case (state)
                IDLE:
                    begin
                        if (en)
                            begin               // start a new run
                                i     <= 8'd0;
                                j     <= 8'd0;
                                si    <= si;
                                imod3 <= 2'd0;
                            end
                        else
                            begin               // no request: hold
                                i     <= i;
                                j     <= j;
                                si    <= si;
                                imod3 <= imod3;
                            end
                    end
                READ_SI:
                    begin                       // waiting for s[i] to arrive: hold.
                        i     <= i;
                        j     <= j;
                        si    <= si;
                        imod3 <= imod3;
                    end
                CALC_J:
                    begin
                        i     <= i;
                        j     <= j + rddata + key_byte;   // j = (j + s[i] + key[i mod 3]) 
                        si    <= rddata;                  // rddata = s[i] in this clock cycle, so si saves it for later use
                        imod3 <= imod3;                   //The calcualtion of j, and the latching of si (temp) from rddata happens in the same cycle
                    end
                READ_SJ:
                    begin                       // waiting for s[j] to arrive: hold all the values
                        i     <= i;
                        j     <= j;
                        si    <= si;
                        imod3 <= imod3;
                    end
                WRITE_SI:
                    begin                       // writing s[i] = s[j]: hold all the values
                        i     <= i;
                        j     <= j;
                        si    <= si;
                        imod3 <= imod3;
                    end
                WRITE_SJ:
                    begin                       // iteration done: next i
                        i     <= i + 8'd1;
                        j     <= j;             // j carries over to the next iteration
                        si    <= si;
                        imod3 <= (imod3 == 2'd2) ? 2'd0 : imod3 + 2'd1;
                    end
                default:
                    begin                       // unused encodings: hold
                        i     <= i;
                        j     <= j;
                        si    <= si;
                        imod3 <= imod3;
                    end
            endcase
        end
    end

    // Output Logic
    always_comb begin
        case (state)
            IDLE:
                begin                              // Idle state
                    addr   = 8'd0;
                    wrdata = 8'd0;
                    wren   = 1'b0;
                end
            READ_SI:
                begin                              // Request s[i] state
                    addr   = i;
                    wrdata = 8'd0;
                    wren   = 1'b0;
                end
            CALC_J:
                begin                              // s[i] arrives on rddata, no memory access. Keep address the same. (at the next clock edge, si will be remembered)
                    addr   = i;
                    wrdata = 8'd0;
                    wren   = 1'b0;
                end
            READ_SJ:
                begin                              // request s[j] since j has been computed. 
                    addr   = j;
                    wrdata = 8'd0;
                    wren   = 1'b0;
                end
            WRITE_SI:                              //s[j] is now in rddata, so set addr to i, copy it to wrdata, and enable wren so the memory can write it
                begin                              // s[i] = s[j]
                    addr   = i;
                    wrdata = rddata;               
                    wren   = 1'b1;
                end
            WRITE_SJ:
                begin                              //set address to j, and set the s[j] = old s[i] (which we remembered before)
                    addr   = j;
                    wrdata = si;
                    wren   = 1'b1;
                end
            default:
                begin                              // unused encodings: do nothing
                    addr   = 8'd0;
                    wrdata = 8'd0;
                    wren   = 1'b0;
                end
        endcase
    end

    assign rdy = (state == IDLE);

endmodule: ksa