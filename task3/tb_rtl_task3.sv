`timescale 1ps / 1ps

module tb_rtl_task3();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    string expected_text;
    integer index, cycles, errors;

    task3 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        errors = 0;
        KEY = 2'b01;                 // keep KEY[1] low during memory setup
        SW = 10'h018;
        expected_text = "Mrs. Dalloway said she would buy the flowers herself.";

        // Wait for the generated memory's own initial block, then load test2.
        #20;
        $readmemh("test2.memh",
            dut.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);
        repeat (2) @(negedge CLOCK_50);
        KEY[1] = 1'b1;

        // task3 starts arc4 once automatically after reset.
        cycles = 0;
        while (!(dut.started && dut.rdy) && cycles < 4000) begin
            @(negedge CLOCK_50);
            cycles = cycles + 1;
        end
        if (cycles == 4000) begin
            $display("ERROR: task3 timed out");
            errors = errors + 1;
        end

        if (dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[0]
            !== expected_text.len()) begin
            $display("ERROR: task3 wrote the wrong PT length");
            errors = errors + 1;
        end
        for (index = 0; index < expected_text.len(); index = index + 1) begin
            if (dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1]
                !== expected_text[index]) begin
                $display("ERROR: PT character %0d was %h, expected %h", index,
                    dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1],
                    expected_text[index]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_task3");
        else $display("FAIL: tb_rtl_task3 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_task3
