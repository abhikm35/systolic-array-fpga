# Waveform probes for systolic_array_4x4_tb

database -open waves -shm -default

probe -create -shm systolic_array_4x4_tb.clk
probe -create -shm systolic_array_4x4_tb.rst
probe -create -shm systolic_array_4x4_tb.clear
probe -create -shm systolic_array_4x4_tb.a_left
probe -create -shm systolic_array_4x4_tb.b_top
probe -create -shm systolic_array_4x4_tb.c_out
probe -create -shm systolic_array_4x4_tb.dut.a_h
probe -create -shm systolic_array_4x4_tb.dut.b_v
probe -create -shm systolic_array_4x4_tb.dut.pe_acc

ida_probe -wave -wave_probe_args {systolic_array_4x4_tb systolic_array_4x4_tb.dut}

puts "probes_array.tcl: array boundary and mesh probed into waves.shm"
