// uart_rx.sv
// UART receiver for Basys 3 host communication (8N1, LSB-first).

module uart_rx #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid
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
    logic [7:0]       rx_shift;

    logic rx_meta;
    logic rx_sync;

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_count <= '0;
            bit_index <= '0;
            rx_shift  <= 8'd0;
            data      <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;

                    if (rx_sync == 1'b0)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_count == CNT_W'((CLKS_PER_BIT / 2) - 1)) begin
                        clk_count <= '0;

                        if (rx_sync == 1'b0)
                            state <= S_DATA;
                        else
                            state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_count <= '0;
                        rx_shift[bit_index] <= rx_sync;

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
                    if (clk_count == CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_count <= '0;

                        if (rx_sync == 1'b1) begin
                            data  <= rx_shift;
                            valid <= 1'b1;
                        end
                        state <= S_CLEANUP;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                S_CLEANUP: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
