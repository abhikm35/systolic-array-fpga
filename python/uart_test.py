#!/usr/bin/env python3
"""
uart_test.py
Host-side UART test script for systolic array accelerator on Basys 3.
Requires pyserial when fully implemented (not required for skeleton run).
"""

# TODO: import serial  # pip install pyserial — enable when UART is implemented

# Basys 3 USB-UART defaults (verify against your port)
SERIAL_PORT = "/dev/ttyUSB0"  # Linux; use COMx on Windows
BAUD_RATE = 115200


def main() -> None:
    # TODO: Open serial port with pyserial.
    # ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)

    # TODO: Send A matrix elements over UART (define host protocol).
    # TODO: Send B matrix elements over UART.
    # TODO: Send start command to trigger compute on FPGA.
    # TODO: Read C result bytes from UART.
    # TODO: Compare received C against golden_model.py expected output.

    print("uart_test.py: TODO — implement pyserial host communication")
    print(f"  Planned port: {SERIAL_PORT} @ {BAUD_RATE} baud")


if __name__ == "__main__":
    main()
