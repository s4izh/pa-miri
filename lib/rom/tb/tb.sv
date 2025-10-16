module tb (
    input logic clk,
    input logic reset_n
);

    localparam XLEN = 32;
    localparam NREG = 4096;
    localparam ADDR_WIDTH = $clog2(NREG);

    logic [ADDR_WIDTH-1:0] addr_i;
    logic [XLEN-1:0] data_o;

    initial begin
        addr_i = 0;
        @(posedge reset_n);
        repeat(100) @(posedge clk);
        $finish;
    end

    rom #(
        .XLEN(XLEN),
        .NREG(NREG),
        .ROMFILE("romfile.hex")
    ) dut (.*);

    always @(posedge clk) begin
        if (!reset_n) begin
            $display("Reset applied");
        end else begin
            $display("At address 0x%h we got value 0x%h", addr_i, data_o);
            addr_i <= addr_i + ADDR_WIDTH'(1);
        end
    end

endmodule
