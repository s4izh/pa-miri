package csr_pkg;
    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
    } capture_xcpt_t;

    // Machine Trap Setup
    localparam logic[11:0] CSR_ADDR_MTVEC    = 12'h305;
    // Machine Trap Handling
    localparam logic[11:0] CSR_ADDR_MEPC     = 12'h341;
    localparam logic[11:0] CSR_ADDR_MCAUSE   = 12'h342;
    localparam logic[11:0] CSR_ADDR_MTVAL    = 12'h343;
endpackage
