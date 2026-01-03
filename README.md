

## miniRV — Minimal RISC-V Compatible CPU System

**miniRV** is a **single-hart, single-core, 32-bit RISC-V–compatible processor system** designed as a **strict, minimal subset of RV32E**.
It is intended for **education, architectural understanding, and co-simulation**, not performance or completeness.

The system is built to run **freestanding C programs** through the **AbstractMachine (AM)** runtime and to interact with the outside world **only through memory-mapped I/O**.

---

## Architectural Scope

### Processor Model

* **Single hart** (one hardware thread)
* **Single core**
* **In-order execution**
* **No speculation, no pipelines**
* Deterministic behavior under arbitrary memory latency

This design ensures that **every architectural state change is visible and explainable**.

---

## Register File

* **16 general-purpose registers**: `x0`–`x15` (RV32E)
* Each register is **32 bits wide**
* `x0` is **hard-wired to zero**
* No CSR registers
* No floating-point or vector registers

This reduced register file simplifies decoding and datapath design while remaining RISC-V compliant.

---

## Supported Instruction Set (Strict Subset)

miniRV supports **only the instructions required to run basic C programs**:

| Category           | Instructions  |
| ------------------ | ------------- |
| Integer arithmetic | `add`, `addi` |
| Upper immediate    | `lui`         |
| Memory load        | `lw`, `lbu`   |
| Memory store       | `sw`, `sb`    |
| Control flow       | `jalr`        |
| Termination        | `ebreak`      |

All instructions:

* Use **standard RV32 encodings**
* Follow **two’s-complement arithmetic**
* Use **sign-extended immediates** as defined by RISC-V

All **unsupported opcodes are architecturally illegal**.

---

## Memory Model

miniRV follows a **Von Neumann architecture**:

* **Single, unified address space**
* **Byte-addressable**
* Instruction fetches and data accesses share the same memory interface

### Address Space

* **32-bit flat address space**
* Program counter starts at:

```
PC = 0x80000000
```

* Upper address region → main memory (≥ 128 MB)
* Lower address region → memory-mapped I/O

There is:

* No virtual memory
* No MMU
* No caches

---

## Memory Access Mechanism

All memory interactions are performed via a **timing-aware system bus abstraction**:

* CPU is the **only master**
* Memory and devices are **slaves**
* Accesses use explicit:

  * address
  * write enable
  * write data
  * byte mask

Instruction fetch and data access:

* May have **arbitrary latency**
* Architectural state updates only when responses are valid
* No new instruction is issued while a request is outstanding

This ensures **architectural correctness independent of timing**.

---

## Memory-Mapped I/O (MMIO)

miniRV interacts with devices **only via MMIO**.

### UART (Task 1)

* **Transmit register** mapped at:

```
0x10000000
```

* Writing a byte to this address prints a character
* Implemented in the simulator (`mem_dpi.cpp`)
* Used by the AM runtime function `putch()`

There is:

* No interrupt support
* No receive FIFO
* Output-only UART

---

## Program Execution Environment

miniRV runs **without an operating system**.

### Runtime

* Uses **AbstractMachine (AM)** as a minimal runtime layer
* Programs are:

  * statically linked
  * freestanding
* Entry point is fixed by AM
* Stack is initialized before `main()`

### Program Termination (Task 4)

* Program exit is defined by executing:

```
ebreak
```

* Exit code is passed via register `a0`
* The simulator observes `ebreak` and terminates execution

This replaces OS syscalls and ensures deterministic termination.

---

## Simulation and Verification

miniRV is intended to be run via **Verilator** with:

* SystemVerilog RTL
* DPI-C memory and device models
* A C++ testbench

### Co-Simulation Rules

* UART writes are **skipped in the reference model**
* Only architectural state is compared
* Device side effects are treated as observable outputs, not memory state

---

## Design Philosophy

miniRV is intentionally **minimal**:

* No interrupts
* No exceptions
* No privilege modes
* No atomics
* No compressed instructions
* No branch prediction
* No speculation
* No caches

This ensures that:

* Every instruction can be traced
* Every bug is explainable
* The ISA–microarchitecture boundary is clear



HOW TO OUTPUT:
```
Hello, AbstractMachine!
```


---

# miniRV – UART, ebreak, and run flow 

This repository contains a minimal RV32-style CPU (`miniRV`) connected to the **AbstractMachine (AM)** software stack.
The goal is to:

* Implement a simple UART behavior model
* Terminate simulation using `ebreak`
* Run programs via `make ARCH=minirv-npc run`

At the end, the `hello` program prints:

```
Hello, AbstractMachine!
```

---

## 0. Prerequisites (exactly as slides assume)

Install required tools:

```bash
sudo apt update
sudo apt install -y git verilator g++ make python3
```

---

## 1. Repository structure (important mental model)

```
miniRV/
├── rtl/                # SystemVerilog CPU
├── tb.cpp              # Verilator testbench
├── mem_dpi.cpp         # Memory + UART DPI model (Task 1)
├── obj_dir/            # Verilator build output (generated)
├── deps/
│   ├── abstract-machine/
│   └── am-kernels/
```

* **UART** is implemented in `mem_dpi.cpp`
* **ebreak handling** is implemented in AM (`trm.c`) + testbench
* **hello program** comes from `am-kernels`

---

## 2. Clone dependencies (AbstractMachine + kernels)

From the repo root:

```bash
mkdir -p deps
cd deps

git clone https://github.com/NJU-ProjectN/abstract-machine
git clone https://github.com/NJU-ProjectN/am-kernels
```

---

## 3. Set `AM_HOME` (required by AM build system)

From repo root:

```bash
export AM_HOME=$PWD/deps/abstract-machine
```

(Optional, but recommended so you don’t repeat it every time):

```bash
echo "export AM_HOME=$PWD/deps/abstract-machine" >> ~/.bashrc
```

---

## 4.  UART behavior model (slide-exact)

### Where UART is implemented

**File**: `mem_dpi.cpp`
**Rule from slides**:

> Insert a condition statement when accessing memory

### Required UART logic (exact behavior)

```cpp
extern "C" void mem_write(uint32_t waddr, uint32_t wdata, uint8_t wmask) {
  if (waddr == 0x10000000u) {        // UART TX MMIO
    fputc(wdata & 0xff, stderr);     // slide: output to stderr
    return;
  }

  // normal RAM write path
}
```

**Important notes (based on common mistakes):**

* UART prints to **`stderr`**, not `stdout`
* If you print cycle traces, they go to `stdout` and will hide UART output unless redirected
* This is why later we use `1>/dev/null`

---

## 5. Task 4 – Finish simulation using `ebreak`

### Modify AM runtime

**File**:
`deps/abstract-machine/am/src/riscv/npc/trm.c`

Add / ensure this implementation:

```c
void halt(int code) {
  asm volatile("mv a0, %0; ebreak" :: "r"(code));
  while (1);
}
```

### What this does (conceptual, not optional)

* `a0` carries exit code
* `ebreak` is observed by the simulator
* Simulation terminates deterministically

---

## 6. Build the Verilator simulator (once)

From repo root:

```bash
rm -rf obj_dir

verilator -Wall \
  -Wno-DECLFILENAME \
  -Wno-UNUSED \
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
```

After this, you must have:

```bash
obj_dir/VminiRV_top
```

---

## 7. – Build the `hello` program (AM side)

Go to hello kernel:

```bash
cd deps/am-kernels/kernels/hello
```

Build **native reference** (sanity check):

```bash
make ARCH=native run
```

Expected output:

```
Hello, AbstractMachine!
```

---

## 8. Build `hello` for miniRV

```bash
make ARCH=minirv-npc
```

This produces:

```
build/hello-minirv-npc.bin
```

---

## 9. Load program and run on miniRV (IMPORTANT COMMAND)

From **repo root**:

```bash
./obj_dir/VminiRV_top 1>/dev/null
```

### Why this command matters

* `stdout` → contains cycle-by-cycle trace → **discarded**
* `stderr` → UART output → **visible**

---

## 10. Expected final output

You should see:

```
Hello, AbstractMachine!
mainargs = ''.
```

followed by clean termination via `ebreak`.

---

## 11. Common pitfalls (already solved here)

| Problem               | Cause                    | Solution                    |
| --------------------- | ------------------------ | --------------------------- |
| “UART doesn’t work”   | UART prints to `stderr`  | Use `1>/dev/null`           |
| Only newline printed  | Hard to see among traces | Redirect stdout             |
| Simulator never exits | Missing `ebreak`         | Task 4                      |
| `make run` says TODO  | npc.mk not implemented   | Use direct binary execution |
| VSCode red squiggles  | IntelliSense only        | Ignore (build is correct)   |

---

## 12. One-line verification (copy-paste test)

From repo root:

```bash
./obj_dir/VminiRV_top 1>/dev/null
```

If you see:

```
Hello, AbstractMachine!
```

---

### End of README
