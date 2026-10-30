`timescale 1ps / 1ps

module tb_rtl_doublecrack();

    logic clk, rst_n, en, rdy, key_valid;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] ct_mem [0:255];
    string odd_text, even_text;
    integer index, cycles, errors;

    doublecrack dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy),
                    .key(key), .key_valid(key_valid),
                    .ct_addr(ct_addr), .ct_rddata(ct_rddata));

    initial clk = 1'b0;
    always #5 clk = ~clk;
    always_ff @(posedge clk)
        ct_rddata <= ct_mem[ct_addr];

    // Start doublecrack and wait for it to return to ready.
    task automatic run_search(input integer limit);
        begin
            en = 1'b1;
            @(negedge clk);
            en = 1'b0;
            cycles = 0;
            while (!rdy && cycles < limit) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (cycles == limit) begin
                $display("ERROR: doublecrack timed out");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        en = 1'b0;
        ct_rddata = 8'd0;
        odd_text = "In a hole in the ground there lived a hobbit.";
        even_text = "Mrs. Dalloway said she would buy the flowers herself.";
        for (index = 0; index < 256; index = index + 1)
            ct_mem[index] = 8'd0;

        // First test the odd core using Sentence 1, whose key is 1.
        $readmemh("sentence1.memh", ct_mem);
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        run_search(6000);
        if (key_valid !== 1'b1 || key !== 24'h000001) begin
            $display("ERROR: odd search returned key=%h valid=%b", key, key_valid);
            errors = errors + 1;
        end
        for (index = 0; index < odd_text.len(); index = index + 1) begin
            if (dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1] !== odd_text[index] || dut.c2.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1] !== odd_text[index]) begin
                $display("ERROR: odd winner/shared PT character %0d is incorrect", index);
                errors = errors + 1;
            end
        end

        // Reset, then test the even core using test2, whose key is 24.
        for (index = 0; index < 256; index = index + 1)
            ct_mem[index] = 8'd0;
        $readmemh("test2.memh", ct_mem);
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        run_search(50000);
        if (key_valid !== 1'b1 || key !== 24'h000018) begin
            $display("ERROR: even search returned key=%h valid=%b", key, key_valid);
            errors = errors + 1;
        end
        for (index = 0; index < even_text.len(); index = index + 1) begin
            if (dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1] !== even_text[index] || dut.c1.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[index + 1] !== even_text[index]) begin
                $display("ERROR: even winner/shared PT character %0d is incorrect", index);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("PASS: tb_rtl_doublecrack");
        else $display("FAIL: tb_rtl_doublecrack found %0d error(s)", errors);
        $finish;
    end

endmodule: tb_rtl_doublecrack
