#!/bin/bash
#==============================================================================
# run_pe.sh — compile and run pe_tb in batch (no GUI)
#
# Usage:
#   ./sim/run_pe.sh
#
# For Verisium GUI, use:  ./sim/run_pe_gui.csh
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/results/logs"
LOG_FILE="${LOG_DIR}/pe_tb.log"

mkdir -p "${LOG_DIR}"

if ! command -v xrun >/dev/null 2>&1; then
  echo "ERROR: xrun not found in PATH."
  echo "In tcsh, run:  source /tools/software/cadence/setup.csh"
  echo "Then re-run:     ./sim/run_pe.sh"
  exit 1
fi

cd "${SCRIPT_DIR}"

echo "Running pe_tb (batch) -> ${LOG_FILE}"

xrun -64bit -sv -f filelist.f -top pe_tb \
  -access +rwc -timescale 1ns/1ps \
  -l "${LOG_FILE}"

echo "--- Summary ---"
grep -E 'cycle [0-9]:|ALL TESTS PASSED|FAILED|UVM_ERROR|\$error' "${LOG_FILE}" || true

if grep -q 'ALL TESTS PASSED' "${LOG_FILE}"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL (see ${LOG_FILE})"
  exit 1
fi
