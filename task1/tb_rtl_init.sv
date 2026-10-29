`timescale 1ps / 1ps


module tb_rtl_init();

// Your testbench goes here.

    logic clk, rst_n, en;
    logic rdy, wren;
    logic [7:0] addr, wrdata;


 
    init dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy),
             .addr(addr), .wrdata(wrdata), .wren(wren));

             
    integer k, errors;


    // 10 ps clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;


     initial begin

        errors = 0;
        // reset
        en = 1'b0;
        rst_n = 1'b0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;


        // init should be ready and not writing
        @(negedge clk);
        if (rdy !== 1'b1 || wren !== 1'b0) begin
            $display("ERROR: after reset rdy=%b wren=%b (expected rdy=1 wren=0)", rdy, wren);
            errors = errors + 1;
        end


        // make one request (en high for exactly one cycle)
        en = 1'b1;
        @(negedge clk);
        en = 1'b0;

        // rdy must drop the cycle after en
        if (rdy !== 1'b0) begin
            $display("ERROR: rdy did not drop after en");
            errors = errors + 1;
        end


        // expect 256 writes: address k gets value k
        for (k = 0; k < 256; k = k + 1) begin
            if (wren !== 1'b1 || addr !== k || wrdata !== k) begin
                $display("ERROR at write %0d: wren=%b addr=%0d wrdata=%0d", k, wren, addr, wrdata);
                errors = errors + 1;
            end
            @(negedge clk);
        end

        // finished: ready again, no more writes
        if (rdy !== 1'b1 || wren !== 1'b0) begin
            $display("ERROR: after 256 writes rdy=%b wren=%b (expected rdy=1 wren=0)", rdy, wren);
            errors = errors + 1;
        end

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED with %0d error(s)", errors);
        $stop;


    end
     

endmodule: tb_rtl_init
