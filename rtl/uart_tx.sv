// uart_tx.sv
// UART transmitter for Basys 3 host communication (8N1, LSB-first).

module uart_tx #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] data,
    input  logic       valid,
    output logic       tx,
    output logic       busy
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int CNT_W = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT + 1);

    typedef enum logic [2:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP,
        S_CLEANUP
    } state_t;

    state_t state;

    logic [CNT_W-1:0] clk_count;
    logic [2:0]       bit_index;
    logic [7:0]       tx_shift;

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_count <= '0;
            bit_index <= '0;
            tx_shift  <= 8'd0;
            tx        <= 1'b1;
            busy      <= 1'b0;
        end else begin
            unique case (state)
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;

                    if (valid) begin
                        tx_shift  <= data;
                        clk_count <= '0;
                        bit_index <= '0;
                        busy      <= 1'b1;
                        tx        <= 1'b0;
                        state     <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;

                    if (clk_count == CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_count <= '0;
                        state     <= S_DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    tx <= tx_shift[bit_index];

                    if (clk_count == CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_count <= '0;

                        if (bit_index == 3'd7) begin
                            bit_index <= '0;
                            state     <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;

                    if (clk_count == CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_count <= '0;
                        state     <= S_CLEANUP;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_CLEANUP: begin
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
