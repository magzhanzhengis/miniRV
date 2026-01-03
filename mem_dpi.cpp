// mem_dpi.cpp  (drop-in replacement)
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include "svdpi.h"

// 128MB (matches recommendation)
static constexpr uint32_t MEM_SIZE = 128u * 1024u * 1024u;
static uint8_t memory[MEM_SIZE];

static bool loaded = false;

// program starts at 0x8000_0000
static constexpr uint32_t MEM_BASE = 0x80000000u;

// Return true if [addr, addr+3] is inside RAM window
static inline bool in_ram(uint32_t addr) {
  if (addr < MEM_BASE) return false;
  uint32_t o = addr - MEM_BASE;
  return (o + 4u) <= MEM_SIZE;
}

static void load_hex_words(const char *filename) {
  std::FILE *f = std::fopen(filename, "r");
  if (!f) {
    std::perror("ERROR opening program_mem.hex");
    std::fprintf(stderr, "Tried: %s\n", filename);
    std::exit(1);
  }

  std::memset(memory, 0, sizeof(memory));

  unsigned x;
  uint32_t i = 0;
  while (i < MEM_SIZE / 4 && std::fscanf(f, "%x", &x) == 1) {
    uint32_t p = i * 4;
    memory[p + 0] = (uint8_t)(x & 0xff);
    memory[p + 1] = (uint8_t)((x >> 8) & 0xff);
    memory[p + 2] = (uint8_t)((x >> 16) & 0xff);
    memory[p + 3] = (uint8_t)((x >> 24) & 0xff);
    i++;
  }

  std::fclose(f);
  std::fprintf(stderr, "DPI: loaded %u words from %s at 0x%08x\n", i, filename, MEM_BASE);
}

static void ensure_loaded() {
  if (loaded) return;
  load_hex_words("program_mem.hex");   // file in miniRV_test root
  loaded = true;
}

// Read 32-bit word (aligned). If address is in "device/unmapped" space, return 0.
extern "C" uint32_t mem_read(uint32_t raddr) {
  ensure_loaded();
  uint32_t a = raddr & ~0x3u;
  static int dbg = 0;
// if (dbg < 10) {
//   std::fprintf(stderr, "DPI mem_read addr = 0x%08x\n", raddr);
//   dbg++;
// }

  // device/unmapped region (below MEM_BASE or above RAM): return 0, don't abort
  if (!in_ram(a)) return 0;

  uint32_t p = a - MEM_BASE;
  return (uint32_t)memory[p + 0]
      | ((uint32_t)memory[p + 1] << 8)
      | ((uint32_t)memory[p + 2] << 16)
      | ((uint32_t)memory[p + 3] << 24);
}

// Write with byte mask. If address is in "device/unmapped" space, ignore.
// extern "C" void mem_write(uint32_t waddr, uint32_t wdata, uint8_t wmask) {
//   if (waddr == 0x10000000) {
//     fputc(wdata & 0xff, stderr);
//     return;
//   }
//   ensure_loaded();
//   uint32_t a = waddr & ~0x3u;

//   // device/unmapped region: ignore writes (Task 3 bring-up behavior)
//   if (!in_ram(a)) return;

//   uint32_t p = a - MEM_BASE;

//   if (wmask & 0x1) memory[p + 0] = (uint8_t)(wdata & 0xff);
//   if (wmask & 0x2) memory[p + 1] = (uint8_t)((wdata >> 8) & 0xff);
//   if (wmask & 0x4) memory[p + 2] = (uint8_t)((wdata >> 16) & 0xff);
//   if (wmask & 0x8) memory[p + 3] = (uint8_t)((wdata >> 24) & 0xff);
// }
extern "C" void mem_write(uint32_t waddr, uint32_t wdata, uint8_t wmask) {

  // UART TX MMIO is the 32-bit word at 0x1000_0000 (byte stores may hit any lane)
  // UART TX MMIO occupies the word at 0x1000_0000
extern "C" void mem_write(uint32_t waddr, uint32_t wdata, uint8_t wmask) {
  if (waddr == 0x10000000u) {      // write to UART (slide)
    fputc(wdata & 0xff, stderr);   // slide: stderr
    return;
  }

  ensure_loaded();
  uint32_t a = waddr & ~0x3u;
  if (!in_ram(a)) return;
  uint32_t p = a - MEM_BASE;

  if (wmask & 0x1) memory[p + 0] = (uint8_t)(wdata & 0xff);
  if (wmask & 0x2) memory[p + 1] = (uint8_t)((wdata >> 8) & 0xff);
  if (wmask & 0x4) memory[p + 2] = (uint8_t)((wdata >> 16) & 0xff);
  if (wmask & 0x8) memory[p + 3] = (uint8_t)((wdata >> 24) & 0xff);
}



  ensure_loaded();
  uint32_t a = waddr & ~0x3u;
  if (!in_ram(a)) return;
  uint32_t p = a - MEM_BASE;

  if (wmask & 0x1) memory[p + 0] = (uint8_t)(wdata & 0xff);
  if (wmask & 0x2) memory[p + 1] = (uint8_t)((wdata >> 8) & 0xff);
  if (wmask & 0x4) memory[p + 2] = (uint8_t)((wdata >> 16) & 0xff);
  if (wmask & 0x8) memory[p + 3] = (uint8_t)((wdata >> 24) & 0xff);
}

