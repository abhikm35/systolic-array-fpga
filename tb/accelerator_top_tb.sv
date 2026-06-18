// accelerator_top_tb.sv
// System test — UART host protocol over full accelerator_top (M4).

`timescale 1ns / 1ps

module accelerator_top_tb;

    localparam int N          = 4;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH  = 32;
    localparam int CLK_FREQ   = 100_000_000;
    localparam int BAUD_RATE  = 115200;
    localparam int BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    localparam logic [7:0] CMD_A = 8'h41;
    localparam logic [7:0] CMD_B = 8'h42;
    localparam logic [7:0] CMD_S = 8'h53;
    localparam logic [7:0] CMD_C = 8'h43;
    localparam logic [7:0] RSP_D = 8'h44;

    logic        clk;
    logic        btnC;
    logic        uart_rx;
    logic        uart_tx;
    logic [15:0] led;

    logic signed [DATA_WIDTH-1:0] a_exp [N][N];
    logic signed [DATA_WIDTH-1:0] b_exp [N][N];
    logic signed [ACC_WIDTH-1:0]  c_exp [N][N];
    logic signed [ACC_WIDTH-1:0]  c_got [N][N];

    int errors;
    bit uart_debug;

    accelerator_top dut (
        .clk     (clk),
        .btnC    (btnC),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx),
        .led     (led)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // UART bit-bang BFM (TB acts as host PC)
    // -------------------------------------------------------------------------

    task automatic uart_send_byte(input logic [7:0] byte_val);
        int i;
        @(posedge clk);
        uart_rx = 1'b0;
        repeat (BIT_PERIOD) @(posedge clk);
        for (i = 0; i < 8; i++) begin
            uart_rx = byte_val[i];
            repeat (BIT_PERIOD) @(posedge clk);
        end
        uart_rx = 1'b1;
        repeat (BIT_PERIOD) @(posedge clk);
    endtask

    task automatic uart_recv_byte(output logic [7:0] byte_val, input string tag);
        int i;
        int timeout;

        timeout = BIT_PERIOD * 50;
        while (uart_tx === 1'b1 && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        if (timeout == 0) begin
            $error("%s: timeout waiting for UART TX start bit", tag);
            errors++;
            byte_val = 8'h00;
            return;
        end

        repeat (BIT_PERIOD + BIT_PERIOD / 2) @(posedge clk);

        for (i = 0; i < 8; i++) begin
            byte_val[i] = uart_tx;
            repeat (BIT_PERIOD) @(posedge clk);
        end

        if (uart_tx !== 1'b1) begin
            $error("%s: bad UART stop bit (tx=%0b)", tag, uart_tx);
            errors++;
        end
        repeat (BIT_PERIOD / 2) @(posedge clk);
    endtask

    // Read 4 UART bytes (one 32-bit LE word). Bytes are sent back-to-back by the
    // DUT, so do not call uart_recv_byte four times (too slow). After each byte,
    // resync on the next start bit the same way uart_recv_byte does.
    task automatic uart_recv_word(output logic signed [31:0] word_val, input string tag);
        logic [7:0] bytes[4];
        int i, b;
        int timeout;

        for (b = 0; b < 4; b++) begin
            if (b == 0) begin
                timeout = BIT_PERIOD * 50;
                while (uart_tx === 1'b1 && timeout > 0) begin
                    @(posedge clk);
                    timeout--;
                end
                if (timeout == 0) begin
                    $error("%s: timeout waiting for UART TX start bit", tag);
                    errors++;
                    word_val = '0;
                    return;
                end
            end else begin
                // Finish sampling the previous stop bit, then catch the next start.
                repeat (BIT_PERIOD / 2) @(posedge clk);
                timeout = BIT_PERIOD * 5;
                while (uart_tx === 1'b1 && timeout > 0) begin
                    @(posedge clk);
                    timeout--;
                end
                if (timeout == 0) begin
                    $error("%s: timeout waiting for UART TX start bit (byte %0d)", tag, b);
                    errors++;
                    word_val = '0;
                    return;
                end
            end

            repeat (BIT_PERIOD + BIT_PERIOD / 2) @(posedge clk);

            for (i = 0; i < 8; i++) begin
                bytes[b][i] = uart_tx;
                repeat (BIT_PERIOD) @(posedge clk);
            end

            if (uart_tx !== 1'b1) begin
                $error("%s: bad stop bit on byte %0d (tx=%0b)", tag, b, uart_tx);
                errors++;
            end
        end

        word_val = $signed({bytes[3], bytes[2], bytes[1], bytes[0]});
    endtask

    // -------------------------------------------------------------------------
    // Host protocol (matches host_uart_cmd.sv)
    // -------------------------------------------------------------------------

    task automatic host_load_a(input int addr, input logic signed [DATA_WIDTH-1:0] value);
        uart_send_byte(CMD_A);
        uart_send_byte(8'(addr));
        uart_send_byte(8'(value[7:0]));
        uart_send_byte(8'(value[15:8]));
    endtask

    task automatic host_load_b(input int addr, input logic signed [DATA_WIDTH-1:0] value);
        uart_send_byte(CMD_B);
        uart_send_byte(8'(addr));
        uart_send_byte(8'(value[7:0]));
        uart_send_byte(8'(value[15:8]));
    endtask

    task automatic host_start_and_wait_done();
        logic [7:0] rsp;
        uart_send_byte(CMD_S);
        uart_recv_byte(rsp, "wait_done");
        if (rsp !== RSP_D) begin
            $error("wait_done: expected 'D' (8'h44), got 8'h%02x", rsp);
            errors++;
        end else begin
            $display("compute done: received 'D'");
        end
    endtask

    task automatic host_read_c(input int addr, output logic signed [ACC_WIDTH-1:0] value);
        uart_send_byte(CMD_C);
        uart_send_byte(8'(addr));
        uart_recv_word(value, $sformatf("read_c addr %0d", addr));
    endtask

    // -------------------------------------------------------------------------
    // Golden model and test matrices (same as controller_array_tb)
    // -------------------------------------------------------------------------

    function automatic int row_major_addr(input int row, input int col);
        return row * N + col;
    endfunction

    function automatic void compute_expected();
        int i, j, k;
        longint acc;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                acc = 0;
                for (k = 0; k < N; k++)
                    acc += a_exp[i][k] * b_exp[k][j];
                c_exp[i][j] = ACC_WIDTH'(acc);
            end
    endfunction

    // Fast BRAM preload for +UART_DEBUG (skips slow UART matrix load in GUI runs).
    task automatic preload_bram_identity();
        int i, j, addr;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                addr = row_major_addr(i, j);
                dut.u_mem.u_bram_a.mem[addr] = (i == j) ? 16'sd1 : 16'sd0;
                dut.u_mem.u_bram_b.mem[addr] = (i == j) ? 16'sd1 : 16'sd0;
                a_exp[i][j] = dut.u_mem.u_bram_a.mem[addr];
                b_exp[i][j] = dut.u_mem.u_bram_b.mem[addr];
            end
    endtask

    task automatic run_uart_debug_stop_after_first_c_read();
        logic signed [ACC_WIDTH-1:0] value;
        preload_bram_identity();
        compute_expected();
        host_start_and_wait_done();
        host_read_c(0, value);
        c_got[0][0] = value;
        $display("UART_DEBUG: first C read c[0][0]=%0d (expected %0d)", value, c_exp[0][0]);
        $display("UART_DEBUG: simulation paused — zoom CMD_TX_BYTE / uart_tx handshake");
        $stop;
    endtask

    task automatic load_identity();
        int i, j;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                a_exp[i][j] = (i == j) ? 16'sd1 : 16'sd0;
                b_exp[i][j] = (i == j) ? 16'sd1 : 16'sd0;
            end
    endtask

    task automatic load_small_test();
        a_exp[0][0] = 1; a_exp[0][1] = 2; a_exp[0][2] = 0; a_exp[0][3] = 0;
        a_exp[1][0] = 3; a_exp[1][1] = 4; a_exp[1][2] = 0; a_exp[1][3] = 0;
        a_exp[2][0] = 0; a_exp[2][1] = 0; a_exp[2][2] = 1; a_exp[2][3] = 0;
        a_exp[3][0] = 0; a_exp[3][1] = 0; a_exp[3][2] = 0; a_exp[3][3] = 1;
        b_exp[0][0] = 5; b_exp[0][1] = 6; b_exp[0][2] = 0; b_exp[0][3] = 0;
        b_exp[1][0] = 7; b_exp[1][1] = 8; b_exp[1][2] = 0; b_exp[1][3] = 0;
        b_exp[2][0] = 0; b_exp[2][1] = 0; b_exp[2][2] = 1; b_exp[2][3] = 0;
        b_exp[3][0] = 0; b_exp[3][1] = 0; b_exp[3][2] = 0; b_exp[3][3] = 1;
    endtask

    task automatic uart_write_matrices();
        int i, j;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                host_load_a(row_major_addr(i, j), a_exp[i][j]);
                host_load_b(row_major_addr(i, j), b_exp[i][j]);
            end
    endtask

    task automatic uart_read_matrices_c();
        int i, j;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++)
                host_read_c(row_major_addr(i, j), c_got[i][j]);
    endtask

    function automatic int check_c_got(input string test_name);
        int i, j, local_errors;
        local_errors = 0;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++)
                if (c_got[i][j] !== c_exp[i][j]) begin
                    $error("%s: c[%0d][%0d]=%0d, expected %0d",
                           test_name, i, j, c_got[i][j], c_exp[i][j]);
                    local_errors++;
                end
        if (local_errors == 0)
            $display("%s: C matrix PASS", test_name);
        return local_errors;
    endfunction

    task automatic run_one_test(input string test_name);
        uart_write_matrices();
        compute_expected();
        host_start_and_wait_done();
        uart_read_matrices_c();
        errors += check_c_got(test_name);
    endtask

    // -------------------------------------------------------------------------
    // Main sequence
    // -------------------------------------------------------------------------

    initial begin
        btnC    = 1'b1;
        uart_rx = 1'b1;
        errors  = 0;
        uart_debug = $test$plusargs("UART_DEBUG");

        repeat (5) @(posedge clk);
        btnC = 1'b0;
        repeat (2) @(posedge clk);

        if (uart_debug) begin
            run_uart_debug_stop_after_first_c_read();
        end else begin
            load_identity();
            run_one_test("identity IxI");

            load_small_test();
            run_one_test("small 4x4");

            if (errors == 0)
                $display("accelerator_top_tb: ALL TESTS PASSED");
            else
                $display("accelerator_top_tb: FAILED with %0d error(s)", errors);
            $finish;
        end
    end

endmodule
