module tb (
    input logic clk,
    input logic reset_n
);

    import "DPI-C" function int cosim_dpi_init(string rom_path, string sram_path, int unsigned pc_reset, int unsigned pc_xcpt, int unsigned mem_dlen);
    import "DPI-C" function int unsigned cosim_dpi_step(output int unsigned pc, output int unsigned ins, output int unsigned rd);

    parameter int DEFAULT_TIMEOUT_CYCLES = 1000;

    parameter int XLEN = 32;
    parameter int MEM_ALEN = 12;
    parameter int MEM_DLEN = 128;
    parameter int CACHE_WAYS = 4;
    parameter int CACHE_SETS = 4;

    logic                imem_valid_o;
    logic [MEM_ALEN-1:0] imem_addr_o;
    logic [MEM_DLEN-1:0] imem_data_i;
    logic                imem_valid_i;

    logic                dmem_valid_o;
    logic [MEM_ALEN-1:0] dmem_addr_o;
    logic [MEM_DLEN-1:0] dmem_data_o;
    logic                dmem_we_o;
    logic [MEM_DLEN-1:0] dmem_data_i;
    logic                dmem_valid_i;

    soc #(
        .XLEN(XLEN),
        .MEM_ALEN(MEM_ALEN),
        .MEM_DLEN(MEM_DLEN),
        .CACHE_WAYS(CACHE_WAYS),
        .CACHE_SETS(CACHE_SETS)
    ) dut (.*);

    valid_delayer #(
        .N(5)
    ) valid_delayer_i_inst (
        .clk,
        .valid_i(imem_valid_o),
        .valid_o(imem_valid_i)
    );

    valid_delayer #(
        .N(5)
    ) valid_delayer_d_inst (
        .clk,
        .valid_i(dmem_valid_o),
        .valid_o(dmem_valid_i)
    );

    rom #(
        .DATA_WIDTH(MEM_DLEN),
        .ADDR_WIDTH(MEM_ALEN)
    ) imem (
        .addr_i(imem_addr_o),
        .data_o(imem_data_i)
    );

    sram #(
        .DATA_WIDTH(MEM_DLEN),
        .ADDR_WIDTH(MEM_ALEN)
    ) dmem (
        .clk,
        .addr_i(dmem_addr_o),
        .we_i(dmem_we_o),
        .byte_en_i('1),
        .data_i(dmem_data_o),
        .data_o(dmem_data_i)
    );

    konata_tracer #(
        .LOG_PREFIX("konata_output")
    ) tracer (
        .clk(clk),
        .reset_n(reset_n),
        .stall_i(dut.hart0_inst.stall_2d),

        // Fetch is valid if we are not inserting a bubble (noop)
        .valid_f_i(!dut.hart0_inst.noop_1f),
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
        int ret;
        string rom_file, sram_file;

        // Load rom
        if ($value$plusargs("ROM_FILE=%s", rom_file)) begin
            $readmemh(rom_file, imem.mem);
            $display("Loaded code memory from '%s'", rom_file);
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
        ret = cosim_dpi_init(rom_file, sram_file, 0'h00001000, 0'h00002000, MEM_DLEN);
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


    logic                tohost_written;
    logic [MEM_DLEN-1:0] tohost_aligned_cacheline;
    logic [XLEN-1:0]     tohost_value;
    assign tohost_written = &{dmem_addr_o, dmem_we_o}; // and reduction
    assign tohost_aligned_cacheline = dmem_data_o >> (((MEM_DLEN/XLEN)-1) * XLEN);
    assign tohost_value = tohost_aligned_cacheline[XLEN-1:0];

    logic [XLEN-1:0] ins;
    assign ins = dut.hart0_inst.s_1f_d.ins;

    logic dut_instr_retired_signal;
    assign dut_instr_retired_signal = (dut.hart0_inst.s_4m_q.valid && dut.hart0_inst.s_4m_q.ins != 0'h00000033);

    int cycle_count = 0;
    int instr_count = 0;
    always @(posedge clk) begin
        if (reset_n) begin
            ++cycle_count;
            if (dut_instr_retired_signal) begin
                instr_count <= instr_count + 1;
            end
            if (tohost_written) begin
                if (tohost_value == 0) begin
                    $display("** SIMULATION PASSED **: 'tohost' was written with 0.");
                    $display("TESTBENCH_RESULTS: res=0, clk=%0d, ins=%0d", cycle_count, instr_count);
                    $finish;
                end else begin
                    $display(1, "Test FAILED! Incorrect 'tohost' value. Expected 0, got %0d.", tohost_value);
                    $display("TESTBENCH_RESULTS: res=1, clk=%0d, ins=%0d", cycle_count, instr_count);
                end
            end else if (cycle_count >= TIMEOUT_CYCLES) begin
                $fatal(1, "Test FAILED! Timeout reached (%0d cycles) without writing to 'tohost'.", TIMEOUT_CYCLES);
            end
        end
    end

    always @(posedge clk) begin
        if (reset_n) begin
            if (dut.hart0_inst.s_4m_q.valid && dut.hart0_inst.s_4m_q.ins != 0'h00000033) begin
                int unsigned pc, ins, rd, trap;
                string disasm;
                int errors;

                trap = cosim_dpi_step(pc, ins, rd);

                if (trap == 1) begin
                    $display("TRAP in cosim: pc: 0x%08x", pc);
                    trap = cosim_dpi_step(pc, ins, rd);
                end

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
