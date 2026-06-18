// uart_rx_tb.sv
// Drives serial bytes on rx and checks uart_rx data/valid.

`timescale 1ns / 1ps

module uart_rx_tb;

    localparam int CLK_FREQ  = 100_000_000;
    localparam int BAUD_RATE = 115200;
    localparam int BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    logic clk, rst, rx;
    logic [7:0] data;
    logic       valid;

    int errors;

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .rx    (rx),
        .data  (data),
        .valid (valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic wait_valid(input logic [7:0] exp, input string tag);
        int timeout;
        timeout = BIT_PERIOD * 20;
        while (!valid && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (!valid) begin
            $error("%s: timeout waiting for valid", tag);
            errors++;
        end else if (data !== exp) begin
            $error("%s: got 8'h%02x, expected 8'h%02x", tag, data, exp);
            errors++;
        end else begin
            $display("%s: PASS (8'h%02x)", tag, data);
        end
        @(posedge clk);
    endtask

    task automatic send_byte(input logic [7:0] byte_val);
        int i;
        @(posedge clk);
        rx = 1'b0;
        repeat (BIT_PERIOD) @(posedge clk);
        for (i = 0; i < 8; i++) begin
            rx = byte_val[i];
            repeat (BIT_PERIOD) @(posedge clk);
        end
        rx = 1'b1;
        repeat (BIT_PERIOD) @(posedge clk);
    endtask

    initial begin
        rst    = 1'b1;
        rx     = 1'b1;
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
                wait_valid(8'h55, "0x55");
                wait_valid(8'hA3, "0xA3");
                wait_valid(8'h00, "0x00");
                wait_valid(8'hFF, "0xFF");
            end
        join

        repeat (BIT_PERIOD) @(posedge clk);

        if (errors == 0)
            $display("uart_rx_tb: ALL TESTS PASSED");
        else
            $display("uart_rx_tb: FAILED with %0d error(s)", errors);
        $finish;
    end

endmodule
