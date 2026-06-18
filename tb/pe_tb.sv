// pe_tb.sv
// Unit testbench for processing element (pe)
// First milestone: complete PE implementation and pass this testbench.

`timescale 1ns / 1ps

module pe_tb;

    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH  = 32;

    logic clk;
    logic rst;
    logic clear;
    logic signed [DATA_WIDTH-1:0] a_in;
    logic signed [DATA_WIDTH-1:0] b_in;
    logic signed [DATA_WIDTH-1:0] a_out;
    logic signed [DATA_WIDTH-1:0] b_out;
    logic signed [ACC_WIDTH-1:0]  acc_out;

    int errors;

    // DUT
    pe #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .clear   (clear),
        .a_in    (a_in),
        .b_in    (b_in),
        .a_out   (a_out),
        .b_out   (b_out),
        .acc_out (acc_out)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst   = 1;
        clear = 0;
        a_in  = 0;
        b_in  = 0;

        // Reset pulse
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        // TODO: Test multiply-accumulate sequence:
        //   Cycle 1: a_in=2,  b_in=3  -> partial sum += 6
        //   Cycle 2: a_in=4,  b_in=5  -> partial sum += 20  (total 26)
        //   Cycle 3: a_in=1,  b_in=7  -> partial sum += 7   (total 33)
        //   Expected acc_out = 33 after three MAC cycles.
        errors = 0;

        // --- MAC cycle 1: 2 * 3 = 6 ---
        @(negedge clk);
        a_in = 2;  b_in = 3;
        @(posedge clk);
        #1step;  // sample after NBA — same as FIFO mon_cb input #1step
        $display("cycle 1: acc_out = %0d (expect 6)", acc_out);
        if (acc_out !== 32'd6) begin
            $error("MAC cycle 1: acc_out=%0d, expected 6", acc_out);
            errors++;
        end
        if (a_out !== 16'sd2) begin
            $error("MAC cycle 1: a_out=%0d, expected 2 (forward a_in)", a_out);
            errors++;
        end
        if (b_out !== 16'sd3) begin
            $error("MAC cycle 1: b_out=%0d, expected 3 (forward b_in)", b_out);
            errors++;
        end

        // --- MAC cycle 2: + 4 * 5 = 20 → 26 ---
        @(negedge clk);
        a_in = 4;  b_in = 5;
        @(posedge clk);
        #1step;
        $display("cycle 2: acc_out = %0d (expect 26)", acc_out);
        if (acc_out !== 32'd26) begin
            $error("MAC cycle 2: acc_out=%0d, expected 26", acc_out);
            errors++;
        end
        if (a_out !== 16'sd4) begin
            $error("MAC cycle 2: a_out=%0d, expected 4 (forward a_in)", a_out);
            errors++;
        end
        if (b_out !== 16'sd5) begin
            $error("MAC cycle 2: b_out=%0d, expected 5 (forward b_in)", b_out);
            errors++;
        end

        // --- MAC cycle 3: + 1 * 7 = 7 → 33 ---
        @(negedge clk);
        a_in = 1;  b_in = 7;
        @(posedge clk);
        #1step;
        $display("cycle 3: acc_out = %0d (expect 33)", acc_out);
        if (acc_out !== 32'd33) begin
            $error("MAC cycle 3: acc_out=%0d, expected 33", acc_out);
            errors++;
        end
        if (a_out !== 16'sd1) begin
            $error("MAC cycle 3: a_out=%0d, expected 1 (forward a_in)", a_out);
            errors++;
        end
        if (b_out !== 16'sd7) begin
            $error("MAC cycle 3: b_out=%0d, expected 7 (forward b_in)", b_out);
            errors++;
        end
        //
        // TODO: Verify a_out forwards a_in and b_out forwards b_in each cycle.
        // TODO: Verify clear resets acc_out to zero.
        @(negedge clk);
        clear = 1;
        a_in  = 0;
        b_in  = 0;
        @(posedge clk);
        #1step;
        if (acc_out !== 32'd0) begin
            $error("clear: acc_out=%0d, expected 0", acc_out);
            errors++;
        end
        clear = 0;
        @(posedge clk);

        // TODO: Use $display or assertions to check results.
        #100;
        $display("pe_tb: TODO — implement MAC test (expected acc_out = 33)");
        if (errors == 0)
            $display("pe_tb: ALL TESTS PASSED");
        else
            $display("pe_tb: FAILED with %0d error(s)", errors);
        $finish;
    end

endmodule
