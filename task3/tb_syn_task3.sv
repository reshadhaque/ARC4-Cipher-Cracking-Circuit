`timescale 1ps / 1ps

module tb_syn_task3();

    logic CLOCK_50;
    logic [1:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    string expected_text;
    integer index, errors;

    // Compile task3.vo with test2.mif embedded in its CT memory.
    task3 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    // Rebuild each plaintext byte from the one-bit RAM blocks in task3.vo.
    function automatic logic [7:0] read_pt(input integer ram_address);
        begin
            read_pt[0] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[ram_address];
            read_pt[1] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a1 .ram_core0.ram_core0.mem[ram_address];
            read_pt[2] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a2 .ram_core0.ram_core0.mem[ram_address];
            read_pt[3] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a3 .ram_core0.ram_core0.mem[ram_address];
            read_pt[4] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a4 .ram_core0.ram_core0.mem[ram_address];
            read_pt[5] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a5 .ram_core0.ram_core0.mem[ram_address];
            read_pt[6] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a6 .ram_core0.ram_core0.mem[ram_address];
            read_pt[7] = dut.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a7 .ram_core0.ram_core0.mem[ram_address];
        end
    endfunction

    initial begin
        errors = 0;
        KEY = 2'b01;
        SW = 10'h018;
        expected_text = "Mrs. Dalloway said she would buy the flowers herself.";

        // Reset task3, then allow enough time for the one ARC4 request.
        repeat (2) @(negedge CLOCK_50);
        KEY[1] = 1'b1;
        repeat (4000) @(negedge CLOCK_50);

        if (read_pt(0) !== expected_text.len()) begin
            $display("ERROR: PT length was %0d, expected %0d", read_pt(0), expected_text.len());
            errors = errors + 1;
        end
        for (index = 0; index < expected_text.len(); index = index + 1) begin
            if (read_pt(index + 1) !== expected_text[index]) begin
                $display("ERROR: PT character %0d was %h, expected %h", index, read_pt(index + 1), expected_text[index]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_syn_task3");
        else $display("FAIL: tb_syn_task3 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_task3
