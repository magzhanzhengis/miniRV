#!/usr/bin/env bash
set -euo pipefail

WS="/usr/riscv64-linux-gnu/include/bits/wordsize.h"
ST="/usr/riscv64-linux-gnu/include/gnu/stubs.h"

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: run as root: sudo $0"
    exit 1
  fi
}

backup_once() {
  local f="$1"
  if [[ -f "$f" && ! -f "${f}.bak" ]]; then
    cp -a "$f" "${f}.bak"
    echo "Backup created: ${f}.bak"
  fi
}

patch_wordsize() {
  if ! [[ -f "$WS" ]]; then
    echo "ERROR: not found: $WS"
    exit 1
  fi

  if grep -q 'rv32i-based targets are not supported' "$WS"; then
    echo "Patching $WS ..."
    perl -0777 -i -pe 's/#else\s*\n\s*#\s*error\s*"rv32i-based targets are not supported"\s*\n/#else\n# define __WORDSIZE_TIME64_COMPAT32 0\n/s' "$WS"
  else
    echo "OK: $WS already patched (or toolchain already supports it)."
  fi
}

patch_stubs() {
  if ! [[ -f "$ST" ]]; then
    echo "ERROR: not found: $ST"
    exit 1
  fi

  if grep -qE '^[[:space:]]*#include[[:space:]]+<gnu/stubs-ilp32\.h>' "$ST"; then
    echo "Patching $ST ..."
    sed -i 's/^[[:space:]]*#include[[:space:]]\+<gnu\/stubs-ilp32\.h>/\/\/#include <gnu\/stubs-ilp32.h>/' "$ST"
  else
    echo "OK: $ST already patched (or no ilp32 include line present)."
  fi
}

main() {
  need_root
  backup_once "$WS"
  backup_once "$ST"
  patch_wordsize
  patch_stubs
  echo "Done."
}

main "$@"
