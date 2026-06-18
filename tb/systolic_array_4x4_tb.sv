// systolic_array_4x4_tb.sv
// M2 testbench — output-stationary 4x4 systolic array, C = A @ B
//
// This testbench plays the role of systolic_controller + BRAM for M2:
// it stores matrices A and B, streams them into a_left/b_top on a fixed
// skewed schedule, then checks c_out against golden C = A @ B.
//
// Injection schedule (systolic cycle index t):
//   a_left[i] = A[i][t-i]  when 0 <= t-i < N, else 0
//   b_top[j]  = B[t-j][j]  when 0 <= t-j < N, else 0
// PE[i,j] accumulates A[i][k]*B[k][j] when both meet at cycle i+j+k.

`timescale 1ns / 1ps

module systolic_array_4x4_tb;

    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH  = 32;
    localparam int N          = 4;

    // -------------------------------------------------------------------------
    // DUT interface signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst;
    logic clear;
    logic signed [DATA_WIDTH-1:0] a_left [N];  // west boundary: one value per row
    logic signed [DATA_WIDTH-1:0] b_top  [N];  // north boundary: one value per col
    logic signed [ACC_WIDTH-1:0]  c_out  [N][N];

    // -------------------------------------------------------------------------
    // Test matrices — stored in TB (like future BRAM contents)
    // -------------------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] A_mat [N][N];
    logic signed [DATA_WIDTH-1:0] B_mat [N][N];
    logic signed [ACC_WIDTH-1:0]  C_exp [N][N];  // expected C = A @ B

    int errors;

    systolic_array_4x4 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .N          (N)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .clear   (clear),
        .a_left  (a_left),
        .b_top   (b_top),
        .c_out   (c_out)
    );

    // 100 MHz clock (10 ns period) — matches pe_tb and planned Basys 3 rate
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // compute_expected — software golden model inside the testbench
    // For each C_exp[i][j], sum A_mat[i][k] * B_mat[k][j] over k.
    // =========================================================================
    function automatic void compute_expected();
        int i, j, k;
        longint acc;
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                acc = 0;
                for (k = 0; k < N; k++)
                    acc += A_mat[i][k] * B_mat[k][j];
                C_exp[i][j] = ACC_WIDTH'(acc);
            end
        end
    endfunction

    // =========================================================================
    // drive_injection — one systolic cycle t of west/north boundary stimulus
    //
    // Skew: row i of A is delayed by i cycles; col j of B is delayed by j.
    // At cycle t, the k-th element of row i enters: A[i][k] with k = t - i.
    // At cycle t, the k-th element of col j enters: B[k][j] with k = t - j.
    // =========================================================================
    task automatic drive_injection(input int t);
        int i, j, k;
        for (i = 0; i < N; i++) begin
            k = t - i;
            if (k >= 0 && k < N)
                a_left[i] = A_mat[i][k];
            else
                a_left[i] = '0;
        end
        for (j = 0; j < N; j++) begin
            k = t - j;
            if (k >= 0 && k < N)
                b_top[j] = B_mat[k][j];
            else
                b_top[j] = '0;
        end
    endtask

    // =========================================================================
    // drive_zeros — all boundary inputs zero (drain / idle cycles)
    // =========================================================================
    task automatic drive_zeros();
        int i, j;
        for (i = 0; i < N; i++) a_left[i] = '0;
        for (j = 0; j < N; j++) b_top[j]  = '0;
    endtask

    // =========================================================================
    // run_systolic_mult — full compute sequence for current A_mat / B_mat
    //
    // 1) Pulse clear — zero all PE accumulators
    // 2) Inject t = 0 .. 2N-2 — all matrix elements enter the mesh
    // 3) Drain N cycles of zeros — flush partial products through pipeline
    // =========================================================================
    task automatic run_systolic_mult();
        int t, d;
        @(negedge clk);
        clear = 1'b1;
        drive_zeros();
        @(posedge clk);
        #1step;
        clear = 1'b0;

        for (t = 0; t <= 2 * N - 2; t++) begin
            @(negedge clk);
            drive_injection(t);
            @(posedge clk);
        end

        for (d = 0; d < N; d++) begin
            @(negedge clk);
            drive_zeros();
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // check_c_matrix — compare hardware c_out against C_exp
    // Caller must #1step before calling (NBA settle after last posedge).
    // =========================================================================
    function automatic int check_c_matrix(input string test_name);
        int i, j;
        int local_errors;
        local_errors = 0;
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                if (c_out[i][j] !== C_exp[i][j]) begin
                    $error("%s: c_out[%0d][%0d]=%0d, expected %0d",
                           test_name, i, j, c_out[i][j], C_exp[i][j]);
                    local_errors++;
                end
            end
        end
        if (local_errors == 0)
            $display("%s: C matrix PASS", test_name);
        return local_errors;
    endfunction

    // =========================================================================
    // load_identity — A = I, B = I  =>  expected C = I
    // =========================================================================
    task automatic load_identity();
        int i, j;
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                A_mat[i][j] = (i == j) ? 16'sd1 : 16'sd0;
                B_mat[i][j] = (i == j) ? 16'sd1 : 16'sd0;
            end
        end
    endtask

    // =========================================================================
    // load_small_test — second regression matrix (matches golden_model.py)
    // =========================================================================
    task automatic load_small_test();
        int i, j;
        logic signed [DATA_WIDTH-1:0] a3 [N][N];
        logic signed [DATA_WIDTH-1:0] b3 [N][N];
        a3[0][0] = 1; a3[0][1] = 2; a3[0][2] = 0; a3[0][3] = 0;
        a3[1][0] = 3; a3[1][1] = 4; a3[1][2] = 0; a3[1][3] = 0;
        a3[2][0] = 0; a3[2][1] = 0; a3[2][2] = 1; a3[2][3] = 0;
        a3[3][0] = 0; a3[3][1] = 0; a3[3][2] = 0; a3[3][3] = 1;
        b3[0][0] = 5; b3[0][1] = 6; b3[0][2] = 0; b3[0][3] = 0;
        b3[1][0] = 7; b3[1][1] = 8; b3[1][2] = 0; b3[1][3] = 0;
        b3[2][0] = 0; b3[2][1] = 0; b3[2][2] = 1; b3[2][3] = 0;
        b3[3][0] = 0; b3[3][1] = 0; b3[3][2] = 0; b3[3][3] = 1;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                A_mat[i][j] = a3[i][j];
                B_mat[i][j] = b3[i][j];
            end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        rst    = 1;
        clear  = 0;
        errors = 0;
        drive_zeros();

        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        // TODO: Identity matrix test — C = I @ I = I
        //   Load A = 4x4 identity, B = 4x4 identity.
        //   Stream A left-to-right and B top-to-bottom per systolic schedule.
        //   After drain, verify c_out[i][j] == (i == j) ? 1 : 0 (fixed-point).
        load_identity();
        compute_expected();
        run_systolic_mult();
        #1step;
        errors += check_c_matrix("identity IxI");

        load_small_test();
        compute_expected();
        run_systolic_mult();
        #1step;
        errors += check_c_matrix("small 4x4");

        if (errors == 0)
            $display("systolic_array_4x4_tb: ALL TESTS PASSED");
        else
            $display("systolic_array_4x4_tb: FAILED with %0d error(s)", errors);
        $finish;
    end

endmodule
