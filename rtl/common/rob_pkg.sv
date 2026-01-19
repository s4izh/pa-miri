`include "harness_params.svh"

package rob_pkg;
    import store_buffer_pkg::*; // for sbid_t

    // Basic ID types
    typedef logic[$clog2(`ROB_N_ENTRIES)-1:0] robid_t;

    // Issue interfaces types
    typedef struct packed {
        logic             valid;
        logic [`XLEN-1:0] pc;
        logic [`XLEN-1:0] dbg_ins;
        logic             rd_we;
        logic [4:0]       rd_addr;
        logic             is_st;
    } issue_req_t;

    typedef struct packed {
        logic             csr_we;
        logic [11:0]      csr_addr;
    } issue_req_csr_t;

    typedef struct packed {
        logic             ready;
        robid_t           robid;
    } issue_rsp_t;

    // Complete interface type
    typedef struct packed {
        logic             valid;
        robid_t           robid;
        logic [`XLEN-1:0] result;
        logic             xcpt;
        // We know if the sbid will be valid at issue time (is_st)
        sbid_t            sbid;
    } complete_t;

    typedef struct packed {
        logic             valid;
        robid_t           robid;
        logic [`XLEN-1:0] rd_result;
        logic [`XLEN-1:0] csr_result;
        logic             xcpt;
    } complete_csr_t;

    // Commit interfaces types
    typedef struct packed {
        logic             valid;
        logic [`XLEN-1:0] pc;
        logic             xcpt;
        robid_t           dbg_robid;
        logic [`XLEN-1:0] dbg_ins;
    } commit_t;

    typedef struct packed {
        logic             rd_we;
        logic [4:0]       rd_addr;
        logic [`XLEN-1:0] rd_data;
    } commit_rf_t;

    typedef struct packed {
        logic             valid;
        sbid_t            sbid;
    } commit_sb_t;

    typedef struct packed {
        logic             csr_we;
        logic [11:0]      csr_addr;
        logic [`XLEN-1:0] csr_data;
    } commit_csr_t;

    // Interface types to peek youngest register values
    // (make rob act as content addressable memory)
    typedef struct packed {
        logic             valid;
        logic [4:0]       addr;
    } cam_req_t;

    typedef struct packed {
        logic             valid;
        logic [11:0]      addr;
    } cam_req_csr_t;

    typedef struct packed {
        logic             valid;
        logic             complete;
        logic [`XLEN-1:0] value;
        robid_t           robid;
    } cam_rsp_t;

endpackage
