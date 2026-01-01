#include <cstdint>
#include <vector>
#include <iostream>
#include <fstream>

#define OP_ADD 0x00
#define OP_LI 0x02
#define OP_BNER0 0x03

using namespace std;
class GoldRV {

private:
    // Architectural state
    uint32_t pc_;

    // Instruction memory (raw bytes)
    
    
    public:
    uint32_t regs_[16];
    vector<uint32_t> ram;
    vector<uint32_t> rom;

    GoldRV()
    {
        pc_ = 0;
    }
    // Load program as raw instruction bytes (little-endian 16-bit words)
    void LoadInstructions(const string filename)
    {
        ifstream file(filename);
        

        if (!file.is_open()) {
            std::cerr << "Error: cannot open " << filename << "\n";
            return;
        }

        string line;
        while (getline(file, line)) {
            uint32_t instr = 0;
            try {
                instr = static_cast<uint32_t>(stoul(line, nullptr, 16));
            } catch (...) {
                cerr << "Invalid hex line: " << line << "\n";
                continue;
            }
            rom.push_back(instr);
            ram.push_back(instr);
            // printf("Loaded instruction: 0x%08x\n", instr);
        }
    
    }


    // Set program counter (instruction index)
    void SetPC(uint32_t pc)
    {
        pc_ = pc;
    }

    int GetPC() 
    {
        return int(pc_);
    } 

    uint32_t GetInstruction()
    {
        return rom[pc_ >> 2];
    }

    // Execute one instruction at PC
    // Returns true if a register was written
    bool ExecuteInstruction(uint32_t& written_reg, uint32_t& written_value)
    {
        bool wrote = false;
        uint32_t instruction = rom[pc_>>2];

        uint8_t opcode =    (instruction & 0x7f);
        uint8_t rd =        (instruction >> 7) & 0x1f;
        uint8_t funct3 =    (instruction >> 12) & 0x7;
        uint8_t rs1 =       (instruction >> 15) & 0x1f;    
        uint8_t rs2 =       (instruction >> 20) & 0x1f;
        uint8_t funct7 =    (instruction >> 25) & 0x7f;

        int32_t imm_i =    (int32_t)instruction >> 20;
        uint32_t imm_u =    (instruction >> 12) << 12;
        int32_t imm_s = ((instruction >> 25) << 5) |
                ((instruction >> 7) & 0x1F);
        imm_s = (imm_s << 20) >> 20; // sign-extend 12-bit

        uint32_t temp = pc_ + 4;    
        
        switch(opcode){
            case 0b0110111: // LUI
                if (rd != 0)
                    regs_[rd] = imm_u;
                wrote = true;
                written_reg = rd;
                written_value = regs_[rd];
                break;
            case 0b1100111: // JALR
                temp = pc_ + 4;
                pc_ = ((regs_[rs1] + imm_i) & ~1) - 4;
                if (rd != 0)
                    regs_[rd] = temp;
                
                // for (int i = 0; i < 16; i++) {
                //     printf("REG[%d]: 0x%08x\n", i, regs_[i]);
                // }
                // printf("PC ON JALR: %d\n", pc_);
                // printf("REGS JALR: %d\n", regs_[rs1]);
                // printf("RS! JALR: %d\n", rs1);
                // printf("IMM_I JALR: %d\n", imm_i);
                wrote = true;
                written_reg = rd;
                written_value = regs_[rd];
                break;
            case 0b0010011: // ADDI
                if (rd != 0)
                    regs_[rd] = regs_[rs1] + imm_i;
                wrote = true;
                written_reg = rd;
                written_value = regs_[rd];
                break;
            case 0b0110011: // ADD
                if (rd != 0)
                    regs_[rd] = regs_[rs1] + regs_[rs2];
                wrote = true;
                written_reg = rd;
                written_value = regs_[rd];
                break;
            case 0b0000011: 
                if (funct3 == 0b010) // LW
                {
                    if (rd != 0) 
                        regs_[rd] = ram[(regs_[rs1] + imm_i)>>2];
                    wrote = true;
                    written_reg = rd;
                    written_value = regs_[rd];
                }                
                else //LBU
                {
                    uint32_t addr = regs_[rs1] + imm_i;
                    uint8_t byte = (ram[addr>>2] >> ((addr & 0x3) * 8)) & 0xFF;
                    // printf("LBU: addr=0x%08x, byte=0x%02x\n", addr, byte);
                    // printf("Instruction: 0x%08x\n", instruction);
                    if(rd != 0)
                        regs_[rd] = byte;
                    
                    wrote = true;
                    written_reg = rd;
                    written_value = regs_[rd];
                }
                break;
            case 0b0100011:
                if (funct3 == 0b000) //SB
                {
                    uint32_t addr = regs_[rs1] + imm_s;
                    uint32_t& word = ram[addr>>2];
                    uint8_t byte = regs_[rs2] & 0xFF;
                    word &= ~(0xFF << ((addr & 0x3) * 8));
                    word |= (byte << ((addr & 0x3) * 8));
                }
                else //SW
                {
                    uint32_t word = regs_[rs2];
                    // printf("SW: addr=0x%08x, word=0x%08x\n", regs_[rs1] + imm_s, word);
                    ram[(regs_[rs1] + imm_s)>>2] = word;
                }
                break;
        }
         
        pc_ += 4;
        return wrote;
    }

};
int main(int argc, char** argv) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " program.hex [max_steps]\n";
        return 1;
    }

    string filename = argv[1];
    int max_steps = (argc >= 3) ? stoi(argv[2]) : 1000;

    GoldRV cpu;

    // IMPORTANT: initialize regs to 0 (your class doesn't do it!)
    for (int i = 0; i < 16; i++) cpu.regs_[i] = 0;

    cpu.LoadInstructions(filename);
    cpu.SetPC(0);

    for (int step = 0; step < max_steps; step++) {
        uint32_t pc = cpu.GetPC();
        uint32_t instr = cpu.GetInstruction();

        uint32_t rd = 0, val = 0;
        bool wrote = cpu.ExecuteInstruction(rd, val);

        // Print one line per executed instruction:
        // step pc instr [optional reg write]
        cout << step
             << " pc=0x" << hex << (uint32_t)pc
             << " instr=0x" << hex << instr;

        if (wrote && rd != 0) {
            cout << " x" << dec << rd
                 << "=0x" << hex << val;
        }
        cout << "\n";
    }

    return 0;
}


