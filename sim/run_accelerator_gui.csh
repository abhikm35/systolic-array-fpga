#!/bin/tcsh -f
#==============================================================================
# run_accelerator_gui.csh — Verisium GUI for accelerator_top_tb
#
# Usage (from sim/, with DISPLAY set for X11/FastX):
#   ./run_accelerator_gui.csh
#
# Fast UART handshake debug (preload BRAM, one C read, then Verilog $stop):
#   ./run_accelerator_gui.csh +UART_DEBUG
#
# At xcelium> prompt, type:  run
#
# Then zoom to the first C-read reply (host sends 'C' + addr, FPGA replies 4 bytes).
# See probes_accelerator.tcl for signal list and what to watch.
#
# NOTE: Full test is slow (~UART bit timing). Pass +UART_DEBUG to preload BRAM,
# run compute + one C read, then Verilog pause for waveform inspection.
#==============================================================================

set script_dir = `dirname $0`
cd $script_dir

if ( ! -d results/logs ) mkdir -p results/logs
set log_file = results/logs/accelerator_top_tb_gui.log

# Forward optional plusargs (e.g. +UART_DEBUG) from command line to xrun.
set xrun_plusargs = ($argv)

if ( ! $?DISPLAY ) then
  echo "ERROR: DISPLAY is not set — use FastX or X11."
  exit 1
endif
if ( "$DISPLAY" == "" ) then
  echo "ERROR: DISPLAY is empty."
  exit 1
endif

source /tools/software/cadence/setup.csh

set verisium_root = ""
if ( -x /tools/software/cadence/verisiumdbg/latest/tools/indago/bin/verisium_debug ) then
  set verisium_root = /tools/software/cadence/verisiumdbg/latest
else if ( -x /tools/software/cadence/verisiumdbg/26.05.081/tools/indago/bin/verisium_debug ) then
  set verisium_root = /tools/software/cadence/verisiumdbg/26.05.081
else
  foreach v ( /tools/software/cadence/verisiumdbg/*/tools/indago/bin/verisium_debug )
    if ( -x "$v" ) then
      set verisium_root = `dirname $v:h:h:h`
      break
    endif
  end
endif

if ( "$verisium_root" == "" ) then
  echo "ERROR: Verisium Debug not found."
  exit 1
endif

setenv VERISIUM_DEBUG_ROOT ${verisium_root}
set path = ( ${verisium_root}/tools/bin ${verisium_root}/tools/indago/bin $path )
rehash

echo "Launching Verisium GUI: accelerator_top_tb"
if ( $#xrun_plusargs > 0 ) then
  echo "Plusargs: ${xrun_plusargs}"
endif
echo "Log: ${log_file}"
echo "At xcelium> prompt, type:  run"
echo ""
echo 'Tip: ./run_accelerator_gui.csh +UART_DEBUG  (fast: one C-read then Verilog pause)'
echo ""
echo "Key signals (see probes_accelerator.tcl):"
echo "  uart_tx / uart_rx"
echo "  u_host_cmd.state, tx_byte_idx, c_read_val"
echo "  u_host_cmd.tx_valid, tx_data, tx_busy, tx_done"
echo "  u_uart_tx.valid, data, busy, state"
echo ""
echo "Zoom to: first CMD_TX_BYTE after a 'C' read (4-byte LE reply)"
echo ""

xrun -64bit -sv -f filelist_accelerator.f -top accelerator_top_tb \
  -access +rwc -linedebug \
  -input probes_accelerator.tcl \
  -gui -debug_opts verisium_interactive \
  -timescale 1ns/1ps \
  ${xrun_plusargs} \
  -l ${log_file}
