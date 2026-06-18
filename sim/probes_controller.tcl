# Waveform probes for controller_array_tb
# BRAM + systolic_controller + systolic_array_4x4 integration

database -open waves -shm -default

# --- TB control / handshake ---
probe -create -shm controller_array_tb.clk
probe -create -shm controller_array_tb.rst
probe -create -shm controller_array_tb.start
probe -create -shm controller_array_tb.done
probe -create -shm controller_array_tb.busy
probe -create -shm controller_array_tb.array_clear

# --- Address mux (TB preload vs controller ownership) ---
probe -create -shm controller_array_tb.tb_a_we
probe -create -shm controller_array_tb.tb_b_we
probe -create -shm controller_array_tb.tb_a_addr
probe -create -shm controller_array_tb.tb_b_addr
probe -create -shm controller_array_tb.ctrl_a_addr
probe -create -shm controller_array_tb.ctrl_b_addr
probe -create -shm controller_array_tb.ctrl_c_addr
probe -create -shm controller_array_tb.a_addr
probe -create -shm controller_array_tb.b_addr
probe -create -shm controller_array_tb.c_addr

# --- BRAM ports (muxed A/B, controller-owned C) ---
probe -create -shm controller_array_tb.a_we
probe -create -shm controller_array_tb.b_we
probe -create -shm controller_array_tb.c_we
probe -create -shm controller_array_tb.a_din
probe -create -shm controller_array_tb.b_din
probe -create -shm controller_array_tb.c_din
probe -create -shm controller_array_tb.a_dout
probe -create -shm controller_array_tb.b_dout
probe -create -shm controller_array_tb.c_dout

# --- Systolic array boundary ---
probe -create -shm controller_array_tb.a_left
probe -create -shm controller_array_tb.b_top
probe -create -shm controller_array_tb.c_out

# --- Controller FSM and internal state ---
probe -create -shm controller_array_tb.u_ctrl.state
probe -create -shm controller_array_tb.u_ctrl.load_cnt
probe -create -shm controller_array_tb.u_ctrl.inject_cnt
probe -create -shm controller_array_tb.u_ctrl.drain_cnt
probe -create -shm controller_array_tb.u_ctrl.wb_cnt
probe -create -shm controller_array_tb.u_ctrl.a_reg
probe -create -shm controller_array_tb.u_ctrl.b_reg

# --- Array mesh (optional detail) ---
probe -create -shm controller_array_tb.u_array.pe_acc

# --- BRAM contents ---
probe -create -shm controller_array_tb.u_mem.u_bram_a.mem
probe -create -shm controller_array_tb.u_mem.u_bram_b.mem
probe -create -shm controller_array_tb.u_mem.u_bram_c.mem

ida_probe -wave -wave_probe_args {controller_array_tb controller_array_tb.u_ctrl controller_array_tb.u_array controller_array_tb.u_mem}

puts "probes_controller.tcl: controller integration signals probed into waves.shm"
