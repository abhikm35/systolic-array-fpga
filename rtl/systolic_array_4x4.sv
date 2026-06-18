// systolic_array_4x4.sv
// 4x4 output-stationary systolic array for fixed-point matrix multiply C = A @ B

module systolic_array_4x4 #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 32,
    parameter int N          = 4
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  clear,
    input  logic signed [DATA_WIDTH-1:0] a_left [N],
    input  logic signed [DATA_WIDTH-1:0] b_top  [N],
    output logic signed [ACC_WIDTH-1:0]  c_out  [N][N]
);

    // -------------------------------------------------------------------------
    // Internal propagation wires
    // TODO: A values move left to right across each row.
    // TODO: B values move top to bottom down each column.
    // TODO: Each PE stores one output-stationary C[i][j] value in its acc_out.
    // -------------------------------------------------------------------------

    // Horizontal A propagation: a_h[row][col] is input to PE at (row, col)
    logic signed [DATA_WIDTH-1:0] a_h [N][N+1];

    // Vertical B propagation: b_v[row][col] is input to PE at (row, col)
    logic signed [DATA_WIDTH-1:0] b_v [N+1][N];

    // PE accumulator outputs
    logic signed [ACC_WIDTH-1:0] pe_acc [N][N];

    // Drive left column from external A inputs
    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : gen_a_left
            assign a_h[gi][0] = a_left[gi];
        end
        for (gj = 0; gj < N; gj++) begin : gen_b_top
            assign b_v[0][gj] = b_top[gj];
        end
    endgenerate

    // Instantiate N x N grid of processing elements
    generate
        for (gi = 0; gi < N; gi++) begin : gen_row
            for (gj = 0; gj < N; gj++) begin : gen_col
                pe #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ACC_WIDTH  (ACC_WIDTH)
                ) u_pe (
                    .clk     (clk),
                    .rst     (rst),
                    .clear   (clear),
                    .a_in    (a_h[gi][gj]),
                    .b_in    (b_v[gi][gj]),
                    .a_out   (a_h[gi][gj+1]),
                    .b_out   (b_v[gi+1][gj]),
                    .acc_out (pe_acc[gi][gj])
                );
            end
        end
    endgenerate

    // Map PE accumulators to output matrix C
    generate
        for (gi = 0; gi < N; gi++) begin : gen_c_row
            for (gj = 0; gj < N; gj++) begin : gen_c_col
                assign c_out[gi][gj] = pe_acc[gi][gj];
            end
        end
    endgenerate

endmodule
