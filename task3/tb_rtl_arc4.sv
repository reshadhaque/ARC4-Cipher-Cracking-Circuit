`timescale 1ps / 1ps

module tb_rtl_arc4();

    logic clk, rst_n, en, rdy;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic pt_wren;
    logic [7:0] ct_mem [0:255];
    logic [7:0] pt_mem [0:255];
    string expected_text;
    integer index, cycles, errors;

    arc4 dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(key),
             .ct_addr(ct_addr), .ct_rddata(ct_rddata),
             .pt_addr(pt_addr), .pt_rddata(pt_rddata),
             .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // CT and PT are external to arc4, so the testbench models them here.
    always_ff @(posedge clk) begin
        ct_rddata <= ct_mem[ct_addr];
        pt_rddata <= pt_mem[pt_addr];
        if (pt_wren) pt_mem[pt_addr] <= pt_wrdata;
    end

    initial begin
        errors = 0;
        en = 1'b0;
        key = 24'h1E4600;
        ct_rddata = 8'd0;
        pt_rddata = 8'd0;
        expected_text = "It was a bright cold day in April, and the clocks were striking thirteen.";
        for (index = 0; index < 256; index = index + 1) begin
            ct_mem[index] = 8'd0;
            pt_mem[index] = 8'hXX;
        end
        $readmemh("test1.memh", ct_mem);

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // Start one full init -> KSA -> PRGA operation.
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;
        cycles = 0;
        while (!rdy && cycles < 4000) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 4000) begin
            $display("ERROR: ARC4 timed out");
            errors = errors + 1;
        end

        // test1 and its expected English sentence are supplied by the handout.
        if (pt_mem[0] !== expected_text.len()) begin
            $display("ERROR: PT length was %0d, expected %0d", pt_mem[0], expected_text.len());
            errors = errors + 1;
        end
        for (index = 0; index < expected_text.len(); index = index + 1) begin
            if (pt_mem[index + 1] !== expected_text[index]) begin
                $display("ERROR: PT character %0d was %h, expected %h",index, pt_mem[index + 1], expected_text[index]);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_arc4");
        else $display("FAIL: tb_rtl_arc4 found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_arc4
