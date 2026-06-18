#!/bin/bash
#==============================================================================
# run_controller.sh — compile and run controller_array_tb (batch)
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/results/logs"
LOG_FILE="${LOG_DIR}/controller_array_tb.log"

mkdir -p "${LOG_DIR}"

if ! command -v xrun >/dev/null 2>&1; then
  echo "ERROR: xrun not found in PATH."
  echo "In tcsh, run:  source /tools/software/cadence/setup.csh"
  exit 1
fi

cd "${SCRIPT_DIR}"

echo "Running controller_array_tb (batch) -> ${LOG_FILE}"

xrun -64bit -sv -f filelist_controller.f -top controller_array_tb \
  -access +rwc -timescale 1ns/1ps \
  -l "${LOG_FILE}"

echo "--- Summary ---"
grep -E 'PASS|FAILED|\$error|c_out' "${LOG_FILE}" || true

if grep -q 'ALL TESTS PASSED' "${LOG_FILE}"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL (see ${LOG_FILE})"
  exit 1
fi
