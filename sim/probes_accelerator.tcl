# Waveform probes for accelerator_top_tb
# Focus: UART C-read reply (4-byte burst) and host_uart_cmd <-> uart_tx handshake
#
# What to look for (zoom to first 'C' read after compute finishes):
#   - u_host_cmd.state enters CMD_TX_BYTE
#   - tx_byte_idx steps 0 -> 1 -> 2 -> 3 once per completed UART frame
#   - tx_valid pulses once per byte; tx_busy rises shortly after each pulse
#   - tx_done (busy falling edge) should precede the next tx_valid (fixed RTL)
#   - uart_tx shows four back-to-back serial frames on the wire

database -open waves -shm -default

set tb accelerator_top_tb
set dut ${tb}.dut
set host ${dut}.u_host_cmd
set utx ${dut}.u_uart_tx
set urx ${dut}.u_uart_rx

# --- TB clock / UART pins (what the "PC" sees) ---
probe -create -shm ${tb}.clk
probe -create -shm ${tb}.uart_rx
probe -create -shm ${tb}.uart_tx

# --- Host command FSM (C read path) ---
probe -create -shm ${host}.state
probe -create -shm ${host}.host_c_addr
probe -create -shm ${host}.c_read_val
probe -create -shm ${host}.tx_byte_idx

# --- UART TX handshake (the bug/fix lives here) ---
probe -create -shm ${host}.tx_data
probe -create -shm ${host}.tx_valid
probe -create -shm ${host}.tx_busy
probe -create -shm ${host}.tx_busy_q
probe -create -shm ${host}.tx_done

# --- UART transmitter internals ---
probe -create -shm ${utx}.valid
probe -create -shm ${utx}.data
probe -create -shm ${utx}.busy
probe -create -shm ${utx}.tx
probe -create -shm ${utx}.state

# --- UART receiver (host -> FPGA commands) ---
probe -create -shm ${urx}.rx
probe -create -shm ${urx}.data
probe -create -shm ${urx}.valid

# --- C BRAM read port (data being serialized) ---
probe -create -shm ${dut}.host_c_addr
probe -create -shm ${dut}.c_dout
probe -create -shm ${dut}.c_addr

# --- Compute handshake (context: 'S' then 'D') ---
probe -create -shm ${dut}.ctrl_start
probe -create -shm ${dut}.ctrl_done
probe -create -shm ${dut}.ctrl_busy

ida_probe -wave -wave_probe_args [list ${tb} ${host} ${utx} ${urx}]

puts "probes_accelerator.tcl: UART / C-read signals probed into waves.shm"
puts ""
puts "Recommended wave groups (top to bottom):"
puts "  1) clk, uart_tx, uart_rx"
puts "  2) host.state, host.tx_byte_idx, host.c_read_val"
puts "  3) host.tx_valid, host.tx_data, host.tx_busy, host.tx_done"
puts "  4) utx.valid, utx.data, utx.busy, utx.state"
puts ""
puts "Zoom tip: run sim; with +UART_DEBUG it stops after first C-read burst"
