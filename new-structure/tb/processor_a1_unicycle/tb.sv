module tb (
    input logic clk,
    input logic reset_n
);
    parameter int XLEN = 32;
    parameter int IALEN = 12;
    parameter int DALEN = 12;

    logic[IALEN-1:0]    imem_addr_o;
    logic[XLEN-1:0]     imem_data_i;

    logic[DALEN-1:0]    dmem_addr_o;
    logic[XLEN-1:0]     dmem_data_o;
    logic               dmem_we_o;
    logic[XLEN-1:0]     dmem_data_i;

    processor_a1_unicycle #(
        .XLEN(XLEN),
        .IALEN(IALEN),
        .DALEN(DALEN)
    ) dut (.*);

    rom #(
        .DATA_WIDTH(XLEN),
        .ADDR_WIDTH(IALEN),
        .ROMFILE("asm/jajasalu2.hex")
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
        .data_i(dmem_data_o),
        .data_o(dmem_data_i)
    );

    initial begin
        @(posedge reset_n)
        repeat(50) @(posedge clk);
        $finish;
    end

    always @(posedge clk) begin
        if (reset_n) begin
            $display("------------------------------------------------------------------");
            $display("TIME: %0t", $time);
            $display("CPU STATE: PC = %h", dut.pc);
            $display("DECODER INPUT: Fetched Instruction = %h", dut.imem_data_i);
            $display("DECODER OUTPUT: is_ld=%b, is_st=%b, is_wb=%b", dut.is_ld, dut.is_st, dut.is_wb);
            $display("REGFILE READ: ra_data = %h, rb_data = %h", dut.ra_data, dut.rb_data);
            $display("ALU INPUTS: add_op_1 = %h, add_op_2 = %h", dut.add_op_1, dut.add_op_2);
            $display("ALU OUTPUT: add_op_result = %h", dut.add_op_result);
            $display("DMEM SIGNALS: dmem_addr_o = %h, dmem_data_o = %h, dmem_data_i = %h, dmem_we_o = %b", dmem_addr_o, dmem_data_o, dmem_data_i, dmem_we_o);
            $display("------------------------------------------------------------------");
        end
    end

endmodule
