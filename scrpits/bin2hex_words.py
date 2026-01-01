#!/usr/bin/env python3
import sys

def main():
    if len(sys.argv) != 3:
        print("Usage: bin2hex_words.py <input.bin> <output_hex>")
        return 2

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    data = open(in_path, "rb").read()
    # pad to 4 bytes
    if len(data) % 4 != 0:
        data += b"\x00" * (4 - (len(data) % 4))

    with open(out_path, "w") as f:
        for i in range(0, len(data), 4):
            w = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
            f.write(f"{w:08x}\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
