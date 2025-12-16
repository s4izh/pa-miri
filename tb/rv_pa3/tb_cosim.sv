module tb (
    input logic clk,
    input logic reset_n
);

    import "DPI-C" function int cosim_dpi_init(string rom_path, string sram_path, int pc_reset, int pc_xcpt);
    import "DPI-C" function int unsigned cosim_dpi_step(output int unsigned pc, output int unsigned ins, output int unsigned rd);

    parameter int DEFAULT_TIMEOUT_CYCLES = 1000;

    parameter int XLEN = 32;
    parameter int IALEN = 12;
    parameter int DALEN = 12;
    parameter int MEM_DLEN = 32;

    logic [IALEN-1:0]        imem_addr_o;
    logic [MEM_DLEN-1:0]     imem_data_i;

    logic [DALEN-1:0]        dmem_addr_o;
    logic [MEM_DLEN-1:0]     dmem_data_o;
    logic [MEM_DLEN/8-1:0]   dmem_byte_en_o;
    logic                    dmem_we_o;
    logic [MEM_DLEN-1:0]     dmem_data_i;

    soc #(
        .XLEN(XLEN),
        .IALEN(IALEN),
        .DALEN(DALEN),
        .MEM_DLEN(MEM_DLEN)
    ) dut (.*);

    rom #(
        .DATA_WIDTH(XLEN),
        .ADDR_WIDTH(IALEN)
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
        .fetch_ins_i(dut.hart0_inst.imem_data_i),

        // For other stages, we trust the valid bit of the pipeline register
        // "If s_1f_q.valid is high, then there is a real instruction in Decode"
        .valid_d_i(dut.hart0_inst.s_1f_q.valid),
        .valid_e_i(dut.hart0_inst.s_2d_q.valid),
        .valid_m_i(dut.hart0_inst.s_3e_q.valid),
        .valid_w_i(dut.hart0_inst.s_4m_q.valid)
    );

    int TIMEOUT_CYCLES;
    initial begin
        int ret;
        string rom_file, sram_file;

        // Load rom
        if ($value$plusargs("ROM_FILE=%s", rom_file)) begin
            $readmemh(rom_file, imem.mem);
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

        // Init DPI-C
        ret = cosim_dpi_init(rom_file, sram_file, 0'h00001000, 0'h00002000);
        case (ret)
            -1: begin
                $error("Failed to init cosim_dpi");
                $fatal();
            end
            default: begin
                $display("Correclty initialized cosim_dpi");
            end
        endcase

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
    assign ins = dut.hart0_inst.imem_data_i;

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
            if (dut.hart0_inst.s_4m_q.valid && dut.hart0_inst.s_4m_q.ins != 0'h00000033) begin
                int unsigned pc, ins, rd, next_pc;
                string disasm;
                int errors;

                next_pc = cosim_dpi_step(pc, ins, rd);

                errors = 0;
                if (pc != dut.hart0_inst.s_4m_q.pc) begin
                    $display("ERROR - Different PC: {dut: 0x%08x, iss: 0x%08x}", dut.hart0_inst.s_4m_q.pc, pc);
                    errors += 1;
                end

                if (ins != dut.hart0_inst.s_4m_q.ins) begin
                    $display("ERROR - Different instruction: {dut: 0x%08x, iss: 0x%08x}", dut.hart0_inst.s_4m_q.ins, ins);
                    errors += 1;
                end

                if (dut.hart0_inst.s_5w_d.is_wb
                    && '0 != dut.hart0_inst.s_5w_d.rd_addr
                    && rd != dut.hart0_inst.s_5w_d.rd_data) begin
                    $display("ERROR - Different rd: {dut: 0x%08x, iss: 0x%08x}", dut.hart0_inst.s_5w_d.rd_data, rd);
                    errors += 1;
                end

                // disasm_rv32i(data.hart0_inst.s_4m_q.ins);
                disasm = rv32_util_pkg::disasm_rv32i(ins);
                if (errors == 0) begin
                    $display("CORRECT - 0x%08x: %s", pc, disasm);
                end else begin
                    $display("INCORRECT - 0x%08x: %s", pc, disasm);
                    $fatal(1, "Test FAILED! Due to %0d errors.", errors);
                end
            end
        end
    end

endmodule
