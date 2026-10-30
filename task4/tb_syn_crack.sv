`timescale 1ps / 1ps

module tb_syn_crack();

    logic clk, rst_n, en, rdy, key_valid;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] ct_mem [0:255];
    integer index, cycles, errors;

    // Compile crack.vo, not crack.sv, with this testbench.
    crack dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy),
              .key(key), .key_valid(key_valid),
              .ct_addr(ct_addr), .ct_rddata(ct_rddata));

    initial clk = 1'b0;
    always #5 clk = ~clk;
    always_ff @(posedge clk)
        ct_rddata <= ct_mem[ct_addr];

    initial begin
        errors = 0;
        en = 1'b0;
        ct_rddata = 8'd0;
        for (index = 0; index < 256; index = index + 1)
            ct_mem[index] = 8'd0;
        $readmemh("sentence1.memh", ct_mem);

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;

        cycles = 0;
        while (!rdy && cycles < 8000) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 8000) begin
            $display("ERROR: synthesized crack timed out");
            errors = errors + 1;
        end
        if (key_valid !== 1'b1 || key !== 24'h000001) begin
            $display("ERROR: crack returned key=%h valid=%b, expected 000001/1",
                     key, key_valid);
            errors = errors + 1;
        end

        // The key check is portable. The synthesized PT path must be added
        // after crack.vo is generated and its RAM name is visible in Memory List.
        if (errors == 0) $display("PASS: tb_syn_crack (key check)");
        else $display("FAIL: tb_syn_crack found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_crack
