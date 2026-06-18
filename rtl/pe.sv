// pe.sv
// Processing Element for output-stationary systolic array
// First milestone: implement and verify this module before array integration.

module pe #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  clear,
    input  logic signed [DATA_WIDTH-1:0] a_in,
    input  logic signed [DATA_WIDTH-1:0] b_in,
    output logic signed [DATA_WIDTH-1:0] a_out,
    output logic signed [DATA_WIDTH-1:0] b_out,
    output logic signed [ACC_WIDTH-1:0]  acc_out
);

    // Internal accumulator register
    logic signed [ACC_WIDTH-1:0] acc_reg;

    // TODO: Implement multiply-accumulate behavior:
    //   - Forward a_in to a_out (A values propagate horizontally)
    //   - Forward b_in to b_out (B values propagate vertically)
    //   - On each enabled cycle: acc_out += a_in * b_in
    //   - On clear: reset accumulator to zero
    //
    // Fixed-point note: a_in and b_in are signed DATA_WIDTH values;
    // product width is 2*DATA_WIDTH; accumulate into ACC_WIDTH.

    always_ff @(posedge clk) begin
        if (rst) begin
            acc_reg <= '0;
            a_out   <= '0;
            b_out   <= '0;
        end else begin
            // TODO: drive a_out <= a_in
            // TODO: drive b_out <= b_in
            a_out <= a_in;
            b_out <= b_in;
            if (clear) begin
                acc_reg <= '0;
            end else begin
                // TODO: acc_reg <= acc_reg + (a_in * b_in)
                acc_reg <= acc_reg + (a_in * b_in);

            end
        end
    end

    assign acc_out = acc_reg;

endmodule
