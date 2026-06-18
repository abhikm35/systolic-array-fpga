// matrix_bram.sv
// Single-port synchronous RAM for one 4x4 matrix bank (row-major addr = row*N + col).

module matrix_bram #(
    parameter int DATA_WIDTH = 16,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = 4
) (
    input  logic                        clk,
    input  logic                        we,
    input  logic [ADDR_WIDTH-1:0]       addr,
    input  logic signed [DATA_WIDTH-1:0] din,
    output logic signed [DATA_WIDTH-1:0] dout
);

    logic signed [DATA_WIDTH-1:0] mem [DEPTH];

    // Registered read: dout valid on the clock after addr/we are sampled.
  always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end

endmodule
