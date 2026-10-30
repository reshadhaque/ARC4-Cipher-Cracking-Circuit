`timescale 1ps / 1ps

module tb_rtl_task4();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    string expected_text;
    integer index, cycles, errors;

    localparam logic [6:0] DIGIT_0 = 7'b1000000;
    localparam logic [6:0] DIGIT_1 = 7'b1111001;
    localparam logic [6:0] BLANK   = 7'b1111111;

    task4 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        errors = 0;
        KEY = 2'b01;
        SW = 10'd0;
        expected_text = "In a hole in the ground there lived a hobbit.";

        // Load the handout's Sentence 1 after the generated CT initializes.
        #20;
        $readmemh("sentence1.memh", dut.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);
        repeat (2) @(negedge CLOCK_50);

        // Displays must be blank before and while cracking.
        if ({HEX5, HEX4, HEX3, HEX2, HEX1, HEX0} !== {6{BLANK}}) begin
            $display("ERROR: displays were not blank before cracking");
            errors = errors + 1;
        end
        KEY[1] = 1'b1;

        cycles = 0;
        while (!(dut.started && dut.rdy) && cycles < 8000) begin
            @(negedge CLOCK_50);
            cycles = cycles + 1;
        end
        if (cycles == 8000) begin
            $display("ERROR: task4 timed out");
            errors = errors + 1;
        end

        // Key 000001 must appear left-to-right on HEX5..HEX0.
        if (HEX5 !== DIGIT_0 || HEX4 !== DIGIT_0 || HEX3 !== DIGIT_0 || HEX2 !== DIGIT_0 || HEX1 !== DIGIT_0 || HEX0 !== DIGIT_1) begin
            $display("ERROR: displays did not show key 000001");
            errors = errors + 1;
        end

        // Also check the plaintext stored inside crack, as required by the lab.
        for (index = 0; index < expected_text.len(); index = index + 1) begin
            if (dut.c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1] !== expected_text[index]) begin
                $display("ERROR: task4 PT character %0d is incorrect", index);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_task4");
        else $display("FAIL: tb_rtl_task4 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_task4
