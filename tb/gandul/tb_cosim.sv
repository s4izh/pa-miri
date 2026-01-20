`include "harness_params.svh"

module tb (
    input logic clk,
    input logic reset_n
);

    import "DPI-C" function int cosim_dpi_init_unified(string sram_path, int unsigned pc_reset, int unsigned pc_xcpt, int unsigned mem_dlen);
    import "DPI-C" function int cosim_dpi_init(string rom_path, string sram_path, int unsigned pc_reset, int unsigned pc_xcpt, int unsigned mem_dlen);
    import "DPI-C" function int unsigned cosim_dpi_step(output int unsigned pc, output int unsigned ins, output int unsigned rd);


    parameter int DEFAULT_TIMEOUT_CYCLES = 1000;

    parameter int XLEN = `XLEN;

    parameter int MEM_SIZE_KB = `MEM_SIZE_KB;
    parameter int MEM_DLEN    = 128;
    parameter int MEM_NLINES  = (MEM_SIZE_KB*1024)/MEM_DLEN;
    parameter int MEM_ALEN    = $clog2(MEM_NLINES);

    parameter int CACHE_WAYS = `CACHE_WAYS;
    parameter int CACHE_SETS = `CACHE_SETS;

    logic                mem_valid_o;
    logic [MEM_ALEN-1:0] mem_addr_o;
    logic [MEM_DLEN-1:0] mem_data_o;
    logic                mem_we_o;
    logic [MEM_DLEN-1:0] mem_data_i;
    logic                mem_valid_i;

    soc #(
        .XLEN(XLEN),
        .MEM_ALEN(MEM_ALEN),
        .MEM_DLEN(MEM_DLEN),
        .CACHE_WAYS(CACHE_WAYS),
        .CACHE_SETS(CACHE_SETS)
    ) dut (.*);

    valid_delayer #(
        .N(`DELAYER_LEN)
    ) valid_delayer_d_inst (
        .clk,
        .valid_i(mem_valid_o),
        .valid_o(mem_valid_i)
    );

    sram #(
        .DATA_WIDTH(MEM_DLEN),
        .ADDR_WIDTH(MEM_ALEN)
    ) dmem (
        .clk,
        .addr_i(mem_addr_o),
        .we_i(mem_we_o),
        .byte_en_i('1),
        .data_i(mem_data_o),
        .data_o(mem_data_i)
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

        // Load sram
        if ($value$plusargs("SRAM_FILE=%s", sram_file)) begin
            $readmemh(sram_file, dmem.mem);
            $display("Loaded data memory from '%s'", sram_file);
        end else begin
            $warning("No SRAM_FILE specified. Empty data memory.");
        end

        // Init DPI-C
        ret = cosim_dpi_init_unified(sram_file, 0'h00001000, 0'h00002000, MEM_DLEN);
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


    // logic                tohost_written;
    // logic [MEM_DLEN-1:0] tohost_aligned_cacheline;
    // logic [XLEN-1:0]     tohost_value;
    // assign tohost_written = &{mem_addr_o, mem_we_o}; // and reduction
    // assign tohost_aligned_cacheline = mem_data_o >> (((MEM_DLEN/XLEN)-1) * XLEN);
    // assign tohost_value = tohost_aligned_cacheline[XLEN-1:0];

    logic                tohost_written;
    logic [XLEN-1:0]     tohost_value;
    assign tohost_written           = dut.hart0_inst.stage_4m_inst.dcache_inst.dreq_valid_i &
                                      dut.hart0_inst.stage_4m_inst.dcache_inst.dreq_we_i    &
                                     (dut.hart0_inst.stage_4m_inst.dcache_inst.dreq_addr_i == 32'hffff_fffc);
    assign tohost_value             = dut.hart0_inst.stage_4m_inst.dcache_inst.dreq_data_i;

    logic [XLEN-1:0] ins;
    assign ins = dut.hart0_inst.s_1f_d.ins;


    `define ROB_COMMIT dut.hart0_inst.rob_commit
    `define ROB_COMMIT_RF dut.hart0_inst.rob_commit_rf
    logic dut_instr_retired_signal, dut_noop_retired_signal;
    assign dut_instr_retired_signal = `ROB_COMMIT.valid && `ROB_COMMIT.dbg_ins != 32'h00000033;
    assign dut_noop_retired_signal  = `ROB_COMMIT.valid && `ROB_COMMIT.dbg_ins == 32'h00000033;

    int cycle_count = 0;
    int instr_count = 0;
    always @(posedge clk) begin
        if (reset_n) begin
            if (dut_instr_retired_signal) begin
                instr_count <= instr_count + 1;
            end
            ++cycle_count;
            if (tohost_written) begin
                if (tohost_value == 0) begin
                    $display("** SIMULATION PASSED **: 'tohost' was written with 0.");
                    $display("TESTBENCH_RESULTS: res=0, clk=%0d, ins=%0d", cycle_count, instr_count);
                end else begin
                    $display("Test FAILED! Incorrect 'tohost' value. Expected 0, got %0d.", tohost_value);
                    $display("TESTBENCH_RESULTS: res=1, clk=%0d, ins=%0d", cycle_count, instr_count);
                end
                $finish;
            end else if (cycle_count >= TIMEOUT_CYCLES) begin
                $display("Test FAILED! Timeout reached (%0d cycles) without writing to 'tohost'.", TIMEOUT_CYCLES);
                $display("TESTBENCH_RESULTS: res=2, clk=%0d, ins=%0d", cycle_count, instr_count);
                $finish;
            end
        end
    end

    always @(posedge clk) begin
        if (reset_n) begin
            if (dut_noop_retired_signal) begin
                $display("NOOP COMMITTED: {pc: 0x%08x, robid: 0x%08x}",
                    `ROB_COMMIT.pc, `ROB_COMMIT.dbg_robid);
            end else if (dut_instr_retired_signal) begin
                int unsigned pc, ins, rd, trap;
                string disasm;
                int errors;

                trap = cosim_dpi_step(pc, ins, rd);

                errors = 0;
                if (pc != `ROB_COMMIT.pc) begin
                    $display("ERROR - Different PC: {dut: 0x%08x, iss: 0x%08x}",
                        `ROB_COMMIT.pc, pc);
                    errors += 1;
                end

                if (!(|trap) && ins != `ROB_COMMIT.dbg_ins) begin
                    $display("ERROR - Different instruction: {dut: 0x%08x, iss: 0x%08x}",
                        `ROB_COMMIT.dbg_ins, ins);
                    errors += 1;
                end

                if (`ROB_COMMIT_RF.rd_we
                    && '0 != `ROB_COMMIT_RF.rd_addr
                    && rd != `ROB_COMMIT_RF.rd_data) begin
                    $display("ERROR - Different rd: {dut: 0x%08x, iss: 0x%08x}",
                        `ROB_COMMIT_RF.rd_data, rd);
                    errors += 1;
                end

                if ((trap != 0) != `ROB_COMMIT.xcpt) begin
                    $display("ERROR - Different xcpt: {dut: %0d, iss: %0d}",
                        `ROB_COMMIT.xcpt, trap);
                    errors += 1;
                end

                // disasm_rv32i(data.hart0_inst.s_4m_q.ins);
                disasm = rv32_util_pkg::disasm_rv32i(ins);
                if (errors == 0) begin
                    $display("CORRECT - 0x%08x: %s - RESULT: 0x%08x", pc, disasm, rd);
                end else begin
                    $display("INCORRECT - 0x%08x: %s", pc, disasm);
                    $display("Test FAILED! Due to %0d errors.", errors);
                    $display("TESTBENCH_RESULTS: res=1, clk=%0d, ins=%0d", cycle_count, instr_count);
                    $finish;
                end
            end
        end
    end

endmodule
