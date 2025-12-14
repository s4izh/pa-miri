module test;

    import "DPI-C" function int cosim_dpi_init(string rom_path, string sram_path, int pc_reset, int pc_xcpt);
    import "DPI-C" function int cosim_dpi_step();

    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    int cycle_cnt;
    initial begin
        int ret;
        ret = cosim_dpi_init("hola.rom.hex", "hola.sram.hex", 0'h00001000, 0'h00002000);
        case (ret)
            -1: $fatal("Failed to init cosim_dpi");
            default: $display("Correclty initialized cosim_dpi");
        endcase
        cycle_cnt = 0;
    end

    always @(posedge clk) begin
        int pc_exec = cosim_dpi_step();
        $display("Executed pc: 0x%x", pc_exec);
        cycle_cnt += 1;
        if (cycle_cnt >= 30) begin
            $finish("Ok!");
        end
    end

endmodule
