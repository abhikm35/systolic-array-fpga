# Architecture — systolic-array-fpga

## Overview

This project implements a **4×4 output-stationary systolic array** accelerator for fixed-point matrix multiplication **C = A × B** on a Digilent Basys 3 FPGA (Artix-7).

## Systolic Array Topology

```
        b_top[0]  b_top[1]  b_top[2]  b_top[3]
            |         |         |         |
a_left[0] → PE[0,0] → PE[0,1] → PE[0,2] → PE[0,3]
            ↓         ↓         ↓         ↓
a_left[1] → PE[1,0] → PE[1,1] → PE[1,2] → PE[1,3]
            ↓         ↓         ↓         ↓
a_left[2] → PE[2,0] → PE[2,1] → PE[2,2] → PE[2,3]
            ↓         ↓         ↓         ↓
a_left[3] → PE[3,0] → PE[3,1] → PE[3,2] → PE[3,3]
```

- **A** values stream **left to right** across each row.
- **B** values stream **top to bottom** down each column.
- Each **PE** performs multiply-accumulate and holds one **output-stationary** element of **C**.

## Processing Element (`pe.sv`)

| Parameter   | Default | Description              |
|-------------|---------|--------------------------|
| DATA_WIDTH  | 16      | Signed operand width     |
| ACC_WIDTH   | 32      | Accumulator width        |

Per cycle (when enabled): `acc += a_in * b_in`, with `a_out = a_in` and `b_out = b_in`.

## Data Path (Planned)

| Block                  | Role                                              |
|------------------------|---------------------------------------------------|
| `matrix_bram.sv`       | Store A, B, and C matrix elements                 |
| `systolic_controller`  | FSM: LOAD → COMPUTE → DRAIN → WRITEBACK → DONE   |
| `systolic_array_4x4`   | 16 PEs in output-stationary mesh                  |
| `uart_rx` / `uart_tx`  | Host command and result transfer (115200 baud)    |
| `accelerator_top`      | Top-level integration for Basys 3                 |

## Fixed-Point Considerations

- Operands are signed 16-bit fixed-point (scaling TBD).
- Products accumulate into 32-bit registers.
- Overflow / rounding policy to be defined during verification.

## Host Interface (Future)

UART protocol (TBD) for loading matrices, starting compute, and reading results. Python `golden_model.py` and `uart_test.py` provide reference and host-side testing.
