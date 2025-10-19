module rom #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 12
)(
    input  logic [ADDR_WIDTH-1:0] addr_i,
    output logic [DATA_WIDTH-1:0] data_o
);
    localparam int NREG = 2 ** ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [NREG-1:0];

    assign data_o = mem[addr_i];

endmodule
