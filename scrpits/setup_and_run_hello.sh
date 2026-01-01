#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TP="$REPO_ROOT/third_party"

AM_DIR="$TP/abstract-machine"
AMK_DIR="$TP/am-kernels"

# --- 0) Dependencies (Ubuntu/Debian)
install_deps() {
  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y \
      git make python3 python3-pip \
      g++ build-essential \
      verilator \
      g++-riscv64-linux-gnu
  else
    echo "WARN: apt not found. Install deps manually: git, make, python3, verilator, g++-riscv64-linux-gnu"
  fi
}

# --- 1) Clone third-party repos (auto-clone)
clone_repos() {
  mkdir -p "$TP"
  if [[ ! -d "$AM_DIR/.git" ]]; then
    git clone https://github.com/NJU-ProjectN/abstract-machine "$AM_DIR"
  else
    echo "OK: abstract-machine already cloned"
  fi

  if [[ ! -d "$AMK_DIR/.git" ]]; then
    git clone https://github.com/NJU-ProjectN/am-kernels "$AMK_DIR"
  else
    echo "OK: am-kernels already cloned"
  fi
}

# --- 2) Apply the slide toolchain header patch (may be needed on some machines)
patch_toolchain_headers() {
  sudo "$REPO_ROOT/scripts/patch_riscv_toolchain_headers.sh" || true
}

# --- 3) Patch abstract-machine for UART + ebreak halt
patch_abstract_machine() {
  "$REPO_ROOT/scripts/patch_abstract_machine_minirv.sh" "$AM_DIR"
}

# --- 4) Build your Verilator sim
build_sim() {
  cd "$REPO_ROOT"

  verilator -Wall \
    -Wno-DECLFILENAME -Wno-UNUSED \
    --top-module miniRV_top \
    --Mdir obj_dir \
    --cc \
    rtl/miniRV.sv \
    rtl/alu.sv \
    rtl/control.sv \
    rtl/instr_fields.sv \
    rtl/pcrom_dpi.sv \
    rtl/ram_dpi.sv \
    rtl/regfile.sv \
    rtl/writeback.sv \
    --exe tb.cpp mem_dpi.cpp \
    --build \
    -o VminiRV_top

  echo "Built simulator: $REPO_ROOT/obj_dir/VminiRV_top"
}
# --- 5) Build hello (minirv-npc) and run on your sim
build_and_run_hello() {
  export AM_HOME="$AM_DIR"
  export NPC_HOME="$REPO_ROOT"

  cd "$AMK_DIR/kernels/hello"
  make ARCH=minirv-npc clean || true
  make ARCH=minirv-npc

  BIN="$AMK_DIR/kernels/hello/build/hello-minirv-npc.bin"
  if [[ ! -f "$BIN" ]]; then
    echo "ERROR: hello bin not found: $BIN"
    exit 1
  fi

  # Convert to program_mem.hex in repo root for your mem_dpi.cpp loader
  "$REPO_ROOT/scripts/bin2hex_words.py" "$BIN" "$REPO_ROOT/program_mem.hex"
  echo "Wrote: $REPO_ROOT/program_mem.hex"

  # Run sim (UART prints to stderr because mem_write uses fputc(..., stderr))
  cd "$REPO_ROOT"
  ./obj_dir/VminiRV_top
}

main() {
  install_deps
  clone_repos
  patch_toolchain_headers
  patch_abstract_machine
  build_sim
  build_and_run_hello
}

main "$@"
