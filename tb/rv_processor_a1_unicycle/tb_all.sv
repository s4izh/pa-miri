// =============================================================================
// Verification Strategy: Automated Memory Check via ABI
//
// 1. The testbench loads the compiled assembly program into instruction memory.
// 2. The assembly program runs, executing a series of tests and storing the
//    results in a data memory region.
// 3. Upon completion, the assembly program writes two key pieces of information
//    to fixed, well-known memory addresses (the "ABI"):
//      a) The base address of the results table.
//      b) A "magic number" (halt signature) to signal it has finished.
// 4. The testbench continuously polls the halt signature address. When it sees
//    the magic number, it knows the test is done.
// 5. The testbench then reads the results' base address from the ABI.
// 6. It proceeds to read all test results from data memory, calculating their
//    addresses relative to the base pointer it just read.
// 7. Finally, it compares each result against a list of expected "golden"
//    values and prints a detailed PASS/FAIL report.
//
// This approach removes the need to manually run objdump to find symbol addresses.
// =============================================================================
module tb (
    input logic clk,
    input logic reset_n
);
    parameter int XLEN = 32;
    parameter int IALEN = 12; // Instruction Address Length (e.g., 12 bits for 4KB)
    parameter int DALEN = 12; // Data Address Length
    parameter int MEM_DLEN = 32;

    //================================================================
    // ABI: Fixed addresses for communication with the test program
    //================================================================
    localparam logic [31:0] HALT_ADDR             = 32'h10001FFC;
    localparam logic [31:0] HALT_SIGNATURE        = 32'hBAADF00D;
    localparam logic [31:0] RESULTS_BASE_PTR_ADDR = 32'h10001FF8;

    //================================================================
    // Test Vectors: Expected values for each test
    // These are defined by their OFFSET from the base address.
    // NOTE: PC-relative values (JAL, AUIPC) are hardcoded here. If you
    // significantly change the assembly program, these may need to be
    // recalculated, but all other values are position-independent.
    //================================================================
    typedef struct {
        string       name;
        logic [31:0] offset;
        logic [31:0] expected_value;
    } test_vector_t;

    const test_vector_t test_vectors[] = '{
        // R-Type Results
        '{"ADD",         0, 32'd15},
        '{"SUB",         4, 32'hFFFFFFFB},
        '{"SLL",         8, 32'd40},
        '{"SLT",        12, 32'd0},
        '{"SLTU",       16, 32'd1},
        '{"XOR",        20, 32'd15},
        '{"SRL",        24, 32'd2},
        '{"SRA",        28, 32'hFFFFFFFD},
        '{"OR",         32, 32'd15},
        '{"AND",        36, 32'd0},
        // I-Type Results
        '{"ADDI",       40, 32'd100},
        '{"SLTI",       44, 32'd1},
        '{"SLTIU",      48, 32'd1},
        '{"XORI",       52, 32'h0000FFFF},
        '{"ORI",        56, 32'h0000FFFF},
        '{"ANDI",       60, 32'h00000F0F},
        '{"SLLI",       64, 32'h00008000},
        '{"SRLI",       68, 32'h0000000F},
        '{"SRAI",       72, 32'hFFFFFFFF},
        // Memory Results
        '{"LW",         76, 32'hDEADBEEF},
        '{"LH",         80, 32'hFFFFBEEF},
        '{"LHU",        84, 32'h0000BEEF},
        '{"LB",         88, 32'hFFFFFFEF},
        '{"LBU",        92, 32'h000000EF},
        '{"SW",         96, 32'h12345678},
        // Branch Results
        '{"BEQ-TAKEN", 100, 32'd1},
        '{"BEQ-FALL",  104, 32'd0},
        '{"BNE-TAKEN", 108, 32'd1},
        '{"BNE-FALL",  112, 32'd0},
        '{"BLT-TAKEN", 116, 32'd1},
        '{"BGE-TAKEN", 120, 32'd1},
        '{"BLTU-TAKEN",124, 32'd1},
        // Jump Results (PC-dependent, update if assembly changes)
        '{"JAL",       128, 32'h000001f4},
        '{"JALR",      132, 32'h0000020c},
        // U-Type Results (PC-dependent, update if assembly changes)
        '{"LUI",       136, 32'hABCDE000},
        '{"AUIPC",     140, 32'h00001218}
    };

    // --- DUT and Memory Instantiation ---
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

    // --- Program Loading ---
    initial begin
        string rom_file;
        if ($value$plusargs("ROM_FILE=%s", rom_file)) begin
            $readmemh(rom_file, imem.mem);
            $display("TB: Loaded instruction memory from '%s'", rom_file);
        end else begin
            $error("TB: No ROM_FILE specified. Empty instruction memory.");
        end
    end

    // --- Simulation Control and Verification ---
    logic test_finished = 1'b0;

    task automatic check_results();
        int failures = 0;
        logic [XLEN-1:0] results_base_addr;
        logic [XLEN-1:0] actual_data;
        logic [XLEN-1:0] current_addr;

        $display("\n================================================================================");
        $display("               >> PROGRAM FINISHED, STARTING MEMORY CHECKS <<");
        $display("================================================================================");

        // 1. Read the base address that the assembly program provided for us.
        results_base_addr = dmem.mem[RESULTS_BASE_PTR_ADDR >> 2];
        $display("TB: Read results base address = 0x%h", results_base_addr);

        // 2. Loop through all test vectors and check memory
        foreach (test_vectors[i]) begin
            current_addr = results_base_addr + test_vectors[i].offset;
            actual_data = dmem.mem[current_addr >> 2]; // Convert byte addr to word index

            if (actual_data == test_vectors[i].expected_value) begin
                $display("[PASS] Test %-12s @ 0x%h: Expected 0x%h, Got 0x%h",
                    test_vectors[i].name, current_addr, test_vectors[i].expected_value, actual_data);
            end else begin
                $error("[FAIL] Test %-12s @ 0x%h: Expected 0x%h, Got 0x%h",
                    test_vectors[i].name, current_addr, test_vectors[i].expected_value, actual_data);
                failures++;
            end
        end

        // 3. Print final summary
        $display("--------------------------------------------------------------------------------");
        if (failures == 0) begin
            $display(">>>>> ALL %0d TESTS PASSED! <<<<<", test_vectors.size());
        end else begin
            $error(">>>>> %0d out of %0d TESTS FAILED! <<<<<", failures, test_vectors.size());
        end
        $display("--------------------------------------------------------------------------------");
        $finish;
    endtask

    // This block polls memory, waiting for the "halt signature" from the assembly program
    always @(posedge clk) begin
        if (reset_n && !test_finished) begin
            // Check if the magic number has been written to the halt address
            if (dmem.mem[HALT_ADDR >> 2] == HALT_SIGNATURE) begin
                #1;
                test_finished = 1'b1;
            end
        end
    end

    initial begin
        @(posedge test_finished);
        check_results();
    end

    initial begin
        repeat(10000) @(posedge clk);
        $error("SIMULATION TIMEOUT! The program did not write the halt signature in 10000 cycles.");
        $finish;
    end

endmodule
