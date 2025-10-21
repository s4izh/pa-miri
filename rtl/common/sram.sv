module sram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 12
)(
    input logic clk,

    input logic [ADDR_WIDTH-1:0] addr_i,

    // write port
    input logic we_i,
    input logic [DATA_WIDTH-1:0] data_i,

    // read port
    output logic [DATA_WIDTH-1:0] data_o
);
    localparam int NREG = 2 ** ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] sram_r[NREG-1:0];

    always_ff @(posedge clk) begin
        if (we_i) begin
            sram_r[addr_i] <= data_i;
        end
    end

    assign data_o = sram_r[addr_i];
endmodule
