#!/usr/bin/env python3
"""
uart_test.py — send one UART message to the Basys 3 accelerator.

Protocol (see rtl/host_uart_cmd.sv). This script sends a single byte by default
('S' = start compute). Watch LED3 on the board for a brief flash when the byte
is received.

Usage:
  pip install pyserial
  python uart_test.py --port COM3          # Windows (check Device Manager)
  python uart_test.py --port /dev/ttyUSB0  # Linux

  python uart_test.py --port COM3 --byte A   # send 'A' instead
  python uart_test.py --port COM3 --byte 0x53
"""

import argparse
import sys
import time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    print("pyserial is required:  pip install pyserial")
    sys.exit(1)

BAUD_RATE = 115200
DEFAULT_BYTE = 0x53  # 'S' — start compute


def parse_byte(s: str) -> int:
    """Parse 'S', 'A', or '0x53' into an integer byte value."""
    s = s.strip()
    if s.startswith("0x") or s.startswith("0X"):
        val = int(s, 16)
    elif len(s) == 1:
        val = ord(s)
    else:
        raise ValueError(f"expected one character or 0xNN, got {s!r}")
    if not 0 <= val <= 255:
        raise ValueError(f"byte out of range: {val}")
    return val


def list_serial_ports() -> None:
    ports = list(list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for p in ports:
        print(f"  {p.device}  {p.description}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Send one UART byte to the systolic array FPGA."
    )
    parser.add_argument(
        "--port",
        help="Serial port (e.g. COM3 on Windows, /dev/ttyUSB0 on Linux)",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=BAUD_RATE,
        help=f"Baud rate (default {BAUD_RATE})",
    )
    parser.add_argument(
        "--byte",
        default="S",
        help="Byte to send: one character (S, A, ...) or hex (0x53). Default: S",
    )
    parser.add_argument(
        "--list-ports",
        action="store_true",
        help="List serial ports and exit",
    )
    args = parser.parse_args()

    if args.list_ports:
        list_serial_ports()
        return

    if not args.port:
        print("Error: --port is required (or use --list-ports).")
        list_serial_ports()
        sys.exit(1)

    try:
        byte_val = parse_byte(args.byte)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    print(f"Opening {args.port} @ {args.baud} baud ...")
    with serial.Serial(args.port, args.baud, timeout=2) as ser:
        time.sleep(0.1)  # let USB-UART settle after open
        ser.reset_input_buffer()

        payload = bytes([byte_val])
        ser.write(payload)
        ser.flush()
        ch = chr(byte_val) if 32 <= byte_val < 127 else "?"
        print(f"Sent 1 byte: 0x{byte_val:02X} ('{ch}')")

        # FPGA may reply (e.g. 'D' after start, 'E' if busy). Wait briefly.
        time.sleep(0.05)
        rsp = ser.read(16)
        if rsp:
            print(f"Received {len(rsp)} byte(s):", " ".join(f"0x{b:02X}" for b in rsp))
            if rsp[0] == 0x44:
                print("  -> 'D' compute done")
            elif rsp[0] == 0x45:
                print("  -> 'E' error (e.g. start while busy)")
        else:
            print("No response yet (normal for a lone 'A'/'B'/'C' without follow-up bytes)")

    print("Done.")


if __name__ == "__main__":
    main()
