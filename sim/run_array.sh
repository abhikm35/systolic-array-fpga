#!/bin/bash
#==============================================================================
# run_array.sh — compile and run systolic_array_4x4_tb (batch, no GUI)
#
# Usage:
#   source /tools/software/cadence/setup.csh   # tcsh, before this script
#   ./run_array.sh
#
# For Verisium GUI:  ./run_array_gui.csh
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/results/logs"
LOG_FILE="${LOG_DIR}/systolic_array_4x4_tb.log"

mkdir -p "${LOG_DIR}"

if ! command -v xrun >/dev/null 2>&1; then
  echo "ERROR: xrun not found in PATH."
  echo "In tcsh, run:  source /tools/software/cadence/setup.csh"
  echo "Then re-run:     ./run_array.sh"
  exit 1
fi

cd "${SCRIPT_DIR}"

echo "Running systolic_array_4x4_tb (batch) -> ${LOG_FILE}"

xrun -64bit -sv -f filelist_array.f -top systolic_array_4x4_tb \
  -access +rwc -timescale 1ns/1ps \
  -l "${LOG_FILE}"

echo "--- Summary ---"
grep -E 'PASS|FAILED|\$error|C matrix' "${LOG_FILE}" || true

if grep -q 'ALL TESTS PASSED' "${LOG_FILE}"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL (see ${LOG_FILE})"
  exit 1
fi
