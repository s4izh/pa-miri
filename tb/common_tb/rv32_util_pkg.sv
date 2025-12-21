package rv32_util_pkg;
    // Helpers for instruction disassembly
    function automatic string regname(input [4:0] r);
        if (r == 0) return "zero";
        else if (r == 1) return "ra";
        else if (r == 2) return "sp";
        else if (r == 3) return "gp";
        else if (r == 4) return "tp";
        else if (r >= 5 && r <= 7)  return $sformatf("t%0d", r-5);
        else if (r >= 8 && r <= 15)  return $sformatf("s%0d", r-8);
        else if (r >= 16 && r <= 27) return $sformatf("a%0d", r-10);
        else                         return $sformatf("t%0d", r-28);
    endfunction

    function automatic string disasm_rv32i(logic [31:0] instr);
        string s;
        logic [6:0]  opcode = instr[6:0];
        logic [4:0]  rd     = instr[11:7];
        logic [2:0]  funct3 = instr[14:12];
        logic [4:0]  rs1    = instr[19:15];
        logic [4:0]  rs2    = instr[24:20];
        logic [6:0]  funct7 = instr[31:25];
        case (opcode)
            7'b0110111: s = $sformatf("lui   %s, 0x%05x", regname(rd), instr[31:12]);
            7'b0010111: s = $sformatf("auipc %s, 0x%05x", regname(rd), instr[31:12]);
            7'b1101111: begin
                logic signed [31:0] imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
                s = $sformatf("jal   %s, %0d", regname(rd), imm);
            end
            7'b1100111: begin
                logic signed [31:0] imm = {{20{instr[31]}}, instr[31:20]};
                s = $sformatf("jalr  %s, %0d(%s)", regname(rd), imm, regname(rs1));
            end
            7'b1100011: begin
                logic signed [31:0] imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
                case (funct3)
                    3'b000: s = $sformatf("beq   %s, %s, %0d", regname(rs1), regname(rs2), imm);
                    3'b001: s = $sformatf("bne   %s, %s, %0d", regname(rs1), regname(rs2), imm);
                    3'b100: s = $sformatf("blt   %s, %s, %0d", regname(rs1), regname(rs2), imm);
                    3'b101: s = $sformatf("bge   %s, %s, %0d", regname(rs1), regname(rs2), imm);
                    3'b110: s = $sformatf("bltu  %s, %s, %0d", regname(rs1), regname(rs2), imm);
                    3'b111: s = $sformatf("bgeu  %s, %s, %0d", regname(rs1), regname(rs2), imm);
                    default: s = "b??";
                endcase
            end
            7'b0000011: begin
                logic signed [31:0] imm = {{20{instr[31]}}, instr[31:20]};
                case (funct3)
                    3'b000: s = $sformatf("lb    %s, %0d(%s)", regname(rd), imm, regname(rs1));
                    3'b001: s = $sformatf("lh    %s, %0d(%s)", regname(rd), imm, regname(rs1));
                    3'b010: s = $sformatf("lw    %s, %0d(%s)", regname(rd), imm, regname(rs1));
                    3'b100: s = $sformatf("lbu   %s, %0d(%s)", regname(rd), imm, regname(rs1));
                    3'b101: s = $sformatf("lhu   %s, %0d(%s)", regname(rd), imm, regname(rs1));
                    default: s = "l??";
                endcase
            end
            7'b0100011: begin
                logic signed [31:0] imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                case (funct3)
                    3'b000: s = $sformatf("sb    %s, %0d(%s)", regname(rs2), imm, regname(rs1));
                    3'b001: s = $sformatf("sh    %s, %0d(%s)", regname(rs2), imm, regname(rs1));
                    3'b010: s = $sformatf("sw    %s, %0d(%s)", regname(rs2), imm, regname(rs1));
                    default: s = "s??";
                endcase
            end
            7'b0010011: begin
                logic [31:0] imm = {{20{instr[31]}}, instr[31:20]};
                case (funct3)
                    3'b000: s = $sformatf("addi  %s, %s, %0d", regname(rd), regname(rs1), imm);
                    3'b010: s = $sformatf("slti  %s, %s, %0d", regname(rd), regname(rs1), imm);
                    3'b011: s = $sformatf("sltiu %s, %s, %0d", regname(rd), regname(rs1), imm);
                    3'b100: s = $sformatf("xori  %s, %s, %0d", regname(rd), regname(rs1), imm);
                    3'b110: s = $sformatf("ori   %s, %s, %0d", regname(rd), regname(rs1), imm);
                    3'b111: s = $sformatf("andi  %s, %s, %0d", regname(rd), regname(rs1), imm);
                    3'b001: s = $sformatf("slli  %s, %s, %0d", regname(rd), regname(rs1), instr[24:20]);
                    3'b101: begin
                        if (funct7[5]) s = $sformatf("srai  %s, %s, %0d", regname(rd), regname(rs1), instr[24:20]);
                        else           s = $sformatf("srli  %s, %s, %0d", regname(rd), regname(rs1), instr[24:20]);
                    end
                    default: s = "???";
                endcase
            end
            7'b0110011: begin
                case ({funct7, funct3})
                    10'b0000000_000: s = $sformatf("add   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0100000_000: s = $sformatf("sub   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_001: s = $sformatf("sll   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_010: s = $sformatf("slt   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_011: s = $sformatf("sltu  %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_100: s = $sformatf("xor   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_101: s = $sformatf("srl   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0100000_101: s = $sformatf("sra   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_110: s = $sformatf("or    %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    10'b0000000_111: s = $sformatf("and   %s, %s, %s", regname(rd), regname(rs1), regname(rs2));
                    default:         s = "???";
                endcase
            end
            7'b1110011: begin
                if (instr == 32'h00000073) s = "ecall";
                else if (instr == 32'h00100073) s = "ebreak";
                else if (funct3 == 3'b000 && instr[31:20] == 12'h302) s = "mret";
                else s = "system";
            end

            default: s = $sformatf("unknown  0x%08x", instr);
        endcase
        return s;
    endfunction

endpackage
