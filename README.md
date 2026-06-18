# systolic-array-fpga

A 4×4 **output-stationary systolic array** accelerator for fixed-point matrix multiplication, targeting the **Digilent Basys 3** FPGA (Xilinx Artix-7 `xc7a35tcpg236-1`).

The design computes **C = A × B** on 4×4 matrices (16-bit signed operands, 32-bit accumulators). A host PC loads operands over **USB-UART** at 115200 baud, starts compute, and reads back the result matrix.

**Status:** RTL simulation and hardware bring-up are complete. Both system tests (identity I×I and small 4×4) pass in simulation and on the Basys 3 board.

## Architecture

```
Host (Python) ──UART 115200──► accelerator_top
                                  ├── uart_rx / uart_tx
                                  ├── host_uart_cmd (protocol parser)
                                  ├── matrix_memories (A, B, C BRAM)
                                  ├── systolic_controller (FSM)
                                  └── systolic_array_4x4 (16 × pe)
```

See [docs/architecture.md](docs/architecture.md) for topology and data-flow details.

## Repository layout

```
systolic-array-fpga/
├── rtl/              SystemVerilog sources (top: accelerator_top.sv)
├── tb/               Testbenches (unit → system)
├── sim/              Xcelium run scripts and file lists
├── python/           Golden model and UART host tests
├── constraints/      Basys 3 pin constraints (basys3.xdc)
└── docs/             Architecture and verification plan
```

## UART host protocol

All multi-byte fields are **little-endian**. Matrix elements use **row-major** addressing: `addr = row * 4 + col` (0..15).

| Host → FPGA | Bytes | Action |
|-------------|-------|--------|
| `'A'` (0x41) | addr, data_lo, data_hi | Write 16-bit A element |
| `'B'` (0x42) | addr, data_lo, data_hi | Write 16-bit B element |
| `'S'` (0x53) | — | Start compute |
| `'C'` (0x43) | addr | Read 32-bit C element |

| FPGA → host | Meaning |
|-------------|---------|
| `'D'` (0x44) | Compute finished |
| `'E'` (0x45) | Error (e.g. start while busy) |

Protocol implementation: `rtl/host_uart_cmd.sv`

---

## Simulation (GT server / Xcelium)

Simulation uses **Cadence Xcelium** on the GT research servers. Source the tool environment first:

```bash
source /tools/software/cadence/setup.csh
cd sim
```

### Milestone testbenches

| Script | Test | Notes |
|--------|------|-------|
| `./run_pe.sh` | PE unit test | Fast |
| `./run_array.sh` | 4×4 array | Fast |
| `./run_bram.sh` | Matrix BRAM | Fast |
| `./run_controller.sh` | Controller + array | Fast |
| `./run_accelerator.sh` | **Full system UART test** | Slow (~UART bit timing) |
| `./run_uart_rx.sh` / `./run_uart_tx.sh` | UART modules | Fast |

The system test runs two cases (same as hardware):

1. **Identity I×I** — A and B are 4×4 identity; expect C = I  
2. **Small 4×4** — dense 2×2 blocks in the upper-left and lower-right

Pass criteria: log contains `ALL TESTS PASSED`.

```bash
./run_accelerator.sh
grep 'ALL TESTS PASSED' results/logs/accelerator_top_tb.log
```

### Waveform debug (Verisium GUI)

Requires X11/FastX (`DISPLAY` set):

```bash
./run_accelerator_gui.csh          # full test (slow)
./run_accelerator_gui.csh +UART_DEBUG   # preload BRAM, one C read, then $stop
```

At the `xcelium>` prompt, type `run`. See `probes_accelerator.tcl` for useful signals.

### Golden model (Python, optional)

```bash
cd python
python3 golden_model.py
```

Prints expected C matrices for the identity and small tests.

---

## FPGA synthesis (Windows + Vivado)

Target: **Digilent Basys 3**, part `xc7a35tcpg236-1`, top module **`accelerator_top`**.

1. Clone/pull the repo on the Windows machine.
2. Create a Vivado project (or open an existing one).
3. Add all files from `rtl/` and `constraints/basys3.xdc`.
4. Set **top module** to `accelerator_top`.
5. Run synthesis → implementation → generate bitstream.
6. Connect Basys 3 via USB; program the device.

**Tips**

- Add RTL sources **by reference** from the repo path (don't copy into the project) so `git pull` stays in sync with the GT server.
- Reset is the **center button** (`btnC`), active-high in RTL.
- UART is the on-board FTDI bridge; no extra wiring needed.

---

## Hardware test (Windows + Python)

Install pyserial, connect the board, and run the host test script:

```powershell
pip install pyserial
cd python
python uart_test.py
```

Default port is **COM3** (override with `--port COM4`). List ports with `--list-ports`.

### What the script does

1. Loads A and B over UART (paced byte timing — see troubleshooting below)
2. Sends `'S'`, waits for `'D'`
3. Reads all 16 C elements (4 bytes each, signed 32-bit LE)
4. Compares against the golden model and prints A, B, C, and expected C

### Options

```powershell
python uart_test.py                      # both tests (default)
python uart_test.py --test identity      # identity I×I only
python uart_test.py --test small         # small 4×4 only
python uart_test.py --ping               # quick link test (send 'S' only)
python uart_test.py --quiet              # PASS/FAIL only, no matrix printout
python uart_test.py --port COM4
```

Expected output ends with:

```
ALL TESTS PASSED
```

Each test takes roughly **4–5 seconds** (UART transfer dominates; printing matrices is instant).

**Before testing:** press **btnC** (center button) to reset the FPGA if a previous run left the command parser in a bad state.

---

## Development workflow

Typical split used for this project:

| Task | Where |
|------|-------|
| Edit RTL, run Xcelium sim | GT server (Cursor + SSH) |
| Synthesis, program Basys 3 | Windows PC (Vivado) |
| UART hardware tests | Windows PC (`python/uart_test.py`) |
| Sync code | `git push` (server) → `git pull` (Windows) |

Do **not** commit simulation artifacts (`sim/xcelium.d/`, etc.) — they break Windows checkout (see troubleshooting).

---

## Troubleshooting & bugs fixed

Issues encountered during bring-up and how they were resolved.

### 1. Testbench: C read timeout / wrong values (`tb/accelerator_top_tb.sv`)

**Symptoms:** Simulation timed out waiting for UART bytes 2–3 of a C read, or read values like `0xFFFF0001` instead of `1`.

**Cause:** Four separate `uart_recv_byte` calls were too slow for the 4-byte burst the DUT sends. A fixed-delay `uart_recv_word` mis-sampled the upper bytes as idle `0xFF`.

**Fix:** `uart_recv_word` resyncs on the start bit of **each** byte (same timing as `uart_recv_byte` in a loop).

---

### 2. RTL: only ~2 bytes transmitted on C read (`rtl/host_uart_cmd.sv`)

**Symptoms:** Testbench (and hardware) timed out on byte 2 of every `'C'` reply.

**Cause:** In `CMD_TX_BYTE`, the FSM issued a new byte whenever `!tx_busy`, incrementing `tx_byte_idx` every idle cycle instead of waiting for the previous byte to finish.

**Fix:** Added `tx_busy_q` and `tx_done = tx_busy_q & ~tx_busy`; send the next byte only on entry (`tx_byte_idx == 0`) or after `tx_done`.

---

### 3. Constraints: wrong UART pins (`constraints/basys3.xdc`)

**Symptoms:** No UART communication on hardware (or garbage), while simulation passed.

**Cause:** Early skeleton XDC used incorrect pins (e.g. C4/D4).

**Fix:** Matched Digilent **Basys-3-Master.xdc**: `uart_rx` → **B18**, `uart_tx` → **A18**, plus correct clock (W5), btnC (U18), and bitstream config.

---

### 4. Git: Windows clone/checkout failed

**Symptoms:** `git clone` or `git pull` on Windows failed on paths containing `:` (e.g. under `sim/xcelium.d/`).

**Cause:** Xcelium simulation artifacts were committed from the GT server.

**Fix:** Added `.gitignore` for `sim/xcelium.d/`, `sim/ida.db/`, `sim/results/`, etc. Removed tracked artifacts from the repo.

---

### 5. Python host: timeout waiting for `'D'` after matrix load (`python/uart_test.py`)

**Symptoms:** `--ping` (single `'S'`) worked and returned `'D'`, but the full identity test timed out after loading A and B.

**Cause:** Python sent UART bytes back-to-back (multi-byte `write()` bursts). On real USB-UART hardware this could desync the FPGA command parser — `'S'` was consumed as a stray data byte, compute never started, no `'D'` was sent.

**Fix:** Pace **one byte at a time** with ~2 UART frame times of delay (matching testbench `uart_send_byte` bit timing). Added a short pause before `'S'`. Rebuild bitstream optional; the Python fix alone resolved the issue on hardware.

---

### 6. RTL: `'D'` reply reliability (`rtl/host_uart_cmd.sv`)

**Symptoms:** Occasional missed done notification under load.

**Fix:** Send `'D'` directly from `CMD_WAIT_DONE` when `ctrl_done` pulses, instead of relying only on the `CMD_IDLE` path (where an incoming RX byte could defer the reply).

---

### 7. LEDs appear off during UART tests

**Symptoms:** LEDs don't visibly light during host tests.

**Cause:** `led[0..3]` mirror short pulses (`ctrl_done`, `ctrl_busy`, `tx_busy`, `rx_valid`) at 100 MHz — far too brief for the human eye.

**Workaround:** Use the UART `'D'` response as the pass/fail indicator. (Optional future improvement: latch `ctrl_done` onto an LED.)

---

## Verification summary

| Milestone | Testbench | Status |
|-----------|-----------|--------|
| M1 — PE | `pe_tb` | Pass |
| M2 — 4×4 array | `systolic_array_4x4_tb` | Pass |
| M3 — Controller + BRAM | `controller_array_tb` | Pass |
| M4 — Full system UART | `accelerator_top_tb` | Pass |
| Hardware | `python/uart_test.py` | Pass (identity + small 4×4) |

See [docs/verification_plan.md](docs/verification_plan.md) for the full phased strategy.

## License

TBD
