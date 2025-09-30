module rom #(
    parameter int XLEN = 32,
    parameter int NREG = 4096,
    parameter string ROMFILE = "",

    parameter ADDR_WIDTH = $clog2(NREG)
)(
    input logic clk,
    // input logic reset_n,

    input logic [ADDR_WIDTH-1:0] addr_i,
    output logic [XLEN-1:0] data_o
);

    reg [XLEN-1:0] rom_r[NREG-1:0];

    initial begin
        if (ROMFILE != "") begin
            $readmemh(ROMFILE, rom_r);
        end else begin
            $warning("No ROMFILE specified");
        end
    end

    assign data_o = rom_r[addr_i];

endmodule
