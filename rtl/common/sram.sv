module sram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 12
)(
    input logic clk,

    input logic [ADDR_WIDTH-1:0] addr_i,

    // write port
    input logic we_i,
    input logic [DATA_WIDTH/8-1:0] byte_en_i,
    input logic [DATA_WIDTH-1:0] data_i,

    // read port
    output logic [DATA_WIDTH-1:0] data_o
);
    localparam int NREG = 2 ** ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem[NREG-1:0];

    always_ff @(posedge clk) begin
        if (we_i) begin
            for (int i = 0; i < DATA_WIDTH/8; ++i) begin
                if (byte_en_i[i]) mem[addr_i][(i*8) +: 8] <= data_i[(i*8) +: 8];
            end
        end
    end

    assign data_o = mem[addr_i];
endmodule
