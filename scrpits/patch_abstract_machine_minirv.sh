#!/usr/bin/env bash
set -euo pipefail

AM_HOME="${1:-}"
if [[ -z "$AM_HOME" ]]; then
  echo "Usage: $0 <path-to-abstract-machine>"
  exit 1
fi

TRM="$AM_HOME/am/src/riscv/npc/trm.c"
if [[ ! -f "$TRM" ]]; then
  echo "ERROR: not found: $TRM"
  exit 1
fi

# Backup once
if [[ ! -f "$TRM.bak" ]]; then
  cp -a "$TRM" "$TRM.bak"
fi

# 1) Patch putch(char ch) body (idempotent)
# Replace the whole function if it exists.
perl -0777 -i -pe '
  if ($ARGV =~ /trm\.c$/) {
    s/void\s+putch\s*\(\s*char\s+ch\s*\)\s*\{.*?\n\}/void putch(char ch) {\n  volatile unsigned char *uart = (volatile unsigned char *)0x10000000ul;\n  *uart = (unsigned char)ch;\n}\n/s;
  }
' "$TRM"

# 2) Patch halt(int code): inline asm ebreak then loop (idempotent)
perl -0777 -i -pe '
  if ($ARGV =~ /trm\.c$/) {
    s/void\s+halt\s*\(\s*int\s+code\s*\)\s*\{\s*while\s*\(\s*1\s*\)\s*;\s*\}/void halt(int code) {\n  asm volatile(\"mv a0, %0; ebreak\" :: \"r\"(code));\n  while (1);\n}\n/s;
  }
' "$TRM"

echo "Patched: $TRM"
