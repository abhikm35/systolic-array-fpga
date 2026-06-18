# Waveform probes for matrix_bram_tb

database -open waves -shm -default

probe -create -shm matrix_bram_tb.clk
probe -create -shm matrix_bram_tb.a_we
probe -create -shm matrix_bram_tb.a_addr
probe -create -shm matrix_bram_tb.a_din
probe -create -shm matrix_bram_tb.a_dout
probe -create -shm matrix_bram_tb.b_we
probe -create -shm matrix_bram_tb.b_addr
probe -create -shm matrix_bram_tb.b_din
probe -create -shm matrix_bram_tb.b_dout
probe -create -shm matrix_bram_tb.c_we
probe -create -shm matrix_bram_tb.c_addr
probe -create -shm matrix_bram_tb.c_din
probe -create -shm matrix_bram_tb.c_dout
probe -create -shm matrix_bram_tb.dut.u_bram_a.mem
probe -create -shm matrix_bram_tb.dut.u_bram_b.mem
probe -create -shm matrix_bram_tb.dut.u_bram_c.mem

ida_probe -wave -wave_probe_args {matrix_bram_tb matrix_bram_tb.dut}

puts "probes_bram.tcl: A/B/C BRAM ports and internal mem probed into waves.shm"
