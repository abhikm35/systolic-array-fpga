# Verification Plan — systolic-array-fpga

## 1. PE Unit Tests (`pe_tb.sv`)

- [ ] Reset clears accumulator to zero.
- [ ] `a_out` forwards `a_in`, `b_out` forwards `b_in` each cycle.
- [ ] MAC sequence: `2×3 + 4×5 + 1×7 = 33`.
- [ ] `clear` pulse resets accumulator mid-sequence.
- [ ] Signed fixed-point edge cases (negative operands, zero).

**Milestone:** Complete before array integration.

## 2. 4×4 Array Tests (`systolic_array_4x4_tb.sv`)

- [ ] Identity matrix: `I × I = I`.
- [ ] Known small integer matrices (compare against golden model).
- [ ] A propagates horizontally, B propagates vertically (waveform checks).
- [ ] `clear` resets all PE accumulators.

## 3. Fixed-Point Arithmetic Tests

- [ ] Scaling and overflow behavior documented and tested.
- [ ] Compare RTL `c_out` against `numpy` golden model with matching fixed-point semantics.
- [ ] Rounding / truncation policy validated.

## 4. BRAM Sequencing Tests

- [ ] Write then read back A and B elements.
- [ ] Address mapping (row-major) correct for 4×4 matrices.
- [ ] Controller read schedule matches systolic load pattern.

## 5. UART / System-Level Tests

- [ ] `uart_rx` / `uart_tx` bit-level loopback (future).
- [ ] `accelerator_top_tb`: command parse → load → compute → readback.
- [ ] `uart_test.py` end-to-end against hardware or UART loopback model.

## 6. Python Golden Model Comparison

- [ ] `golden_model.py` produces reference C for test matrices.
- [ ] Export hex/decimal vectors for simulation ($readmemh or direct drive).
- [ ] Automated diff: RTL vs golden within fixed-point tolerance.

## Regression Strategy

| Phase | Focus                          | Pass Criteria                    |
|-------|--------------------------------|----------------------------------|
| M1    | `pe` + `pe_tb`                 | MAC test passes                  |
| M2    | `systolic_array_4x4` + tb      | Identity test passes             |
| M3    | Controller + BRAM              | Load/compute sequence correct    |
| M4    | UART + top                     | Host protocol round-trip         |

## Tools

- Simulator: Vivado XSim, Verilator, or Questa (TBD).
- Synthesis: Vivado for Artix-7 XC7A35T (Basys 3).
- Python 3 + NumPy for reference; pyserial for hardware tests (later).
