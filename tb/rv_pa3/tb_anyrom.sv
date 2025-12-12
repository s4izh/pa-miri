module romX4 (
    input  logic [11:0]  addr_i,
    output logic [127:0] data_o
);
    localparam int NREG = 2 ** 12;
    reg [31:0] mem [NREG-1:0];
    assign data_o = {mem[addr_i+3], mem[addr_i+2], mem[addr_i+1], mem[addr_i]};
endmodule

module tb (
    input logic clk,
    input logic reset_n
);

    parameter int DEFAULT_TIMEOUT_CYCLES = 1000;

    parameter int XLEN = 32;
    parameter int IALEN = 12;
    parameter int DALEN = 12;
    parameter int IMEM_DLEN = 128;
    parameter int DMEM_DLEN = 32;

    logic [IALEN-1:0]        imem_addr_o;
    logic [IMEM_DLEN-1:0]    imem_data_i;

    logic [DALEN-1:0]        dmem_addr_o;
    logic [DMEM_DLEN-1:0]    dmem_data_o;
    logic [DMEM_DLEN/8-1:0]  dmem_byte_en_o;
    logic                    dmem_we_o;
    logic [DMEM_DLEN-1:0]    dmem_data_i;

    soc #(
        .XLEN(XLEN),
        .IALEN(IALEN),
        .DALEN(DALEN),
        .IMEM_DLEN(IMEM_DLEN),
        .DMEM_DLEN(DMEM_DLEN)
    ) dut (.*);

    romX4 #(
        // .DATA_WIDTH(IMEM_DLEN),
        // .ADDR_WIDTH(IALEN)
    ) imem (
        .addr_i(imem_addr_o),
        .data_o(imem_data_i)
    );

    sram #(
        .DATA_WIDTH(XLEN),
        .ADDR_WIDTH(DALEN)
    ) dmem (
        .clk,
        .addr_i(dmem_addr_o),
        .we_i(dmem_we_o),
        .byte_en_i(dmem_byte_en_o),
        .data_i(dmem_data_o),
        .data_o(dmem_data_i)
    );

    konata_tracer #(
        .LOG_PREFIX("konata_output")
    ) tracer (
        .clk(clk),
        .reset_n(reset_n),
        .stall_i(dut.hart0_inst.stall),

        // Fetch is valid if we are not inserting a bubble (noop)
        .valid_f_i(!dut.hart0_inst.noop),
        .fetch_pc_i(dut.hart0_inst.pc),
        .fetch_ins_i(dut.hart0_inst.s_1f_d.ins),

        // For other stages, we trust the valid bit of the pipeline register
        // "If s_1f_q.valid is high, then there is a real instruction in Decode"
        .valid_d_i(dut.hart0_inst.s_1f_q.valid),
        .valid_e_i(dut.hart0_inst.s_2d_q.valid),
        .valid_m_i(dut.hart0_inst.s_3e_q.valid),
        .valid_w_i(dut.hart0_inst.s_4m_q.valid)
    );

    int TIMEOUT_CYCLES;
    initial begin
        string rom_file, sram_file;

        // Load rom
        if ($value$plusargs("ROM_FILE=%s", rom_file)) begin
            $readmemh(rom_file, imem.mem);
            $display("Loaded instruction memory from '%s'", rom_file);
        end else begin
            $error("No ROM_FILE specified. Empty instruction memory");
        end

        // Load sram
        if ($value$plusargs("SRAM_FILE=%s", sram_file)) begin
            $readmemh(sram_file, dmem.mem);
            $display("Loaded data memory from '%s'", sram_file);
        end else begin
            $warning("No SRAM_FILE specified. Empty data memory.");
        end

        // Override default timeout cycles
        if ($value$plusargs("TIMEOUT_CYCLES=%d", TIMEOUT_CYCLES)) begin
            $display("Timeout set at %d cycles", TIMEOUT_CYCLES);
        end else begin
            TIMEOUT_CYCLES = DEFAULT_TIMEOUT_CYCLES;
            $warning("Timeout not set. Using default %d cycles", TIMEOUT_CYCLES);
        end
    end

    logic               tohost_written;
    logic [XLEN-1:0]    tohost_value;
    assign tohost_written = &{dmem_addr_o, dmem_we_o}; // and reduction
    assign tohost_value = dmem_data_o;

    logic [XLEN-1:0] ins;
    assign ins = dut.hart0_inst.s_1f_d.ins;

    int cycle_count = 0;
    always @(posedge clk) begin
        if (reset_n) begin
            ++cycle_count;
            if (tohost_written) begin
                if (tohost_value == 0) begin
                    $display("** SIMULATION PASSED **: 'tohost' was written with 0.");
                    $finish;
                end else begin
                    $fatal(1, "Test FAILED! Incorrect 'tohost' value. Expected 0, got %0d.", tohost_value);
                end
            end else if (cycle_count >= TIMEOUT_CYCLES) begin
                $fatal(1, "Test FAILED! Timeout reached (%0d cycles) without writing to 'tohost'.", TIMEOUT_CYCLES);
            end
        end
    end

    always @(posedge clk) begin
        if (reset_n) begin
            $display("--------------------------------------------------------------------------------");
            $display("TIME: %0t", $time);
            $display("=============================[ FETCH ]==============================");
            $display("PC          : 0x%h", dut.hart0_inst.pc);
            $display("Instruction : 0x%h", dut.hart0_inst.s_1f_d.ins);
            // $display("=============================[ DECODE ]=============================");
            // $display("rd          : x%0d (reg %0d)", dut.hart0_inst.rd_addr, dut.hart0_inst.rd_addr);
            // $display("rs1         : x%0d (reg %0d)", dut.hart0_inst.rs1_addr, dut.hart0_inst.rs1_addr);
            // $display("rs2         : x%0d (reg %0d)", dut.hart0_inst.rs2_addr, dut.hart0_inst.rs2_addr);
            // $display("Immediate   : 0x%h (%d)", dut.hart0_inst.immed, dut.hart0_inst.immed);
            // $display("=============================[ EXECUTE ]============================");
            // $display("rs1_data    : 0x%h", dut.hart0_inst.rs1_data);
            // $display("rs2_data    : 0x%h", dut.hart0_inst.rs2_data);
            // // $display("ALU Op1     : 0x%h (%s)", dut.hart0_inst.alu_op1, dut.hart0_inst.alu_op1_sel.name());
            // // $display("ALU Op2     : 0x%h (%s)", dut.hart0_inst.alu_op2, dut.hart0_inst.alu_op2_sel.name());
            // // $display("ALU Op      : %s", dut.hart0_inst.alu_op.name());
            // $display("ALU Result  : 0x%h", dut.hart0_inst.alu_result);
            // // $display("Branch?     : %s, Taken?=%b", dut.hart0_inst.compare_op.name(), dut.hart0_inst.taken_branch);
            // $display("=============================[ MEMORY ]=============================");
            // if (dut.hart0_inst.is_ld || dut.hart0_inst.is_st) begin
            //     $display("Memory Op   : %s", dut.hart0_inst.is_ld ? "LOAD" : "STORE");
            //     $display("Mem Address : 0x%h", dmem_addr_o);
            //     $display("Mem wr_en   : %b", dmem_we_o);
            //     $display("Mem wr_data : 0x%h", dmem_data_o);
            //     $display("Mem rd_data : 0x%h", dmem_data_i);
            //     // $display("Mem width   : %s", dut.hart0_inst.dmem_width_o.name());
            // end else begin
            //     $display("Memory Op   : ---");
            // end
            // $display("=============================[ WRITEBACK ]==========================");
            // $display("Writeback En: %b", dut.hart0_inst.is_wb);
            // if (dut.hart0_inst.is_wb) begin
            //     // $display("WB Data Src : %s", dut.hart0_inst.wb_sel.name());
            //     $display("WB Data     : 0x%h", dut.hart0_inst.rd_data);
            //     $display("WB Dest Reg : x%0d", dut.hart0_inst.rd_addr);
            // end
            // $display("=============================[ PC UPDATE ]==========================");
            // // $display("PC Select   : %s", dut.hart0_inst.pc_sel.name());
            // $display("--------------------------------------------------------------------------------\n");
        end
    end

endmodule
