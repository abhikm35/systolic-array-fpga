// host_uart_cmd.sv
// UART command parser: load A/B BRAM, start compute, read C BRAM.
//
// Host protocol (all multi-byte fields little-endian):
//   'A' addr u8  data_lo u8  data_hi u8   — write 16-bit A element at addr (0..15)
//   'B' addr u8  data_lo u8  data_hi u8   — write 16-bit B element at addr
//   'S'                                   — pulse systolic controller start (when idle)
//   'C' addr u8                           — read 32-bit C element; FPGA replies with 4 data bytes
//   'D' (FPGA→host)                       — compute finished (sent automatically after START)

module host_uart_cmd #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 32
) (
    input  logic       clk,
    input  logic       rst,

    input  logic [7:0] rx_data,
    input  logic       rx_valid,

    input  logic       ctrl_busy,
    input  logic       ctrl_done,
    output logic       ctrl_start,

    input  logic       tx_busy,
    output logic [7:0] tx_data,
    output logic       tx_valid,

    input  logic signed [ACC_WIDTH-1:0] c_dout,

    output logic                        host_a_we,
    output logic                        host_b_we,
    output logic [3:0]                  host_a_addr,
    output logic [3:0]                  host_b_addr,
    output logic [3:0]                  host_c_addr,
    output logic signed [DATA_WIDTH-1:0] a_din,
    output logic signed [DATA_WIDTH-1:0] b_din
);

    localparam logic [7:0] CMD_A = 8'h41;
    localparam logic [7:0] CMD_B = 8'h42;
    localparam logic [7:0] CMD_S = 8'h53;
    localparam logic [7:0] CMD_C = 8'h43;
    localparam logic [7:0] RSP_D = 8'h44;
    localparam logic [7:0] RSP_E = 8'h45;

    typedef enum logic [3:0] {
        CMD_IDLE,
        CMD_A_ADDR,
        CMD_A_LO,
        CMD_A_HI,
        CMD_B_ADDR,
        CMD_B_LO,
        CMD_B_HI,
        CMD_C_ADDR,
        CMD_C_WAIT,
        CMD_C_SAMPLE,
        CMD_TX_BYTE,
        CMD_WAIT_DONE
    } cmd_state_t;

    cmd_state_t state;

    logic [3:0]       elem_addr;
    logic [7:0]       data_lo;
    logic [7:0]       data_hi;
    logic [ACC_WIDTH-1:0] c_read_val;
    logic [2:0]       tx_byte_idx;

    logic ctrl_done_q;
    logic done_pulse;
    logic start_pulse;
    logic done_tx_pending;
    logic tx_busy_q;
    wire  tx_done = tx_busy_q & ~tx_busy;

    assign done_pulse = ctrl_done & ~ctrl_done_q;

    always_ff @(posedge clk) begin
        if (rst)
            ctrl_done_q <= 1'b0;
        else
            ctrl_done_q <= ctrl_done;
    end

    always_ff @(posedge clk) begin
        if (rst)
            tx_busy_q <= 1'b0;
        else
            tx_busy_q <= tx_busy;
    end

    always_ff @(posedge clk) begin
        if (rst)
            ctrl_start <= 1'b0;
        else
            ctrl_start <= start_pulse;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state            <= CMD_IDLE;
            elem_addr        <= '0;
            data_lo          <= '0;
            data_hi          <= '0;
            c_read_val       <= '0;
            tx_byte_idx      <= '0;
            host_a_we        <= 1'b0;
            host_b_we        <= 1'b0;
            host_a_addr      <= '0;
            host_b_addr      <= '0;
            host_c_addr      <= '0;
            a_din            <= '0;
            b_din            <= '0;
            tx_data          <= '0;
            tx_valid         <= 1'b0;
            start_pulse      <= 1'b0;
            done_tx_pending  <= 1'b0;
        end else begin
            host_a_we   <= 1'b0;
            host_b_we   <= 1'b0;
            tx_valid    <= 1'b0;
            start_pulse <= 1'b0;

            if (done_pulse && state != CMD_WAIT_DONE)
                done_tx_pending <= 1'b1;

            unique case (state)
                CMD_IDLE: begin
                    tx_byte_idx <= '0;

                    if (!tx_busy && done_tx_pending) begin
                        tx_data         <= RSP_D;
                        tx_valid        <= 1'b1;
                        done_tx_pending <= 1'b0;
                    end else if (rx_valid) begin
                        unique case (rx_data)
                            CMD_A: state <= CMD_A_ADDR;
                            CMD_B: state <= CMD_B_ADDR;
                            CMD_S: begin
                                if (!ctrl_busy) begin
                                    start_pulse <= 1'b1;
                                    state       <= CMD_WAIT_DONE;
                                end else if (!tx_busy) begin
                                    tx_data  <= RSP_E;
                                    tx_valid <= 1'b1;
                                end
                            end
                            CMD_C: state <= CMD_C_ADDR;
                            default: ;
                        endcase
                    end
                end

                CMD_A_ADDR: begin
                    if (rx_valid) begin
                        if (ctrl_busy) begin
                            state <= CMD_IDLE;
                        end else begin
                            elem_addr   <= rx_data[3:0];
                            host_a_addr <= rx_data[3:0];
                            state       <= CMD_A_LO;
                        end
                    end
                end

                CMD_A_LO: begin
                    if (rx_valid) begin
                        data_lo <= rx_data;
                        state   <= CMD_A_HI;
                    end
                end

                CMD_A_HI: begin
                    if (rx_valid) begin
                        data_hi   <= rx_data;
                        a_din     <= $signed({rx_data, data_lo});
                        host_a_we <= 1'b1;
                        state     <= CMD_IDLE;
                    end
                end

                CMD_B_ADDR: begin
                    if (rx_valid) begin
                        if (ctrl_busy) begin
                            state <= CMD_IDLE;
                        end else begin
                            elem_addr   <= rx_data[3:0];
                            host_b_addr <= rx_data[3:0];
                            state       <= CMD_B_LO;
                        end
                    end
                end

                CMD_B_LO: begin
                    if (rx_valid) begin
                        data_lo <= rx_data;
                        state   <= CMD_B_HI;
                    end
                end

                CMD_B_HI: begin
                    if (rx_valid) begin
                        data_hi   <= rx_data;
                        b_din     <= $signed({rx_data, data_lo});
                        host_b_we <= 1'b1;
                        state     <= CMD_IDLE;
                    end
                end

                CMD_C_ADDR: begin
                    if (rx_valid) begin
                        host_c_addr <= rx_data[3:0];
                        state       <= CMD_C_WAIT;
                    end
                end

                CMD_C_WAIT: begin
                    state <= CMD_C_SAMPLE;
                end

                CMD_C_SAMPLE: begin
                    c_read_val  <= c_dout;
                    tx_byte_idx <= '0;
                    state       <= CMD_TX_BYTE;
                end

                CMD_TX_BYTE: begin
                    // One byte per UART frame: on entry (idx==0) or when tx_done.
                    if (!tx_busy && ((tx_byte_idx == 3'd0) || tx_done)) begin
                        unique case (tx_byte_idx)
                            3'd0: tx_data <= c_read_val[7:0];
                            3'd1: tx_data <= c_read_val[15:8];
                            3'd2: tx_data <= c_read_val[23:16];
                            3'd3: tx_data <= c_read_val[31:24];
                            default: tx_data <= 8'h00;
                        endcase
                        tx_valid <= 1'b1;

                        if (tx_byte_idx == 3'd3)
                            state <= CMD_IDLE;
                        else
                            tx_byte_idx <= tx_byte_idx + 1'b1;
                    end
                end

                CMD_WAIT_DONE: begin
                    if (done_pulse) begin
                        state <= CMD_IDLE;
                        if (!tx_busy) begin
                            tx_data         <= RSP_D;
                            tx_valid        <= 1'b1;
                            done_tx_pending <= 1'b0;
                        end else begin
                            done_tx_pending <= 1'b1;
                        end
                    end
                end

                default: state <= CMD_IDLE;
            endcase
        end
    end

endmodule
