// matrix_bram_tb.sv
// M3 unit test — three-bank matrix_memories write/read with 1-cycle BRAM latency.

`timescale 1ns / 1ps

module matrix_bram_tb;

    localparam int N          = 4;
    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH  = 32;
    localparam int DEPTH      = 16;
    localparam int ADDR_WIDTH = 4;

    logic clk;
    logic a_we, b_we, c_we;
    logic [ADDR_WIDTH-1:0]       a_addr, b_addr, c_addr;
    logic signed [DATA_WIDTH-1:0] a_din, b_din;
    logic signed [DATA_WIDTH-1:0] a_dout, b_dout;
    logic signed [ACC_WIDTH-1:0]  c_din, c_dout;

    logic signed [DATA_WIDTH-1:0] a_exp [N][N];
    logic signed [DATA_WIDTH-1:0] b_exp [N][N];
    logic signed [ACC_WIDTH-1:0]  c_exp [N][N];

    int errors;

    matrix_memories #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
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

    initial clk = 0;
    always #5 clk = ~clk;

    function automatic int row_major_addr(input int row, input int col);
        return row * N + col;
    endfunction

    task automatic load_small_test_matrices();
        int i, j;
        a_exp[0][0] = 1; a_exp[0][1] = 2; a_exp[0][2] = 0; a_exp[0][3] = 0;
        a_exp[1][0] = 3; a_exp[1][1] = 4; a_exp[1][2] = 0; a_exp[1][3] = 0;
        a_exp[2][0] = 0; a_exp[2][1] = 0; a_exp[2][2] = 1; a_exp[2][3] = 0;
        a_exp[3][0] = 0; a_exp[3][1] = 0; a_exp[3][2] = 0; a_exp[3][3] = 1;
        b_exp[0][0] = 5; b_exp[0][1] = 6; b_exp[0][2] = 0; b_exp[0][3] = 0;
        b_exp[1][0] = 7; b_exp[1][1] = 8; b_exp[1][2] = 0; b_exp[1][3] = 0;
        b_exp[2][0] = 0; b_exp[2][1] = 0; b_exp[2][2] = 1; b_exp[2][3] = 0;
        b_exp[3][0] = 0; b_exp[3][1] = 0; b_exp[3][2] = 0; b_exp[3][3] = 1;
        c_exp[0][0] = 19; c_exp[0][1] = 22; c_exp[0][2] = 0; c_exp[0][3] = 0;
        c_exp[1][0] = 43; c_exp[1][1] = 50; c_exp[1][2] = 0; c_exp[1][3] = 0;
        c_exp[2][0] = 0;  c_exp[2][1] = 0;  c_exp[2][2] = 1; c_exp[2][3] = 0;
        c_exp[3][0] = 0;  c_exp[3][1] = 0;  c_exp[3][2] = 0; c_exp[3][3] = 1;
    endtask

    task automatic bram_write_a(input int row, input int col, input logic signed [DATA_WIDTH-1:0] data);
        @(negedge clk);
        a_we   = 1'b1;
        a_addr = ADDR_WIDTH'(row_major_addr(row, col));
        a_din  = data;
        @(posedge clk);
        #1step;
        a_we   = 1'b0;
    endtask

    task automatic bram_write_b(input int row, input int col, input logic signed [DATA_WIDTH-1:0] data);
        @(negedge clk);
        b_we   = 1'b1;
        b_addr = ADDR_WIDTH'(row_major_addr(row, col));
        b_din  = data;
        @(posedge clk);
        #1step;
        b_we   = 1'b0;
    endtask

    task automatic bram_write_c(input int row, input int col, input logic signed [ACC_WIDTH-1:0] data);
        @(negedge clk);
        c_we   = 1'b1;
        c_addr = ADDR_WIDTH'(row_major_addr(row, col));
        c_din  = data;
        @(posedge clk);
        #1step;
        c_we   = 1'b0;
    endtask

    task automatic bram_read_a(input int row, input int col,
                             output logic signed [DATA_WIDTH-1:0] data);
        @(negedge clk);
        a_we   = 1'b0;
        a_addr = ADDR_WIDTH'(row_major_addr(row, col));
        @(posedge clk);
        #1step;
        data = a_dout;
    endtask

    task automatic bram_read_b(input int row, input int col,
                             output logic signed [DATA_WIDTH-1:0] data);
        @(negedge clk);
        b_we   = 1'b0;
        b_addr = ADDR_WIDTH'(row_major_addr(row, col));
        @(posedge clk);
        #1step;
        data = b_dout;
    endtask

    task automatic bram_read_c(input int row, input int col,
                             output logic signed [ACC_WIDTH-1:0] data);
        @(negedge clk);
        c_we   = 1'b0;
        c_addr = ADDR_WIDTH'(row_major_addr(row, col));
        @(posedge clk);
        #1step;
        data = c_dout;
    endtask

    task automatic write_all_matrices();
        int i, j;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                bram_write_a(i, j, a_exp[i][j]);
                bram_write_b(i, j, b_exp[i][j]);
                bram_write_c(i, j, c_exp[i][j]);
            end
    endtask

    task automatic verify_bank_a();
        int i, j;
        logic signed [DATA_WIDTH-1:0] got;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                bram_read_a(i, j, got);
                if (got !== a_exp[i][j]) begin
                    $error("Bank A[%0d][%0d]: got %0d, expected %0d", i, j, got, a_exp[i][j]);
                    errors++;
                end
            end
    endtask

    task automatic verify_bank_b();
        int i, j;
        logic signed [DATA_WIDTH-1:0] got;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                bram_read_b(i, j, got);
                if (got !== b_exp[i][j]) begin
                    $error("Bank B[%0d][%0d]: got %0d, expected %0d", i, j, got, b_exp[i][j]);
                    errors++;
                end
            end
    endtask

    task automatic verify_bank_c();
        int i, j;
        logic signed [ACC_WIDTH-1:0] got;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                bram_read_c(i, j, got);
                if (got !== c_exp[i][j]) begin
                    $error("Bank C[%0d][%0d]: got %0d, expected %0d", i, j, got, c_exp[i][j]);
                    errors++;
                end
            end
    endtask

    initial begin
        a_we = 0;
        b_we = 0;
        c_we = 0;
        a_addr = '0;
        b_addr = '0;
        c_addr = '0;
        a_din  = '0;
        b_din  = '0;
        c_din  = '0;
        errors = 0;

        load_small_test_matrices();

        repeat (3) @(posedge clk);

        write_all_matrices();
        verify_bank_a();
        verify_bank_b();
        verify_bank_c();

        if (errors == 0) begin
            $display("matrix_bram_tb: Bank A PASS");
            $display("matrix_bram_tb: Bank B PASS");
            $display("matrix_bram_tb: Bank C PASS");
            $display("matrix_bram_tb: ALL TESTS PASSED");
        end else
            $display("matrix_bram_tb: FAILED with %0d error(s)", errors);
        $finish;
    end

endmodule
