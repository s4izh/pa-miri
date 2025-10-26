module tb (
    input logic clk,
    input logic reset_n
);
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

    initial begin
        string rom_file;
        if ($value$plusargs("ROM_FILE=%s", rom_file)) begin
            $readmemh(rom_file, imem.mem);
        end else begin
            $error("No ROM_FILE specified. Empty instruction memory");
        end
    end

    initial begin
        @(posedge reset_n)
        repeat(500) @(posedge clk);
        $finish;
    end

    always @(posedge clk) begin
        if (reset_n) begin
            $display("--------------------------------------------------------------------------------");
            $display("TIME: %0t", $time);
            $display("=============================[ FETCH ]==============================");
            $display("PC          : 0x%h", dut.hart0_inst.pc);
            $display("Instruction : 0x%h", dut.hart0_inst.imem_data_i);
            $display("=============================[ DECODE ]=============================");
            $display("rd          : x%0d (reg %0d)", dut.hart0_inst.rd_addr, dut.hart0_inst.rd_addr);
            $display("rs1         : x%0d (reg %0d)", dut.hart0_inst.rs1_addr, dut.hart0_inst.rs1_addr);
            $display("rs2         : x%0d (reg %0d)", dut.hart0_inst.rs2_addr, dut.hart0_inst.rs2_addr);
            $display("Immediate   : 0x%h (%d)", dut.hart0_inst.immed, dut.hart0_inst.immed);
            $display("=============================[ EXECUTE ]============================");
            $display("rs1_data    : 0x%h", dut.hart0_inst.rs1_data);
            $display("rs2_data    : 0x%h", dut.hart0_inst.rs2_data);
            $display("ALU Op1     : 0x%h (%s)", dut.hart0_inst.alu_op1, dut.hart0_inst.alu_op1_sel.name());
            $display("ALU Op2     : 0x%h (%s)", dut.hart0_inst.alu_op2, dut.hart0_inst.alu_op2_sel.name());
            $display("ALU Op      : %s", dut.hart0_inst.alu_op.name());
            $display("ALU Result  : 0x%h", dut.hart0_inst.alu_result);
            $display("Branch?     : %s, Taken?=%b", dut.hart0_inst.compare_op.name(), dut.hart0_inst.taken_branch);
            $display("=============================[ MEMORY ]=============================");
            if (dut.hart0_inst.is_ld || dut.hart0_inst.is_st) begin
                $display("Memory Op   : %s", dut.hart0_inst.is_ld ? "LOAD" : "STORE");
                $display("Mem Address : 0x%h", dmem_addr_o);
                $display("Mem wr_en   : %b", dmem_we_o);
                $display("Mem wr_data : 0x%h", dmem_data_o);
                $display("Mem rd_data : 0x%h", dmem_data_i);
                $display("Mem width   : %s", dut.hart0_inst.dmem_width_o.name());
            end else begin
                $display("Memory Op   : ---");
            end
            $display("=============================[ WRITEBACK ]==========================");
            $display("Writeback En: %b", dut.hart0_inst.is_wb);
            if (dut.hart0_inst.is_wb) begin
                $display("WB Data Src : %s", dut.hart0_inst.wb_sel.name());
                $display("WB Data     : 0x%h", dut.hart0_inst.rd_data);
                $display("WB Dest Reg : x%0d", dut.hart0_inst.rd_addr);
            end
            $display("=============================[ PC UPDATE ]==========================");
            $display("PC Select   : %s", dut.hart0_inst.pc_sel.name());
            $display("--------------------------------------------------------------------------------\n");
        end
    end

endmodule
