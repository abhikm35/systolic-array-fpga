// matrix_memories.sv
// Three independent single-port BRAM banks for A, B (16-bit) and C (32-bit).
// Row-major addressing: addr = row * N + col  (0 .. N*N-1).

module matrix_memories #(
    parameter int N          = 4,
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 32,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = 4
) (
    input  logic clk,

    // Bank A — operand matrix
    input  logic                        a_we,
    input  logic [ADDR_WIDTH-1:0]       a_addr,
    input  logic signed [DATA_WIDTH-1:0] a_din,
    output logic signed [DATA_WIDTH-1:0] a_dout,

    // Bank B — operand matrix
    input  logic                        b_we,
    input  logic [ADDR_WIDTH-1:0]       b_addr,
    input  logic signed [DATA_WIDTH-1:0] b_din,
    output logic signed [DATA_WIDTH-1:0] b_dout,

    // Bank C — result matrix
    input  logic                        c_we,
    input  logic [ADDR_WIDTH-1:0]       c_addr,
    input  logic signed [ACC_WIDTH-1:0]  c_din,
    output logic signed [ACC_WIDTH-1:0]  c_dout
);

    matrix_bram #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_bram_a (
        .clk  (clk),
        .we   (a_we),
        .addr (a_addr),
        .din  (a_din),
        .dout (a_dout)
    );

    matrix_bram #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_bram_b (
        .clk  (clk),
        .we   (b_we),
        .addr (b_addr),
        .din  (b_din),
        .dout (b_dout)
    );

    matrix_bram #(
        .DATA_WIDTH (ACC_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_bram_c (
        .clk  (clk),
        .we   (c_we),
        .addr (c_addr),
        .din  (c_din),
        .dout (c_dout)
    );

endmodule
