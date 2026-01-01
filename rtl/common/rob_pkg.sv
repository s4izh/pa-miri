package rob_pkg;

    // Parameters
    `define XLEN          32
    `define N_ENTRIES_ROB 8
    `define N_ENTRIES_SB  8

    // Basic ID types
    typedef logic[$clog2(N_ENTRIES_ROB)-1:0] robid_t;
    // TODO: use propper store buffer id when we have it
    typedef logic[$clog2(N_ENTRIES_SB)-1:0] sbid_t;

    // Issue interfaces types
    typedef struct {
        logic             valid;
        logic [`XLEN-1:0] pc;
        logic             rd_we;
        logic [4:0]       rd_addr;
        logic             is_st;
    } issue_req_t;

    typedef struct {
        logic             ready;
        robid_t           robid;
    } issue_rsp_t;

    // Complete interface type
    typedef struct {
        logic             valid;
        robid_t           robid;
        logic [`XLEN-1:0] result;
        // We know if the sbid will be valid at issue time
        sbid_t            sbid;
    } complete_t;

    // Commit interfaces types
    typedef struct {
        logic             valid;
        logic             xcpt;
        robid_t           robid; //debug
    } commit_t;

    typedef struct {
        logic             rd_we;
        logic [4:0]       rd_addr;
        logic [`XLEN-1:0] rd_data;
        logic             xcpt;
    } commit_rf_t;

    typedef struct {
        logic             valid;
        sbid_t            sbid;
    } commit_sb_t;

endpackage
