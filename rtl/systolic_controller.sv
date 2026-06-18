// systolic_controller.sv
// Loads A/B from BRAM into registers, runs systolic multiply, writes C to BRAM.

module systolic_controller #(
    parameter int N          = 4,
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 32,
    parameter int ADDR_WIDTH = 4,
    parameter int DEPTH      = 16
) (
    input  logic clk,
    input  logic rst,
    input  logic start,
    output logic done,
    output logic busy,

    output logic array_clear,

    output logic [ADDR_WIDTH-1:0]        a_addr,
    input  logic signed [DATA_WIDTH-1:0] a_dout,

    output logic [ADDR_WIDTH-1:0]        b_addr,
    input  logic signed [DATA_WIDTH-1:0] b_dout,

    output logic                         c_we,
    output logic [ADDR_WIDTH-1:0]        c_addr,
    output logic signed [ACC_WIDTH-1:0]  c_din,

    input  logic signed [ACC_WIDTH-1:0]  c_out [N][N],

    output logic signed [DATA_WIDTH-1:0] a_left [N],
    output logic signed [DATA_WIDTH-1:0] b_top  [N]
);

    typedef enum logic [3:0] {
        IDLE,
        LOAD_A,
        LOAD_B,
        CLEAR,
        COMPUTE,
        DRAIN,
        WRITEBACK,
        DONE_ST
    } state_t;

    state_t state;

    logic signed [DATA_WIDTH-1:0] a_reg [N][N];
    logic signed [DATA_WIDTH-1:0] b_reg [N][N];

    logic [$clog2(DEPTH + 1)-1:0] load_cnt;
    logic [$clog2(2 * N)-1:0]     inject_cnt;
    logic [$clog2(N + 1)-1:0]     drain_cnt;
    logic [ADDR_WIDTH-1:0]        wb_cnt;

    logic [1:0]            cap_row, cap_col;
    logic [ADDR_WIDTH-1:0] cap_addr;

    function automatic logic [1:0] addr_row(input logic [ADDR_WIDTH-1:0] addr);
        return addr[ADDR_WIDTH-1:2];
    endfunction

    function automatic logic [1:0] addr_col(input logic [ADDR_WIDTH-1:0] addr);
        return addr[1:0];
    endfunction

    assign cap_addr = ADDR_WIDTH'(load_cnt - 1);
    assign cap_row  = addr_row(cap_addr);
    assign cap_col  = addr_col(cap_addr);

    assign done        = (state == DONE_ST);
    assign busy        = (state != IDLE) && (state != DONE_ST);
    assign array_clear = (state == CLEAR);
    assign c_we        = (state == WRITEBACK);

    // Systolic boundary — same schedule as systolic_array_4x4_tb drive_injection(t)
    always_comb begin
        int i, j, k, t;
        t = int'(inject_cnt);
        for (i = 0; i < N; i++) begin
            k = t - i;
            if (state == COMPUTE && k >= 0 && k < N)
                a_left[i] = a_reg[i][k];
            else
                a_left[i] = '0;
        end
        for (j = 0; j < N; j++) begin
            k = t - j;
            if (state == COMPUTE && k >= 0 && k < N)
                b_top[j] = b_reg[k][j];
            else
                b_top[j] = '0;
        end
    end

    always_comb begin
        a_addr = '0;
        b_addr = '0;
        c_addr = '0;
        c_din  = '0;
        unique case (state)
            LOAD_A:    a_addr = ADDR_WIDTH'(load_cnt);
            LOAD_B:    b_addr = ADDR_WIDTH'(load_cnt);
            WRITEBACK: begin
                c_addr = wb_cnt;
                c_din  = c_out[addr_row(wb_cnt)][addr_col(wb_cnt)];
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            load_cnt   <= '0;
            inject_cnt <= '0;
            drain_cnt  <= '0;
            wb_cnt     <= '0;
        end else begin
            unique case (state)
                IDLE: begin
                    load_cnt   <= '0;
                    inject_cnt <= '0;
                    drain_cnt  <= '0;
                    wb_cnt     <= '0;
                    if (start)
                        state <= LOAD_A;
                end

                LOAD_A: begin
                    if (load_cnt > 0)
                        a_reg[cap_row][cap_col] <= a_dout;
                    if (load_cnt == DEPTH) begin
                        load_cnt <= '0;
                        state    <= LOAD_B;
                    end else
                        load_cnt <= load_cnt + 1'b1;
                end

                LOAD_B: begin
                    if (load_cnt > 0)
                        b_reg[cap_row][cap_col] <= b_dout;
                    if (load_cnt == DEPTH) begin
                        load_cnt <= '0;
                        state    <= CLEAR;
                    end else
                        load_cnt <= load_cnt + 1'b1;
                end

                CLEAR: begin
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (inject_cnt == 2 * N - 2) begin
                        inject_cnt <= '0;
                        drain_cnt  <= '0;
                        state      <= DRAIN;
                    end else
                        inject_cnt <= inject_cnt + 1'b1;
                end

                DRAIN: begin
                    if (drain_cnt == N - 1) begin
                        drain_cnt <= '0;
                        wb_cnt    <= '0;
                        state     <= WRITEBACK;
                    end else
                        drain_cnt <= drain_cnt + 1'b1;
                end

                WRITEBACK: begin
                    if (wb_cnt == DEPTH - 1)
                        state <= DONE_ST;
                    else
                        wb_cnt <= wb_cnt + 1'b1;
                end

                DONE_ST: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
