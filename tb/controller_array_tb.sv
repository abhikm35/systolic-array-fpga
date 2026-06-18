// controller_array_tb.sv
// M3 integration — BRAM + systolic_controller + systolic_array_4x4
// TB loads A/B into BRAM, pulses start, controller runs full sequence, checks c_out.

`timescale 1ns / 1ps

module controller_array_tb;

    localparam int N          = 4;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH  = 32;
    localparam int ADDR_WIDTH = 4;

    logic clk, rst;
    logic start, done, busy, array_clear;

    logic tb_a_we, tb_b_we;
    logic ctrl_c_we;
    logic [ADDR_WIDTH-1:0] tb_a_addr, tb_b_addr, ctrl_a_addr, ctrl_b_addr, ctrl_c_addr;
    logic signed [DATA_WIDTH-1:0] tb_a_din, tb_b_din;
    logic signed [ACC_WIDTH-1:0]  ctrl_c_din;
    logic signed [DATA_WIDTH-1:0] a_dout, b_dout;
    logic signed [ACC_WIDTH-1:0]  c_dout;

    logic a_we, b_we, c_we;
    logic [ADDR_WIDTH-1:0] a_addr, b_addr, c_addr;
    logic signed [DATA_WIDTH-1:0] a_din, b_din;
    logic signed [ACC_WIDTH-1:0]  c_din;

    logic signed [DATA_WIDTH-1:0] a_left [N];
    logic signed [DATA_WIDTH-1:0] b_top  [N];
    logic signed [ACC_WIDTH-1:0]  c_out  [N][N];

    logic signed [DATA_WIDTH-1:0] a_exp [N][N];
    logic signed [DATA_WIDTH-1:0] b_exp [N][N];
    logic signed [ACC_WIDTH-1:0]  c_exp [N][N];

    int errors;

    assign a_we   = tb_a_we;
    assign b_we   = tb_b_we;
    assign c_we   = ctrl_c_we;
    assign a_addr = busy ? ctrl_a_addr : tb_a_addr;
    assign b_addr = busy ? ctrl_b_addr : tb_b_addr;
    assign c_addr = ctrl_c_addr;
    assign a_din  = tb_a_din;
    assign b_din  = tb_b_din;
    assign c_din  = ctrl_c_din;

    initial clk = 0;
    always #5 clk = ~clk;

    matrix_memories #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) u_mem (
        .clk    (clk),
        .a_we   (a_we),
        .a_addr (a_addr),
        .a_din  (a_din),
        .a_dout (a_dout),
        .b_we   (b_we),
        .b_addr (b_addr),
        .b_din  (b_din),
        .b_dout (b_dout),
        .c_we   (c_we),
        .c_addr (c_addr),
        .c_din  (c_din),
        .c_dout (c_dout)
    );

    systolic_controller #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_ctrl (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .done        (done),
        .busy        (busy),
        .array_clear (array_clear),
        .a_addr      (ctrl_a_addr),
        .a_dout      (a_dout),
        .b_addr      (ctrl_b_addr),
        .b_dout      (b_dout),
        .c_we        (ctrl_c_we),
        .c_addr      (ctrl_c_addr),
        .c_din       (ctrl_c_din),
        .c_out       (c_out),
        .a_left      (a_left),
        .b_top       (b_top)
    );

    systolic_array_4x4 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .N          (N)
    ) u_array (
        .clk     (clk),
        .rst     (rst),
        .clear   (array_clear),
        .a_left  (a_left),
        .b_top   (b_top),
        .c_out   (c_out)
    );

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

    task automatic bram_write_a(input int row, input int col, input logic signed [DATA_WIDTH-1:0] data);
        @(negedge clk);
        tb_a_we   = 1'b1;
        tb_a_addr = ADDR_WIDTH'(row_major_addr(row, col));
        tb_a_din  = data;
        @(posedge clk);
        #1step;
        tb_a_we   = 1'b0;
    endtask

    task automatic bram_write_b(input int row, input int col, input logic signed [DATA_WIDTH-1:0] data);
        @(negedge clk);
        tb_b_we   = 1'b1;
        tb_b_addr = ADDR_WIDTH'(row_major_addr(row, col));
        tb_b_din  = data;
        @(posedge clk);
        #1step;
        tb_b_we   = 1'b0;
    endtask

    task automatic write_matrices_to_bram();
        int i, j;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                bram_write_a(i, j, a_exp[i][j]);
                bram_write_b(i, j, b_exp[i][j]);
            end
    endtask

    task automatic pulse_start_and_wait();
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        #1step;
        start = 1'b0;
        while (!done)
            @(posedge clk);
        @(posedge clk);
        #1step;
    endtask

    function automatic int check_c_out(input string test_name);
        int i, j, local_errors;
        local_errors = 0;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++)
                if (c_out[i][j] !== c_exp[i][j]) begin
                    $error("%s: c_out[%0d][%0d]=%0d, expected %0d",
                           test_name, i, j, c_out[i][j], c_exp[i][j]);
                    local_errors++;
                end
        if (local_errors == 0)
            $display("%s: c_out PASS", test_name);
        return local_errors;
    endfunction

    task automatic run_one_test(input string test_name);
        write_matrices_to_bram();
        compute_expected();
        pulse_start_and_wait();
        errors += check_c_out(test_name);
    endtask

    initial begin
        rst       = 1;
        start     = 0;
        tb_a_we   = 0;
        tb_b_we   = 0;
        errors    = 0;

        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        load_identity();
        run_one_test("identity IxI");

        load_small_test();
        run_one_test("small 4x4");

        if (errors == 0)
            $display("controller_array_tb: ALL TESTS PASSED");
        else
            $display("controller_array_tb: FAILED with %0d error(s)", errors);
        $finish;
    end

endmodule
