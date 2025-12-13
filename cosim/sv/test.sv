module test;

    import "DPI-C" function int cosim_dpi_step(int n);

    initial begin
        int a = cosim_dpi_step(30);
        int b = cosim_dpi_step(31);
        $display("Hey! %d, %d", a, b);
        $finish();
    end

endmodule
