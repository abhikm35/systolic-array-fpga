# systolic-array-fpga

A 4×4 **output-stationary systolic array** accelerator for fixed-point matrix multiplication, targeting the **Digilent Basys 3** FPGA (Xilinx Artix-7).

## Project Overview

This design performs **C = A × B** on 4×4 matrices using a mesh of processing elements (PEs). Matrix operands stream through the array — A left-to-right, B top-to-bottom — while each PE accumulates one element of the result matrix C.

Host communication (planned) uses the Basys 3 USB-UART bridge at 115200 baud.

## Current Milestone

**M1 — Processing Element:** Implement and verify `rtl/pe.sv` with `tb/pe_tb.sv`.

Target test: `2×3 + 4×5 + 1×7 = 33` (MAC accumulation).

All other modules are skeleton placeholders with TODO sections.

## Planned Architecture

```
Host (Python) ──UART──► accelerator_top
                           ├── uart_rx / uart_tx
                           ├── matrix_bram (A, B, C)
                           ├── systolic_controller (FSM)
                           └── systolic_array_4x4 (16 × pe)
```

See [docs/architecture.md](docs/architecture.md) for topology and data-flow details.

## Repository Layout

```
systolic-array-fpga/
├── rtl/           SystemVerilog sources
├── tb/            Testbenches
├── python/        Golden model and UART host scripts
├── constraints/   Basys 3 XDC (skeleton)
└── docs/          Architecture and verification plan
```

## Build & Simulation

### PE unit test (first milestone)

```bash
# Example with XSim (adjust paths/tooling as needed)
cd systolic-array-fpga
xvlog rtl/pe.sv tb/pe_tb.sv
xelab pe_tb -debug typical
xsim pe_tb -R
```

### Golden model (skeleton)

```bash
cd python
python3 golden_model.py
```

### Synthesis (future)

1. Uncomment pin assignments in `constraints/basys3.xdc`.
2. Add `accelerator_top` as top module in Vivado.
3. Target device: `xc7a35tcpg236-1` (Basys 3).

## Verification

See [docs/verification_plan.md](docs/verification_plan.md) for phased test strategy from PE unit tests through system-level UART checks.

## Resume Relevance

- **Digital design:** Systolic array architecture, output-stationary dataflow, FSM control.
- **FPGA:** Artix-7 synthesis, BRAM inference, timing constraints, Basys 3 I/O.
- **Verification:** Layered UVM-style test plan, Python golden-model cross-check.
- **Systems:** UART host protocol, embedded accelerator bring-up.

## License

TBD
