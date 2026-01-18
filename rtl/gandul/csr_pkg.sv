package csr_pkg;

    `define XLEN 32

    typedef enum {
        CSR_OP_RW,
        CSR_OP_RS,
        CSR_OP_RC
    } csr_op_e;

    typedef struct {
        logic             valid;
        csr_op_e          csr_op;
        // CSR info
        logic [11:0]      csr_addr;
        logic [`XLEN-1:0] csr_data;
        // Destination reg info
        logic [4:0]       rd_addr;
        // Source reg info
        logic [4:0]       rs1_addr;
        logic [`XLEN-1:0] rs1_data;
        // uimm info
        logic             uimm_valid;
        logic [4:0]       uimm;
        // ROB signals
        robid_t           robid;
    } signals_csr_in_t;

    typedef struct {
        logic             valid;
        // Result of the source register
        logic             rd_we;
        logic [`XLEN-1:0] rd_data;
        // Result of the csr
        logic             csr_we;
        logic [`XLEN-1:0] csr_data;
        // ROB signals
        robid_t           robid;
        logic             xcpt;
    } signals_csr_out_t;

    // Machine Information Registers
    localparam logic[11:0] CSR_ADDR_MHARTID  = 12'hF14;

    // Machine Trap Setup
    localparam logic[11:0] CSR_ADDR_MTVEC    = 12'h305;

    // Machine Trap Handling
    localparam logic[11:0] CSR_ADDR_MSCRATCH = 12'h340;
    localparam logic[11:0] CSR_ADDR_MEPC     = 12'h341;
    localparam logic[11:0] CSR_ADDR_MCAUSE   = 12'h342;
    localparam logic[11:0] CSR_ADDR_MTVAL    = 12'h343;

endpackage
