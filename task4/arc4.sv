`timescale 1ps / 1ps

module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // Signals going into the S memory (driven by the mux below)
    logic [7:0] s_addr, s_wrdata, s_rddata;
    logic       s_wren;

    // init's signals
    logic       init_en, init_rdy, init_wren;
    logic [7:0] init_addr, init_wrdata;

    // ksa's signals
    logic       ksa_en, ksa_rdy, ksa_wren;
    logic [7:0] ksa_addr, ksa_wrdata;

    // prga's signals (S side only: its CT and PT ports go straight to arc4's ports)
    logic       prga_en, prga_rdy, prga_wren;
    logic [7:0] prga_addr, prga_wrdata;

    // Controller states
    typedef enum logic [2:0] {IDLE, START_INIT, WAIT_INIT, START_KSA, WAIT_KSA, START_PRGA, WAIT_PRGA} state_type;

    state_type state, next_state;


    s_mem s(.address(s_addr), .clock(clk), .data(s_wrdata), .wren(s_wren), .q(s_rddata));

    init i(.clk(clk), .rst_n(rst_n),
           .en(init_en), .rdy(init_rdy),
           .addr(init_addr), .wrdata(init_wrdata), .wren(init_wren));

    ksa k(.clk(clk), .rst_n(rst_n),
          .en(ksa_en), .rdy(ksa_rdy),
          .key(key),
          .addr(ksa_addr), .rddata(s_rddata), .wrdata(ksa_wrdata), .wren(ksa_wren));

    prga p(.clk(clk), .rst_n(rst_n),
           .en(prga_en), .rdy(prga_rdy),
           .key(key),
           .s_addr(prga_addr), .s_rddata(s_rddata), .s_wrdata(prga_wrdata), .s_wren(prga_wren),
           .ct_addr(ct_addr), .ct_rddata(ct_rddata),
           .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));


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
            IDLE:       if (en)       next_state = START_INIT;  // a request has arrived
            START_INIT: if (init_rdy) next_state = WAIT_INIT;   // init_en goes out this cycle
            WAIT_INIT:  if (init_rdy) next_state = START_KSA;   // init finished
            START_KSA:  if (ksa_rdy)  next_state = WAIT_KSA;    // ksa_en goes out this cycle
            WAIT_KSA:   if (ksa_rdy)  next_state = START_PRGA;  // ksa finished
            START_PRGA: if (prga_rdy) next_state = WAIT_PRGA;   // prga_en goes out this cycle
            WAIT_PRGA:  if (prga_rdy) next_state = IDLE;        // prga finished: decryption done
            default:    next_state = IDLE;
        endcase
    end

    // Enables: one-cycle request, only while the module is ready
    assign init_en = (state == START_INIT) && init_rdy;
    assign ksa_en  = (state == START_KSA)  && ksa_rdy;
    assign prga_en = (state == START_PRGA) && prga_rdy;

    // arc4 is ready for a new request only when idle (depends only on state, never on en)
    assign rdy = (state == IDLE);

    // S memory mux: chooses which module drives the S memory in each state
    always_comb begin
        case (state)
            IDLE:
                begin                       // nothing running: no memory access
                    s_addr   = 8'd0;
                    s_wrdata = 8'd0;
                    s_wren   = 1'b0;
                end
            START_INIT:
                begin                       // init is about to start: init drives S
                    s_addr   = init_addr;
                    s_wrdata = init_wrdata;
                    s_wren   = init_wren;
                end
            WAIT_INIT:
                begin                       // init is filling S: init drives S
                    s_addr   = init_addr;
                    s_wrdata = init_wrdata;
                    s_wren   = init_wren;
                end
            START_KSA:
                begin                       // ksa is about to start: ksa drives S
                    s_addr   = ksa_addr;
                    s_wrdata = ksa_wrdata;
                    s_wren   = ksa_wren;
                end
            WAIT_KSA:
                begin                       // ksa is shuffling S: ksa drives S
                    s_addr   = ksa_addr;
                    s_wrdata = ksa_wrdata;
                    s_wren   = ksa_wren;
                end
            START_PRGA:
                begin                       // prga is about to start: prga drives S
                    s_addr   = prga_addr;
                    s_wrdata = prga_wrdata;
                    s_wren   = prga_wren;
                end
            WAIT_PRGA:
                begin                       // prga is decrypting: prga drives S
                    s_addr   = prga_addr;
                    s_wrdata = prga_wrdata;
                    s_wren   = prga_wren;
                end
            default:
                begin                       // unused encodings: no memory access
                    s_addr   = 8'd0;
                    s_wrdata = 8'd0;
                    s_wren   = 1'b0;
                end
        endcase
    end

endmodule: arc4
