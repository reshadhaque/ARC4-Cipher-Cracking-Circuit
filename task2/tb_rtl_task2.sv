`timescale 1ps / 1ps

module tb_rtl_task2();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    logic [7:0] expected_mem [0:255];
    integer index, cycles, errors;

    task2 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        errors = 0;
        KEY = 2'b11;
        SW = 10'h33C;
        $readmemh("ksa_expected.memh", expected_mem);

        // task2 automatically runs init followed by KSA after reset.
        KEY[1] = 1'b0;
        repeat (2) @(negedge CLOCK_50);
        KEY[1] = 1'b1;

        cycles = 0;
        while (dut.state != 3'd4 && cycles < 2500) begin
            @(negedge CLOCK_50);
            cycles = cycles + 1;
        end
        if (cycles == 2500) begin
            $display("ERROR: task2 timed out");
            errors = errors + 1;
        end

        // The final S memory must match the handout table for key 00033C.
        for (index = 0; index < 256; index = index + 1) begin
            if (dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[index]
                !== expected_mem[index]) begin
                $display("ERROR: S[%0d] = %h, expected %h", index,
                    dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[index],
                    expected_mem[index]);
                errors = errors + 1;
            end
        end

        // DONE must prevent any later writes to S.
        repeat (5) begin
            @(negedge CLOCK_50);
            if (dut.wren !== 1'b0) begin
                $display("ERROR: task2 wrote S after reaching DONE");
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_task2");
        else $display("FAIL: tb_rtl_task2 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_task2
