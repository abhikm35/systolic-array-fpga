// uart_tx_tb.sv
// Drives uart_tx with data/valid and decodes serial output on tx.

`timescale 1ns / 1ps

module uart_tx_tb;

    localparam int CLK_FREQ  = 100_000_000;
    localparam int BAUD_RATE = 115200;
    localparam int BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    logic       clk, rst;
    logic [7:0] data;
    logic       valid;
    logic       tx;
    logic       busy;

    int errors;

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .data  (data),
        .valid (valid),
        .tx    (tx),
        .busy  (busy)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic send_byte(input logic [7:0] byte_val);
        @(posedge clk);
        data  = byte_val;
        valid = 1'b1;
        @(posedge clk);
        #1step;
        valid = 1'b0;

        while (busy)
            @(posedge clk);
    endtask

    task automatic recv_byte(output logic [7:0] byte_val, input string tag);
        int i;
        int timeout;

        timeout = BIT_PERIOD * 20;
        while (tx === 1'b1 && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0) begin
            $error("%s: timeout waiting for start bit", tag);
            errors++;
            return;
        end

        // Wait 1.5 bit times from start detection to center of D0
        // (half bit to center of start, then one full bit past start).
        repeat (BIT_PERIOD + BIT_PERIOD / 2) @(posedge clk);

        for (i = 0; i < 8; i++) begin
            byte_val[i] = tx;
            repeat (BIT_PERIOD) @(posedge clk);
        end

        // After the loop we are at the center of the stop bit.
        if (tx !== 1'b1) begin
            $error("%s: bad stop bit (tx=%0b)", tag, tx);
            errors++;
        end
        repeat (BIT_PERIOD / 2) @(posedge clk);
    endtask

    task automatic check_byte(input logic [7:0] exp, input string tag);
        logic [7:0] got;
        recv_byte(got, tag);
        if (got !== exp) begin
            $error("%s: got 8'h%02x, expected 8'h%02x", tag, got, exp);
            errors++;
        end else begin
            $display("%s: PASS (8'h%02x)", tag, got);
        end
    endtask

    initial begin
        rst    = 1'b1;
        valid  = 1'b0;
        data   = 8'h00;
        errors = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        fork
            begin
                send_byte(8'h55);
                send_byte(8'hA3);
                send_byte(8'h00);
                send_byte(8'hFF);
            end
            begin
                check_byte(8'h55, "0x55");
                check_byte(8'hA3, "0xA3");
                check_byte(8'h00, "0x00");
                check_byte(8'hFF, "0xFF");
            end
        join

        repeat (BIT_PERIOD) @(posedge clk);

        if (errors == 0)
            $display("uart_tx_tb: ALL TESTS PASSED");
        else
            $display("uart_tx_tb: FAILED with %0d error(s)", errors);
        $finish;
    end

endmodule
