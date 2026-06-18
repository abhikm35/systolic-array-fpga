// accelerator_top.sv
// Top-level systolic array accelerator for Digilent Basys 3
//
// Host UART protocol (see host_uart_cmd.sv):
//   'A' addr data_lo data_hi  — write A BRAM element
//   'B' addr data_lo data_hi  — write B BRAM element
//   'S'                       — start C = A @ B
//   'C' addr                  — read C BRAM element (4-byte LE reply)
//   'D'                       — done notification from FPGA after compute

module accelerator_top (
    input  logic        clk,      // 100 MHz system clock
    input  logic        btnC,     // active-high reset (center button)
    input  logic        uart_rx,  // host -> FPGA
    output logic        uart_tx,  // FPGA -> host
    output logic [15:0] led
);

    logic rst;
    assign rst = btnC;

    localparam int DATA_WIDTH = 16;
    localparam int ACC_WIDTH  = 32;
    localparam int N          = 4;

    logic        ctrl_start;
    logic        ctrl_done;
    logic        ctrl_busy;
    logic        array_clear;

    logic signed [DATA_WIDTH-1:0] a_left [N];
    logic signed [DATA_WIDTH-1:0] b_top  [N];
    logic signed [ACC_WIDTH-1:0]  c_out  [N][N];

    logic [7:0]  rx_data;
    logic        rx_valid;
    logic [7:0]  tx_data;
    logic        tx_valid;
    logic        tx_busy;

    logic        host_a_we, host_b_we;
    logic [3:0]  host_a_addr, host_b_addr, host_c_addr;
    logic [3:0]  ctrl_a_addr, ctrl_b_addr, ctrl_c_addr;
    logic signed [DATA_WIDTH-1:0] a_din, b_din;
    logic signed [DATA_WIDTH-1:0] a_dout, b_dout;
    logic signed [ACC_WIDTH-1:0]  c_din, c_dout;
    logic        ctrl_c_we;

    logic        a_we, b_we;
    logic [3:0]  a_addr, b_addr, c_addr;

    // Host owns A/B when controller is idle; controller owns all banks while busy.
    assign a_we   = ctrl_busy ? 1'b0 : host_a_we;
    assign b_we   = ctrl_busy ? 1'b0 : host_b_we;
    assign a_addr = ctrl_busy ? ctrl_a_addr : host_a_addr;
    assign b_addr = ctrl_busy ? ctrl_b_addr : host_b_addr;
    assign c_addr = ctrl_busy ? ctrl_c_addr : host_c_addr;

    uart_rx #(
        .CLK_FREQ  (100_000_000),
        .BAUD_RATE (115200)
    ) u_uart_rx (
        .clk   (clk),
        .rst   (rst),
        .rx    (uart_rx),
        .data  (rx_data),
        .valid (rx_valid)
    );

    uart_tx #(
        .CLK_FREQ  (100_000_000),
        .BAUD_RATE (115200)
    ) u_uart_tx (
        .clk   (clk),
        .rst   (rst),
        .data  (tx_data),
        .valid (tx_valid),
        .tx    (uart_tx),
        .busy  (tx_busy)
    );

    host_uart_cmd #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH)
    ) u_host_cmd (
        .clk         (clk),
        .rst         (rst),
        .rx_data     (rx_data),
        .rx_valid    (rx_valid),
        .ctrl_busy   (ctrl_busy),
        .ctrl_done   (ctrl_done),
        .ctrl_start  (ctrl_start),
        .tx_busy     (tx_busy),
        .tx_data     (tx_data),
        .tx_valid    (tx_valid),
        .c_dout      (c_dout),
        .host_a_we   (host_a_we),
        .host_b_we   (host_b_we),
        .host_a_addr (host_a_addr),
        .host_b_addr (host_b_addr),
        .host_c_addr (host_c_addr),
        .a_din       (a_din),
        .b_din       (b_din)
    );

    matrix_memories #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .DEPTH      (N * N),
        .ADDR_WIDTH (4)
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
        .c_we   (ctrl_c_we),
        .c_addr (c_addr),
        .c_din  (c_din),
        .c_dout (c_dout)
    );

    systolic_controller #(
        .N          (N),
        .DATA_WIDTH (DATA_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .ADDR_WIDTH (4)
    ) u_ctrl (
        .clk         (clk),
        .rst         (rst),
        .start       (ctrl_start),
        .done        (ctrl_done),
        .busy        (ctrl_busy),
        .array_clear (array_clear),
        .a_addr      (ctrl_a_addr),
        .a_dout      (a_dout),
        .b_addr      (ctrl_b_addr),
        .b_dout      (b_dout),
        .c_we        (ctrl_c_we),
        .c_addr      (ctrl_c_addr),
        .c_din       (c_din),
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

    always_ff @(posedge clk) begin
        if (rst)
            led <= 16'h0000;
        else begin
            led[0] <= ctrl_done;
            led[1] <= ctrl_busy;
            led[2] <= tx_busy;
            led[3] <= rx_valid;
        end
    end

endmodule
