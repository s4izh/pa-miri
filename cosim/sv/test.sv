module test;

    import "DPI-C" function int cosim_dpi_init(string rom_path, string sram_path, int pc_reset, int pc_xcpt);
    import "DPI-C" function int cosim_dpi_step(output int unsigned pc, output int unsigned ins);


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
            -1: begin
                $display("Failed to init cosim_dpi");
                $fatal();
            end
            default: begin
                $display("Correclty initialized cosim_dpi");
            end
        endcase
        cycle_cnt = 0;
    end

    always @(posedge clk) begin
        int unsigned pc, ins;
        int active = cosim_dpi_step(pc, ins);
        $display("Executed:\n\t- iss: {pc: 0x%08x, ins: 0x%08x}\n\t", pc, ins);
        cycle_cnt += 1;
        if (cycle_cnt >= 100) begin
            $finish("Ok!");
        end
    end

endmodule
