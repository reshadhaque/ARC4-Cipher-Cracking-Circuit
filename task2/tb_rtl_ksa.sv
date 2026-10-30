`timescale 1ps / 1ps

module tb_rtl_ksa();

    logic clk, rst_n, en, rdy, wren;
    logic [23:0] key;
    logic [7:0] addr, rddata, wrdata;
    logic [7:0] s_mem [0:255];
    logic [7:0] expected_mem [0:255];
    integer index, cycles, errors;

    ksa dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(key),
            .addr(addr), .rddata(rddata), .wrdata(wrdata), .wren(wren));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // This small memory model has the same one-clock read delay as the FPGA RAM.
    always_ff @(posedge clk) begin
        rddata <= s_mem[addr];
        if (wren) s_mem[addr] <= wrdata;
    end

    initial begin
        errors = 0;
        en = 1'b0;
        key = 24'h00033C;
        rddata = 8'd0;

        // KSA begins with the identity permutation created by init.
        for (index = 0; index < 256; index = index + 1)
            s_mem[index] = index[7:0];
        $readmemh("ksa_expected.memh", expected_mem);

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // Start KSA with the key used by the handout's expected table.
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;
        if (rdy !== 1'b0) begin
            $display("ERROR: KSA did not become busy");
            errors = errors + 1;
        end

        // Wait for KSA to finish, but stop if it takes unexpectedly long.
        cycles = 0;
        while (!rdy && cycles < 2000) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 2000) begin
            $display("ERROR: KSA timed out");
            errors = errors + 1;
        end

        // Compare all 256 bytes with the exact table in the lab manual.
        for (index = 0; index < 256; index = index + 1) begin
            if (s_mem[index] !== expected_mem[index]) begin
                $display("ERROR: S[%0d] = %h, expected %h",
                         index, s_mem[index], expected_mem[index]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_ksa");
        else $display("FAIL: tb_rtl_ksa found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_ksa
