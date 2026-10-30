`timescale 1ps / 1ps

module tb_syn_task4();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    integer cycles, errors;

    localparam logic [6:0] DIGIT_0 = 7'b1000000;
    localparam logic [6:0] DIGIT_1 = 7'b1111001;
    localparam logic [6:0] BLANK   = 7'b1111111;

    // Compile task4.vo, initialized with Sentence 1, instead of task4.sv.
    task4 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        errors = 0;
        KEY = 2'b01;
        SW = 10'd0;
        repeat (2) @(negedge CLOCK_50);

        if ({HEX5, HEX4, HEX3, HEX2, HEX1, HEX0} !== {6{BLANK}}) begin
            $display("ERROR: displays were not blank before cracking");
            errors = errors + 1;
        end
        KEY[1] = 1'b1;

        // The netlist has no portable internal rdy name, so wait for the display.
        cycles = 0;
        while (HEX0 == BLANK && cycles < 8000) begin
            @(negedge CLOCK_50);
            cycles = cycles + 1;
        end
        if (cycles == 8000) begin
            $display("ERROR: synthesized task4 timed out");
            errors = errors + 1;
        end
        if (HEX5 !== DIGIT_0 || HEX4 !== DIGIT_0 || HEX3 !== DIGIT_0 || HEX2 !== DIGIT_0 || HEX1 !== DIGIT_0 || HEX0 !== DIGIT_1) begin
            $display("ERROR: displays did not show key 000001");
            errors = errors + 1;
        end

        // Add the synthesized PT hierarchy after task4.vo is generated if the
        // TA requires this testbench to inspect PT as well as the displayed key.
        if (errors == 0) $display("PASS: tb_syn_task4 (display check)");
        else $display("FAIL: tb_syn_task4 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_task4
