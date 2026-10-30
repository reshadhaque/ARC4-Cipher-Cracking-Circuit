`timescale 1ps / 1ps

module tb_syn_ksa();

    logic clk, rst_n, en, rdy, wren;
    logic [23:0] key;
    logic [7:0] addr, rddata, wrdata;
    logic [7:0] s_mem [0:255];
    logic [7:0] expected_mem [0:255];
    integer index, cycles, errors;

    // Compile ksa.vo, not ksa.sv, with this testbench.
    ksa dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(key),
            .addr(addr), .rddata(rddata), .wrdata(wrdata), .wren(wren));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        rddata <= s_mem[addr];
        if (wren) s_mem[addr] <= wrdata;
    end

    initial begin
        errors = 0;
        en = 1'b0;
        key = 24'h00033C;
        rddata = 8'd0;
        for (index = 0; index < 256; index = index + 1)
            s_mem[index] = index[7:0];
        $readmemh("ksa_expected.memh", expected_mem);

        // Reset and start the synthesized KSA.
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;

        cycles = 0;
        while (!rdy && cycles < 2000) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 2000) begin
            $display("ERROR: synthesized KSA timed out");
            errors = errors + 1;
        end

        // Check the complete handout result.
        for (index = 0; index < 256; index = index + 1) begin
            if (s_mem[index] !== expected_mem[index]) begin
                $display("ERROR: S[%0d] = %h, expected %h",
                         index, s_mem[index], expected_mem[index]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_syn_ksa");
        else $display("FAIL: tb_syn_ksa found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_ksa
