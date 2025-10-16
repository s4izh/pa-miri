module rom #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 12,
    parameter string ROMFILE = ""
)(
    input  logic [ADDR_WIDTH-1:0] addr_i,
    output logic [DATA_WIDTH-1:0] data_o
);
    localparam int NREG = 2 ** ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] rom_r[NREG-1:0];

    initial begin
        // if (ROMFILE != "") begin
        //     $readmemh(ROMFILE, rom_r);
        // end else begin
        //     $warning("No ROMFILE specified");
        // end
        $readmemh("utils/jajasalu2.hex", rom_r);
    end

    assign data_o = rom_r[addr_i];

endmodule
