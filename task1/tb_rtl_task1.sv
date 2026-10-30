`timescale 1ps / 1ps

module tb_rtl_task1();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    integer address, cycles, errors;

    task1 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        errors = 0;
        KEY = 2'b11;
        SW = 10'd0;

        // Reset task1. It should automatically start init exactly once.
        KEY[1] = 1'b0;
        repeat (2) @(negedge CLOCK_50);
        KEY[1] = 1'b1;

        // Wait until the one request has finished, with a simple timeout.
        cycles = 0;
        while (!(dut.started && dut.rdy) && cycles < 400) begin
            @(negedge CLOCK_50);
            cycles = cycles + 1;
        end
        if (cycles == 400) begin
            $display("ERROR: task1 timed out");
            errors = errors + 1;
        end

        // Check every location in the generated S memory.
        for (address = 0; address < 256; address = address + 1) begin
            if (dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[address] !== address[7:0]) begin
                $display("ERROR: S[%0d] = %h, expected %h", address, dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[address], address[7:0]);
                errors = errors + 1;
            end
        end

        // S must not be written again until another reset.
        repeat (5) begin
            @(negedge CLOCK_50);
            if (dut.wren !== 1'b0) begin
                $display("ERROR: task1 wrote S again after init finished");
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_task1");
        else $display("FAIL: tb_rtl_task1 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_task1
