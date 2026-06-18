#!/bin/tcsh -f
#==============================================================================
# run_array_gui.csh — Verisium GUI for systolic_array_4x4_tb
# Usage: ./run_array_gui.csh   (from sim/, with DISPLAY set)
# At xcelium> prompt, type:  run
#==============================================================================

set script_dir = `dirname $0`
cd $script_dir

if ( ! -d results/logs ) mkdir -p results/logs
set log_file = results/logs/systolic_array_4x4_tb_gui.log

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

echo "Launching Verisium GUI: systolic_array_4x4_tb"
echo "Log: ${log_file}"

xrun -64bit -sv -f filelist_array.f -top systolic_array_4x4_tb \
  -access +rwc -linedebug \
  -input probes_array.tcl \
  -gui -debug_opts verisium_interactive \
  -timescale 1ns/1ps \
  -l ${log_file}
