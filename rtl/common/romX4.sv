module romX4 (
    input  logic [11:0]  addr_i,
    output logic [127:0] data_o
);
    localparam int NREG = 2 ** 12;
    reg [31:0] mem [NREG-1:0];
    assign data_o = {mem[addr_i+3], mem[addr_i+2], mem[addr_i+1], mem[addr_i]};
endmodule
