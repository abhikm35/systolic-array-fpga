#!/usr/bin/env python3
"""
golden_model.py
Reference model for 4x4 fixed-point matrix multiply C = A @ B.
Used to generate expected results for RTL simulation and UART tests.
"""

import numpy as np

DATA_WIDTH = 16
N = 4


def print_matrix(name: str, m: np.ndarray) -> None:
    print(f"{name}:")
    print(m)
    print()


def main() -> None:
    # Identity test — matches systolic_array_4x4_tb load_identity()
    A_eye = np.eye(N, dtype=np.int32)
    B_eye = np.eye(N, dtype=np.int32)
    C_eye = A_eye @ B_eye
    print("=== Identity: C = I @ I ===")
    print_matrix("Expected C", C_eye)

    # Small dense test — matches systolic_array_4x4_tb load_small_test()
    A = np.array([
        [1, 2, 0, 0],
        [3, 4, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
    ], dtype=np.int32)
    B = np.array([
        [5, 6, 0, 0],
        [7, 8, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
    ], dtype=np.int32)
    C = A @ B
    print("=== Small 4x4 test ===")
    print_matrix("A", A)
    print_matrix("B", B)
    print_matrix("Expected C", C)

    # TODO: Later export test vectors to files (e.g., a_vectors.hex, b_vectors.hex).


if __name__ == "__main__":
    main()
