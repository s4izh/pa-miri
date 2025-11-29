module konata_tracer #(
    parameter int XLEN = 32,
    parameter string LOG_PREFIX = "konata_output"
)(
    input logic clk,
    input logic reset_n,
    input logic stall_i,

    // HARDWARE HOOKS
    // we look at the VALID bits coming out of each pipeline register.
    // if the hardware says valid=1, we track it. If valid=0, it's a bubble.
    input logic valid_f_i, // !noop
    input logic valid_d_i, // s_1f_q.valid
    input logic valid_e_i, // s_2d_q.valid
    input logic valid_m_i, // s_3e_q.valid
    input logic valid_w_i, // s_4m_q.valid

    // we need the fetch info to describe the instruction
    input logic [XLEN-1:0] fetch_pc_i,
    input logic [31:0]     fetch_ins_i
);

    longint unsigned id_counter = 1;

    // a simple shift register to carry IDs down the pipeline
    // id_pipe[0] corresponds to Fetch
    // id_pipe[1] corresponds to Decode
    // id_pipe[2] corresponds to Execute
    // id_pipe[3] corresponds to Memory
    // id_pipe[4] corresponds to Writeback
    // id_pipe[5] is used to flag the cycle in which the ins is retired
    longint unsigned id_pipe [5:0];

    // track the previous valid instruction to calculate retirement latency
    longint unsigned last_retired_id;

    // Init kanata format
    //   - Header
    //   - Location of first instruction
    initial begin
        $display("%s:Kanata\t0004", LOG_PREFIX);
        $display("%s:C=\t0", LOG_PREFIX);
    end

    always @(posedge clk) begin
        $display("%s:C\t1", LOG_PREFIX);
        if (!reset_n) begin
            id_pipe <= '{default:0};
            id_counter <= 1;
        end else if (!stall_i) begin
            // 1. Shift the IDs down the pipe (Synchronous with HW pipeline regs)
            id_pipe[5] <= id_pipe[4];
            id_pipe[4] <= id_pipe[3];
            id_pipe[3] <= id_pipe[2];
            id_pipe[2] <= id_pipe[1];
            id_pipe[1] <= id_pipe[0];

            // 2. Insert new ID at Fetch if valid
            // If the processor is flushing (valid_f_i is low), we insert a 0 (bubble)
            if (valid_f_i) begin
                id_pipe[0] <= id_counter;

                // Log the creation of this instruction immediately
                // fetch : time : pc : global_id : 0 : asm
                $display("%s:I\t%0d\t%0t\t0",
                    LOG_PREFIX, id_counter, fetch_pc_i);
                $display("%s:L\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_counter, 0, disassemble_rv32i(fetch_ins_i));

                id_counter++;
            end else begin
                id_pipe[0] <= 0; // Bubble
            end
        end
    end

    // 3. Log Stage Transitions
    // We look at the ID that IS ENTERING the stage on this clock edge.
    // Since we use non-blocking assignments above, we check the OLD value of the previous stage.
    always @(posedge clk) begin
        if (reset_n && !stall_i) begin

            if (id_pipe[0] != 0)
                $display("%s:S\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_pipe[0], 0, "F");

            if (id_pipe[1] != 0 && valid_d_i)
                $display("%s:S\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_pipe[1], 0, "D");

            if (id_pipe[2] != 0 && valid_e_i)
                $display("%s:S\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_pipe[2], 0, "E");

            if (id_pipe[3] != 0 && valid_m_i)
                $display("%s:S\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_pipe[3], 0, "M");

            if (id_pipe[4] != 0 && valid_w_i)
                $display("%s:S\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_pipe[4], 0, "W");

            if (id_pipe[5] != 0)
                $display("%s:R\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_pipe[4], 0, 0);

        end
    end

    // Helper to convert register number → name (x0 → zero, x1 → ra, etc.)
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


    function automatic string disassemble_rv32i(logic [31:0] instr);
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

endmodule
