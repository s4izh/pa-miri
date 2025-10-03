module sram #(
    parameter int XLEN = 32,
    parameter int NREG = 4096,
    parameter int ADDR_WIDTH = $clog2(NREG)
)(
    input logic clk,

    input logic [ADDR_WIDTH-1:0] addr_i,

    // write port
    input logic we_i,
    input logic [XLEN-1:0] data_i,

    // read port
    output logic [XLEN-1:0] data_o
);
    reg [XLEN-1:0] sram_r[NREG-1:0];

    always_ff @(posedge clk) begin
        if (we_i) begin
            sram_r[addr_i] <= data_i;
        end
    end

    assign data_o = sram_r[addr_i];
endmodule
