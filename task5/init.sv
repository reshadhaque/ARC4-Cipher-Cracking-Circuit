`timescale 1ps / 1ps



module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

// your code here

typedef enum logic {IDLE, WRITE} state_type;

state_type state, next_state;

logic [7:0] i;

    //State Register
    always_ff@(posedge clk, negedge rst_n) begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    //Counter Circuit
    always_ff@(posedge clk, negedge rst_n) begin
        if(!rst_n)
            i <= 8'd0;
        else
            begin
                case(state)
                    IDLE: if (en) i <= 8'd0; //Reset the value to 0 when enable is called
                    WRITE: i <= i + 8'd1; //increment by 1 in each write cycle
                endcase
            end
    end

    //Next State Logic

    always_comb begin
        case(state)
            IDLE:
                begin
                    if(rdy && en)
                        next_state = WRITE;
                    else
                        next_state = IDLE;
                end
            WRITE:
                begin
                    if(i < 255)
                        next_state = WRITE;
                    else
                        next_state = IDLE;
                end
            default: next_state = state;
        endcase

    end

    assign wren = (state == WRITE);
    assign rdy = (state == IDLE);
    assign addr   = i;
    assign wrdata = i;

endmodule: init