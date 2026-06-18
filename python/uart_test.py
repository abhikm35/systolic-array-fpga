#!/usr/bin/env python3
"""
uart_test.py — host-side UART tests for the Basys 3 systolic array accelerator.

Protocol matches rtl/host_uart_cmd.sv and tb/accelerator_top_tb.sv.

Usage:
  pip install pyserial
  python uart_test.py                      # identity IxI test (default)
  python uart_test.py --ping               # send one 'S' byte only
  python uart_test.py --port COM4
  python uart_test.py --list-ports
"""

import argparse
import struct
import sys
import time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    print("pyserial is required:  pip install pyserial")
    sys.exit(1)

N = 4
BAUD_RATE = 115200
SERIAL_PORT = "COM3"

CMD_A = ord("A")
CMD_B = ord("B")
CMD_S = ord("S")
CMD_C = ord("C")
RSP_D = ord("D")
RSP_E = ord("E")


def row_major_addr(row: int, col: int) -> int:
    return row * N + col


def identity_matrix():
    """4x4 identity — same as load_identity() in accelerator_top_tb.sv."""
    m = [[0] * N for _ in range(N)]
    for i in range(N):
        m[i][i] = 1
    return m


def list_serial_ports() -> None:
    ports = list(list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for p in ports:
        print(f"  {p.device}  {p.description}")


class AcceleratorHost:
    """Minimal pyserial driver for host_uart_cmd protocol."""

    def __init__(self, ser: serial.Serial):
        self.ser = ser

    def send_byte(self, val: int) -> None:
        self.ser.write(bytes([val & 0xFF]))
        self.ser.flush()

    def read_byte(self, timeout: float = 2.0) -> int:
        old = self.ser.timeout
        self.ser.timeout = timeout
        data = self.ser.read(1)
        self.ser.timeout = old
        if len(data) != 1:
            raise TimeoutError("timeout waiting for UART byte from FPGA")
        return data[0]

    def load_a(self, addr: int, value: int) -> None:
        u16 = value & 0xFFFF
        self.send_byte(CMD_A)
        self.send_byte(addr & 0x0F)
        self.send_byte(u16 & 0xFF)
        self.send_byte((u16 >> 8) & 0xFF)

    def load_b(self, addr: int, value: int) -> None:
        u16 = value & 0xFFFF
        self.send_byte(CMD_B)
        self.send_byte(addr & 0x0F)
        self.send_byte(u16 & 0xFF)
        self.send_byte((u16 >> 8) & 0xFF)

    def start_and_wait_done(self) -> None:
        self.send_byte(CMD_S)
        rsp = self.read_byte(timeout=5.0)
        if rsp == RSP_D:
            print("compute done: received 'D'")
        elif rsp == RSP_E:
            raise RuntimeError("FPGA returned 'E' (error — start while busy?)")
        else:
            raise RuntimeError(f"expected 'D' (0x44), got 0x{rsp:02X}")

    def read_c(self, addr: int) -> int:
        self.send_byte(CMD_C)
        self.send_byte(addr & 0x0F)
        old = self.ser.timeout
        self.ser.timeout = 2.0
        raw = self.ser.read(4)
        self.ser.timeout = old
        if len(raw) != 4:
            raise TimeoutError(
                f"timeout reading C addr {addr} (got {len(raw)}/4 bytes)"
            )
        return struct.unpack("<i", raw)[0]

    def load_matrix_a(self, mat) -> None:
        for i in range(N):
            for j in range(N):
                self.load_a(row_major_addr(i, j), mat[i][j])

    def load_matrix_b(self, mat) -> None:
        for i in range(N):
            for j in range(N):
                self.load_b(row_major_addr(i, j), mat[i][j])

    def read_matrix_c(self):
        c = [[0] * N for _ in range(N)]
        for i in range(N):
            for j in range(N):
                c[i][j] = self.read_c(row_major_addr(i, j))
        return c


def run_identity_test(host: AcceleratorHost) -> bool:
    """Full IxI test — mirrors accelerator_top_tb run_one_test('identity IxI')."""
    a = identity_matrix()
    b = identity_matrix()
    c_exp = identity_matrix()

    print("Loading A (identity)...")
    host.load_matrix_a(a)
    print("Loading B (identity)...")
    host.load_matrix_b(b)
    print("Starting compute...")
    host.start_and_wait_done()
    print("Reading C matrix...")
    c_got = host.read_matrix_c()

    errors = 0
    for i in range(N):
        for j in range(N):
            if c_got[i][j] != c_exp[i][j]:
                print(
                    f"  FAIL c[{i}][{j}]={c_got[i][j]}, expected {c_exp[i][j]}"
                )
                errors += 1

    if errors == 0:
        print("identity IxI: C matrix PASS")
        return True

    print(f"identity IxI: FAILED with {errors} error(s)")
    return False


def run_ping(host: AcceleratorHost, byte_val: int) -> None:
    ch = chr(byte_val) if 32 <= byte_val < 127 else "?"
    host.send_byte(byte_val)
    print(f"Sent 1 byte: 0x{byte_val:02X} ('{ch}')")
    time.sleep(0.05)
    old = host.ser.timeout
    host.ser.timeout = 2.0
    rsp = host.ser.read(16)
    host.ser.timeout = old
    if rsp:
        print(f"Received {len(rsp)} byte(s):", " ".join(f"0x{b:02X}" for b in rsp))
        if rsp[0] == RSP_D:
            print("  -> 'D' compute done")
        elif rsp[0] == RSP_E:
            print("  -> 'E' error")
    else:
        print("No response (normal for lone A/B/C without follow-up bytes)")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="UART host tests for systolic array FPGA."
    )
    parser.add_argument(
        "--port", default=SERIAL_PORT, help=f"Serial port (default {SERIAL_PORT})"
    )
    parser.add_argument(
        "--baud", type=int, default=BAUD_RATE, help=f"Baud rate (default {BAUD_RATE})"
    )
    parser.add_argument(
        "--ping",
        action="store_true",
        help="Send a single 'S' byte only (quick link test)",
    )
    parser.add_argument(
        "--list-ports", action="store_true", help="List serial ports and exit"
    )
    args = parser.parse_args()

    if args.list_ports:
        list_serial_ports()
        return

    print(f"Opening {args.port} @ {args.baud} baud ...")
    with serial.Serial(args.port, args.baud, timeout=2) as ser:
        time.sleep(0.1)
        ser.reset_input_buffer()
        host = AcceleratorHost(ser)

        if args.ping:
            run_ping(host, CMD_S)
            print("Done.")
            return

        ok = run_identity_test(host)
        print("Done.")
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
