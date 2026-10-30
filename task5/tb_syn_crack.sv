`timescale 1ps / 1ps

module tb_syn_crack();

    logic clk, rst_n, en, rdy, key_valid, stop;
    logic [23:0] key, start_key;
    logic [7:0] ct_addr, ct_rddata, rd_pt_addr, rd_pt_rddata;
    logic [7:0] ct_mem [0:255];
    string expected_text;
    integer index, cycles, errors;

    // Compile crack.vo, not crack.sv, with this testbench.
    crack dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy),
              .key(key), .key_valid(key_valid),
              .ct_addr(ct_addr), .ct_rddata(ct_rddata),
              .start_key(start_key), .stop(stop),
              .rd_pt_addr(rd_pt_addr), .rd_pt_rddata(rd_pt_rddata));

    initial clk = 1'b0;
    always #5 clk = ~clk;
    always_ff @(posedge clk)
        ct_rddata <= ct_mem[ct_addr];

    initial begin
        errors = 0;
        en = 1'b0;
        stop = 1'b0;
        start_key = 24'd1;
        rd_pt_addr = 8'd0;
        ct_rddata = 8'd0;
        expected_text = "In a hole in the ground there lived a hobbit.";
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
        while (!rdy && cycles < 5000) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 5000) begin
            $display("ERROR: synthesized Task 5 crack timed out");
            errors = errors + 1;
        end
        if (key_valid !== 1'b1 || key !== 24'h000001) begin
            $display("ERROR: crack returned key=%h valid=%b, expected 000001/1",
                     key, key_valid);
            errors = errors + 1;
        end

        rd_pt_addr = 8'd0;
        @(posedge clk); @(negedge clk);
        if (rd_pt_rddata !== expected_text.len()) begin
            $display("ERROR: crack PT has the wrong length");
            errors = errors + 1;
        end
        for (index = 0; index < expected_text.len(); index = index + 1) begin
            rd_pt_addr = index + 1;
            @(posedge clk); @(negedge clk);
            if (rd_pt_rddata !== expected_text[index]) begin
                $display("ERROR: crack PT character %0d is incorrect", index);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_syn_crack");
        else $display("FAIL: tb_syn_crack found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_crack
