`timescale 1ps / 1ps

module tb_syn_prga();

    logic clk, rst_n, en, rdy;
    logic [7:0] s_addr, s_rddata, s_wrdata;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic s_wren, pt_wren;
    logic [7:0] s_mem [0:255];
    logic [7:0] ct_mem [0:255];
    logic [7:0] pt_mem [0:255];
    integer index, cycles, errors;

    // Compile prga.vo, not prga.sv, with this testbench.
    prga dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(24'd0),
             .s_addr(s_addr), .s_rddata(s_rddata), .s_wrdata(s_wrdata), .s_wren(s_wren),
             .ct_addr(ct_addr), .ct_rddata(ct_rddata),
             .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        s_rddata <= s_mem[s_addr];
        ct_rddata <= ct_mem[ct_addr];
        pt_rddata <= pt_mem[pt_addr];
        if (s_wren) s_mem[s_addr] <= s_wrdata;
        if (pt_wren) pt_mem[pt_addr] <= pt_wrdata;
    end

    initial begin
        errors = 0;
        en = 1'b0;
        s_rddata = 8'd0;
        ct_rddata = 8'd0;
        pt_rddata = 8'd0;
        for (index = 0; index < 256; index = index + 1) begin
            s_mem[index] = index[7:0];
            ct_mem[index] = 8'd0;
            pt_mem[index] = 8'hXX;
        end
        ct_mem[0] = 8'd2;
        ct_mem[1] = 8'h41;
        ct_mem[2] = 8'h42;

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;

        cycles = 0;
        while (!rdy && cycles < 50) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 50) begin
            $display("ERROR: synthesized PRGA timed out");
            errors = errors + 1;
        end

        if (pt_mem[0] !== 8'd2 || pt_mem[1] !== 8'h43 || pt_mem[2] !== 8'h47) begin
            $display("ERROR: PT was %h %h %h, expected 02 43 47",
                     pt_mem[0], pt_mem[1], pt_mem[2]);
            errors = errors + 1;
        end
        if (s_mem[2] !== 8'd3 || s_mem[3] !== 8'd2) begin
            $display("ERROR: PRGA did not perform the expected S[2]/S[3] swap");
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS: tb_syn_prga");
        else $display("FAIL: tb_syn_prga found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_syn_prga
