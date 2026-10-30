`timescale 1ps / 1ps

module tb_syn_task2();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    logic [7:0] expected_mem [0:255];
    integer address, errors;

    // Compile task2.vo, not task2.sv, with this testbench.
    task2 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    // Rebuild each S byte from the eight one-bit RAM blocks in task2.vo.
    function automatic logic [7:0] read_s(input integer ram_address);
        begin
            read_s[0] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[ram_address];
            read_s[1] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a1 .ram_core0.ram_core0.mem[ram_address];
            read_s[2] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a2 .ram_core0.ram_core0.mem[ram_address];
            read_s[3] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a3 .ram_core0.ram_core0.mem[ram_address];
            read_s[4] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a4 .ram_core0.ram_core0.mem[ram_address];
            read_s[5] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a5 .ram_core0.ram_core0.mem[ram_address];
            read_s[6] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a6 .ram_core0.ram_core0.mem[ram_address];
            read_s[7] = dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a7 .ram_core0.ram_core0.mem[ram_address];
        end
    endfunction

    initial begin
        errors = 0;
        KEY = 2'b01;
        SW = 10'h33C;
        $readmemh("ksa_expected.memh", expected_mem);

        // Reset task2, then allow enough time for init followed by KSA.
        repeat (2) @(negedge CLOCK_50);
        KEY[1] = 1'b1;
        repeat (2500) @(negedge CLOCK_50);

        // Check all 256 entries against the table supplied in the handout.
        for (address = 0; address < 256; address = address + 1) begin
            if (read_s(address) !== expected_mem[address]) begin
                $display("ERROR: S[%0d] = %h, expected %h",
                         address, read_s(address), expected_mem[address]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_syn_task2");
        else $display("FAIL: tb_syn_task2 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_task2
