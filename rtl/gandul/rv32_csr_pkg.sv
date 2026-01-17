package rv32_csr_pkg;

    // Machine Information Registers
    localparam logic[11:0] CSR_ADDR_MHARTID  = 12'hF14;

    // Machine Trap Setup
    localparam logic[11:0] CSR_ADDR_MSTATUS  = 12'h300;
    localparam logic[11:0] CSR_ADDR_MTVEC    = 12'h305;

    // Machine Trap Handling
    localparam logic[11:0] CSR_ADDR_MSCRATCH = 12'h340;
    localparam logic[11:0] CSR_ADDR_MEPC     = 12'h341;
    localparam logic[11:0] CSR_ADDR_MCAUSE   = 12'h342;
    localparam logic[11:0] CSR_ADDR_MTVAL    = 12'h343;

endpackage
