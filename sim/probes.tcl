# Waveform probes — loaded before sim via: xrun ... -input probes.tcl
# Records PE testbench and DUT signals into waves.shm for Verisium.

database -open waves -shm -default

# Testbench controls
probe -create -shm pe_tb.clk
probe -create -shm pe_tb.rst
probe -create -shm pe_tb.clear
probe -create -shm pe_tb.a_in
probe -create -shm pe_tb.b_in
probe -create -shm pe_tb.a_out
probe -create -shm pe_tb.b_out
probe -create -shm pe_tb.acc_out

# DUT internals
probe -create -shm pe_tb.dut.acc_reg

# Push probed signals into the Verisium waveform pane
ida_probe -wave -wave_probe_args {pe_tb pe_tb.dut}

puts "probes.tcl: pe_tb and pe DUT probed into waves.shm"
