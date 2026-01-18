import csr_pkg::*;

module csr_regfile #(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic reset_n,
    // Read port
    input  logic [11:0]     read_addr_i,
    output logic [XLEN-1:0] read_data_o,
    // Write port
    input  logic            write_en_i,
    input  logic [11:0]     write_addr_i,
    output logic [XLEN-1:0] write_data_i,
    // Exceptions
    output logic            xcpt_o,
    // Control signals coming from csrs
    output logic [XLEN-1:0] trap_addr_o
);
    logic [1:0] current_priv;
    logic xcpt_write, xcpt_read;
    // CSRs
    logic [XLEN-1:0] csr_mhartid;
    logic [XLEN-1:0] csr_mtvec;
    logic [XLEN-1:0] csr_mscratch;
    logic [XLEN-1:0] csr_mepc;
    logic [XLEN-1:0] csr_mcause;
    logic [XLEN-1:0] csr_mtval;

    assign current_priv = 2'b11;

    assign trap_addr_o = csr_mtvec;
    assign xcpt_o = xcpt_read | xcpt_write;

    // Read
    always_comb begin
        read_data_o = '0;
        xcpt_read = ~can_read(read_addr_i, current_priv);
        if (~xcpt_read) begin
            case (read_addr_i)
                CSR_ADDR_MHARTID:  read_data_o = csr_mhartid;
                CSR_ADDR_MTVEC:    read_data_o = csr_mtvec;
                CSR_ADDR_MSCRATCH: read_data_o = csr_mscratch;
                CSR_ADDR_MEPC:     read_data_o = csr_mepc;
                CSR_ADDR_MCAUSE:   read_data_o = csr_mcause;
                CSR_ADDR_MTVAL:    read_data_o = csr_mtval;
                default:           xcpt_read = '1;
            endcase
        end
    end

    // Write
    always @(posedge clk) begin
        if (!reset_n) begin
            csr_mstatus  <= '0;
            csr_mtvec    <= '0;
            csr_mhartid  <= '0;
            csr_mscratch <= '0;
            csr_mepc     <= '0;
            csr_mcause   <= '0;
            csr_mtval    <= '0;
            xcpt_write    = '0;
        end else begin
            xcpt_write = write_en_i & ~can_write(write_addr_i, current_priv);
            if (write_en_i & ~xcpt_write) begin
                case(write_addr_i)
                    CSR_ADDR_MHARTID:  csr_mhartid  <= write_data_i;
                    CSR_ADDR_MSTATUS:  csr_mstatus  <= write_data_i;
                    CSR_ADDR_MTVEC:    csr_mtvec    <= write_data_i;
                    CSR_ADDR_MSCRATCH: csr_mscratch <= write_data_i;
                    CSR_ADDR_MEPC:     csr_mepc     <= write_data_i;
                    CSR_ADDR_MCAUSE:   csr_mcause   <= write_data_i;
                    CSR_ADDR_MTVAL:    csr_mtval    <= write_data_i;
                    default:           xcpt_write = '1;
                endcase
            end

        end
    end

    function logic can_read(logic [11:0] addr, logic [1:0] current_priv);
        logic [1:0] eleven2ten, nine2eight;
        logic [3:0] seven2four;
        eleven2ten = addr[11:10];
        nine2eight = addr[9:8];
        seven2four = addr[7:4];
        if (nine2eight >= current_priv) return 0;
        if (eleven2ten == 2'b01 && seven2four == 4'b1011) return 0;
        return 1;
    endfunction

    function logic can_write(logic [11:0] addr, logic [1:0] current_priv);
        logic [1:0] eleven2ten, nine2eight;
        logic [3:0] seven2four;
        eleven2ten = addr[11:10];
        nine2eight = addr[9:8];
        seven2four = addr[7:4];
        if (nine2eight >= current_priv) return 0;
        if (eleven2ten == 2'b01 && seven2four == 4'b1011) return 0;
        if (
            eleven2ten == 2'b11 && (
                seven2four[3] == 1'b0 ||
                seven2four[3:2] == 2'b10 ||
                seven2four[3:2] == 2'b11
            )
        ) return 0;

        return 1;
    endfunction

endmodule
