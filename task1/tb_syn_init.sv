`timescale 1ps / 1ps

module tb_syn_init();

    logic clk, rst_n, en;
    logic rdy, wren;
    logic [7:0] addr, wrdata;
    integer expected, errors;

    // Compile init.vo, not init.sv, with this testbench.
    init dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy),
             .addr(addr), .wrdata(wrdata), .wren(wren));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        en = 1'b0;

        // Reset the synthesized module.
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        if (rdy !== 1'b1 || wren !== 1'b0) begin
            $display("ERROR: init should be ready and not writing after reset");
            errors = errors + 1;
        end

        // Send one request and check every write it produces.
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;
        if (rdy !== 1'b0) begin
            $display("ERROR: rdy should go low after accepting en");
            errors = errors + 1;
        end

        for (expected = 0; expected < 256; expected = expected + 1) begin
            if (wren !== 1'b1 || addr !== expected[7:0] || wrdata !== expected[7:0]) begin
                $display("ERROR: write %0d had wren=%b addr=%0d data=%0d", expected, wren, addr, wrdata);
                errors = errors + 1;
            end
            @(negedge clk);
        end

        if (rdy !== 1'b1 || wren !== 1'b0) begin
            $display("ERROR: init did not return to idle after 256 writes");
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS: tb_syn_init");
        else $display("FAIL: tb_syn_init found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_init
