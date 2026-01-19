import rv_datapath_pkg::*;
import rv_branch_compare_pkg::*;
import memory_controller_pkg::*;
import alu_pkg::*;
import rv_isa_pkg::*;
import rob_pkg::*;

`include "harness_params.svh"

module gandul# (
    parameter int XLEN = 32,
    parameter int N_PHY_REG = 32,
    parameter int WAYS = 4,
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128,
    parameter int MULDIV_OP_DELAY = 6
)(
    input  logic clk,
    input  logic reset_n,

    output logic                      imem_valid_o,
    output logic [XLEN-1:0]           imem_addr_o,
    input  logic                      imem_valid_i,
    input  logic [BITS_CACHELINE-1:0] imem_data_i,

    output logic                      dmem_valid_o,
    output logic [XLEN-1:0]           dmem_addr_o,
    output logic [BITS_CACHELINE-1:0] dmem_data_o,
    output logic                      dmem_we_o,
    input  logic                      dmem_valid_i,
    input  logic [BITS_CACHELINE-1:0] dmem_data_i
);

    // pc
    logic [XLEN-1:0] pc;
    // trap control signals
    logic rob_trap_valid, xcpt_2d, xcpt_icache;
    // branch control
    logic taken_branch;
    // mux selectors
    mux_pc_sel_e pc_sel;
    // pipeline stages data
    signals_fetch_t     s_1f_d, s_1f_q;
    signals_decode_t    s_2d_d, s_2d_q;
    signals_execute_t   s_3e_d, s_3e_q;
    signals_memory_t    s_4m_d, s_4m_q;
    signals_writeback_t s_5w_d;
    // data mem interfacing
    dmem_if_in_t  dmem_if_in;
    dmem_if_out_t dmem_if_out;

    // store buffer signals (allocation handshake between 2d and 4m)
    logic       sb_full;
    sbid_t      sb_alloc_idx;
    logic       sb_alloc_en;

    // Hazard control
    // Detection
    logic rs1_valid, rs2_valid;
    logic [$clog2(N_PHY_REG)-1:0] rs1_addr, rs2_addr;
    logic csr_re;
    logic [11:0] csr_raddr;
    // Control
    logic noop_1f, noop_2d, noop_3e, noop_4m, noop_5w, noop_muldiv, noop_csr;
    logic stall_1f, stall_2d, stall_3e, stall_4m, stall_muldiv, stall_csr;
    logic data_hazard;
    // Signals from 2d to forwarding unit (to avoid UNOPTFLAT)
    logic is_st_2d;
    // Bypass control
    logic bypass_rs1_2d_sel, bypass_rs2_2d_sel, bypass_csr_2d_sel;
    logic [XLEN-1:0] bypass_rs1_2d_data, bypass_rs2_2d_data, bypass_csr_2d_data;
    logic bypass_4m_3e_sel;

    logic waiting_for_memory_4m;

    logic icache_dreq_ready;
    logic [XLEN-1:0] icache_drsp_data;

    // branch predictor signals
    logic [XLEN-1:0] bp_pred_target;
    logic            bp_pred_taken;

    logic            is_control_3e; // is instruction in EX a control flow?
    logic            branch_real_taken_3e; // actual outcome in EX
    logic [XLEN-1:0] branch_real_target_3e;// actual target in EX
    logic            misprediction;   // did we mess up?

    // use s_1f_q.valid (input to decode) instead of s_2d_d.valid (output of decode)
    // this avoids the circular loop where trap -> noop -> s_2d_d.valid=0 -> trap=0
    // Use icache_dreq_ready directly to break loop through s_1f_d
    assign rob_trap_valid = rob_commit.valid & rob_commit.xcpt;

    // inject a noop on 1f and 2d if we have a pending jump
    // a jump is pending if we were doing a request to icache while
    // the pc changed, this means the fetched ins isn't the one we wanted to
    // go, so we propagate a nop down the pipeline
    assign noop_1f     = misprediction | rob_trap_valid | pending_jump_valid;
    assign noop_2d     = misprediction | rob_trap_valid | pending_jump_valid;
    assign noop_3e     = rob_trap_valid;
    assign noop_4m     = rob_trap_valid;
    assign noop_5w     = rob_trap_valid;
    assign noop_muldiv = rob_trap_valid;
    assign noop_csr    = rob_trap_valid;

    logic rob_can_commit_xcpt;
    // assign rob_can_commit_xcpt = ~(waiting_for_memory_4m | ~icache_dreq_ready | ~rob_issue_rsp.ready);
    assign rob_can_commit_xcpt = ~(waiting_for_memory_4m | ~rob_issue_rsp.ready);

    logic stall_for_sb_full;
    assign stall_for_sb_full = is_st_2d & sb_full;

    assign stall_1f     = waiting_for_memory_4m | ~icache_dreq_ready | data_hazard | ~rob_issue_rsp.ready | stall_for_sb_full;
    assign stall_2d     = waiting_for_memory_4m | ~icache_dreq_ready | data_hazard | ~rob_issue_rsp.ready | stall_for_sb_full;
    assign stall_3e     = waiting_for_memory_4m;
    assign stall_4m     = waiting_for_memory_4m;
    assign stall_muldiv = 0;
    assign stall_csr  = 0;

    // Data memory interface
    assign dmem_if_in.valid = dmem_valid_i;
    assign dmem_if_in.data  = dmem_data_i;

    assign dmem_valid_o = dmem_if_out.valid;
    assign dmem_we_o    = dmem_if_out.we;
    assign dmem_addr_o  = dmem_if_out.addr;
    assign dmem_data_o  = dmem_if_out.data;

    // Muldiv functional unit
    signals_muldiv_in_t  muldiv_input;
    signals_muldiv_out_t muldiv_output;

    // CSR functional unit
    signals_csr_in_t     csr_input;
    signals_csr_out_t    csr_output;

    // =========================================================================
    // = Reorder Buffer
    // =========================================================================

    // // === ISSUE ===
    // From stage_2d
    issue_req_t     rob_issue_req;
    issue_req_csr_t rob_issue_req_csr;
    // To stage_2d
    issue_rsp_t     rob_issue_rsp;

    // // === COMPLETE ===
    // From wb in normal FU
    complete_t      rob_complete_alumem;
    // From wb in muldiv FU
    complete_t      rob_complete_muldiv;
    // From wb in muldiv FU
    complete_csr_t  rob_complete_csr;

    // // === COMMIT ===
    // To pc_sel
    commit_t        rob_commit;
    // To regfile
    commit_rf_t     rob_commit_rf;
    // To store-buffer
    commit_sb_t     rob_commit_sb;
    // To CSR regfile
    commit_csr_t    rob_commit_csr;

    // // === CAM ===
    // From stage_2d
    cam_req_t       rob_cam_req_rs1;
    // To stage_2d
    cam_rsp_t       rob_cam_rsp_rs1;
    // From stage_2d
    cam_req_t       rob_cam_req_rs2;
    // To stage_2d
    cam_rsp_t       rob_cam_rsp_rs2;
    // From stage_2d
    cam_req_csr_t   rob_cam_req_csr;
    // To stage_2d
    cam_rsp_t       rob_cam_rsp_csr;

    // Issue
    assign rob_issue_req.valid   = (s_2d_d.valid | muldiv_input.valid | csr_input.valid) & ~stall_for_sb_full;
    // assign rob_issue_req.valid   = (s_2d_d.valid | xcpt_2d | muldiv_input.valid | csr_input.valid) & ~stall_for_sb_full;
    assign rob_issue_req.pc      = s_1f_q.pc;
    assign rob_issue_req.rd_addr = s_2d_d.rd_addr;
    assign rob_issue_req.xcpt    = xcpt_2d;
    always_comb begin
        if (muldiv_input.valid) begin
            rob_issue_req.dbg_ins = muldiv_input.ins;
            rob_issue_req.is_st   = 0;
            rob_issue_req.rd_we   = 1;
        end else if (csr_input.valid) begin
            rob_issue_req.dbg_ins = csr_input.ins;
            rob_issue_req.is_st   = 0;
            rob_issue_req.rd_we   = 1;
        end else begin
            rob_issue_req.dbg_ins = s_2d_d.ins;
            rob_issue_req.is_st   = s_2d_d.is_st;
            rob_issue_req.rd_we   = s_2d_d.is_wb;
        end
    end

    // Complete alumem
    assign rob_complete_alumem.valid   = s_5w_d.valid;
    assign rob_complete_alumem.robid   = s_5w_d.robid;
    assign rob_complete_alumem.result  = s_5w_d.rd_data;
    assign rob_complete_alumem.xcpt    = s_5w_d.xcpt;
    assign rob_complete_alumem.sbid    = s_5w_d.sbid;

    // Complete muldiv
    assign rob_complete_muldiv.valid   = muldiv_output.valid;
    assign rob_complete_muldiv.robid   = muldiv_output.robid;
    assign rob_complete_muldiv.result  = muldiv_output.result;
    assign rob_complete_muldiv.xcpt    = muldiv_output.xcpt;
    assign rob_complete_muldiv.sbid    = '0;

    // Complete CSR
    assign rob_complete_csr.valid      = csr_output.valid;
    assign rob_complete_csr.robid      = csr_output.robid;
    assign rob_complete_csr.rd_result  = csr_output.rd_data;
    assign rob_complete_csr.csr_result = csr_output.csr_data;
    assign rob_complete_csr.xcpt       = csr_output.xcpt;

    // CAM
    assign rob_cam_req_rs1.valid = rs1_valid;
    assign rob_cam_req_rs1.addr  = rs1_addr;
    assign rob_cam_req_rs2.valid = rs2_valid;
    assign rob_cam_req_rs2.addr  = rs2_addr;
    assign rob_cam_req_csr.valid = csr_re;
    assign rob_cam_req_csr.addr  = csr_raddr;


    rob rob_inst (
        .clk,
        .reset_n,

        .issue_req_i(rob_issue_req),
        .issue_req_csr_i(rob_issue_req_csr),
        .issue_rsp_o(rob_issue_rsp),

        .complete_alumem_i(rob_complete_alumem),
        .complete_muldiv_i(rob_complete_muldiv),
        .complete_csr_i(rob_complete_csr),

        .can_commit_xcpt_i(rob_can_commit_xcpt),
        .commit_o(rob_commit),
        .commit_rf_o(rob_commit_rf),
        .commit_sb_o(rob_commit_sb),
        .commit_csr_o(rob_commit_csr),

        .cam_req_rs1_i(rob_cam_req_rs1),
        .cam_rsp_rs1_o(rob_cam_rsp_rs1),
        .cam_req_rs2_i(rob_cam_req_rs2),
        .cam_rsp_rs2_o(rob_cam_rsp_rs2),
        .cam_req_csr_i(rob_cam_req_csr),
        .cam_rsp_csr_o(rob_cam_rsp_csr)
    );

    // =========================================================================
    // = Stage 1: Fetch
    // =========================================================================

    logic            req_jump_valid;
    logic [XLEN-1:0] req_jump_target;

    always_comb begin
        req_jump_valid  = 0;
        req_jump_target = '0;

        if (rob_trap_valid) begin
            req_jump_valid = 1;
            req_jump_target = 'h2000;
        end
        else if (misprediction) begin
            req_jump_valid = 1;
            if (is_control_3e) req_jump_target = branch_real_target_3e;
            else               req_jump_target = s_3e_d.pc + 4;
        end
        // else if (frontend_trap_valid) begin
        //     req_jump_valid  = 1;
        //     req_jump_target = 'h2000;
        // end
    end

    // buffer jump if an icache request is running
    logic            pending_jump_valid;
    logic [XLEN-1:0] pending_jump_target;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            pending_jump_valid <= 0;
            pending_jump_target <= '0;
        end else begin
            if (icache_dreq_ready) begin
                pending_jump_valid <= 0;
            end else if (req_jump_valid) begin
                pending_jump_valid <= 1;
                pending_jump_target <= req_jump_target;
            end
        end
    end

    // pc
    always @(posedge clk) begin
        if (!reset_n) begin
            pc <= 'h1000;
        end else begin
            if (icache_dreq_ready) begin
                if (pending_jump_valid) begin
                    pc <= pending_jump_target;
                end else if (req_jump_valid) begin
                    pc <= req_jump_target;
                end else if (!stall_1f) begin
                    if (bp_pred_taken) begin
                        pc <= bp_pred_target;
                    end else begin
                        pc <= pc + 4;
                    end
                end
            end
        end
    end

    icache_wrapper #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) icache_inst (
        .clk,
        .reset_n,
        // Data req
        .dreq_valid_i(reset_n),
        .dreq_ready_o(icache_dreq_ready),
        .dreq_addr_i(pc),
        .dreq_width_i(MEMOP_WIDTH_32),
        // Data rsp
        .drsp_data_o(icache_drsp_data),
        .drsp_xcpt_o(xcpt_icache),
        // Fill req
        .freq_valid_o(imem_valid_o),
        .freq_addr_o(imem_addr_o),
        // Fill rsp
        .frsp_valid_i(imem_valid_i),
        .frsp_data_i(imem_data_i)
    );

    logic trap_valid_1f;
    assign trap_valid_1f = xcpt_icache & icache_dreq_ready & ~misprediction & ~pending_jump_valid;

    // pipeline
    always_comb begin
        s_1f_d.valid = icache_dreq_ready;
        s_1f_d.pc = pc;
        s_1f_d.pred_target = bp_pred_target;
        s_1f_d.xcpt = trap_valid_1f;

        if (noop_1f | stall_1f) begin
            s_1f_d.ins = 32'h00000033; // noop (add x0, x0, x0)
            s_1f_d.pred_taken = 0;
        end else begin
            s_1f_d.ins        = icache_drsp_data;
            s_1f_d.pred_taken = bp_pred_taken; // Use BP output
        end
    end

    decoupling_reg #(
        .regtype_t(signals_fetch_t)
    ) decoupling_reg_1f_2d_inst (
        .clk,
        .reset_n,
        .stall_i(stall_2d),
        .d_i(s_1f_d),
        .q_o(s_1f_q)
    );

    // =========================================================================
    // = Stage 2: Decode
    // =========================================================================
    stage_2d #(
        .XLEN(XLEN),
        .NREG(N_PHY_REG)
    ) stage_2d_inst (
        .clk,
        .reset_n,
        // Pipeline input/output
        ._i(s_1f_q),
        ._o_alumem(s_2d_d),
        ._o_muldiv(muldiv_input),
        ._o_csr(csr_input),
        // Write-back - Scalar register
        .rd_we_i(rob_commit_rf.rd_we),
        .rd_addr_i(rob_commit_rf.rd_addr),
        .rd_data_i(rob_commit_rf.rd_data),
        // Write-back - CSR
        .csr_we_i(rob_commit_csr.csr_we),
        .csr_waddr_i(rob_commit_csr.csr_addr),
        .csr_wdata_i(rob_commit_csr.csr_data),
        // Exception
        .xcpt_2d_o(xcpt_2d),
        // Hazard detection
        .noop_i(noop_2d),
        .stall_i(stall_2d),
        .bypass_rs1_sel_i(bypass_rs1_2d_sel),
        .bypass_rs2_sel_i(bypass_rs2_2d_sel),
        .bypass_csr_sel_i(bypass_csr_2d_sel),
        .bypass_rs1_data_i(bypass_rs1_2d_data),
        .bypass_rs2_data_i(bypass_rs2_2d_data),
        .bypass_csr_data_i(bypass_csr_2d_data),
        .bypass_4m_3e_sel_i(bypass_4m_3e_sel),
        .rs1_addr_o(rs1_addr),
        .rs1_valid_o(rs1_valid),
        .rs2_addr_o(rs2_addr),
        .rs2_valid_o(rs2_valid),
        .csr_raddr_o(csr_raddr),
        .csr_re_o(csr_re),
        .is_st_o(is_st_2d),
        .robid_i(rob_issue_rsp.robid),
        .rob_issue_req_csr_o(rob_issue_req_csr),
        .rob_commit_xcpt_valid_i(rob_trap_valid),
        .rob_commit_xcpt_pc_i(rob_commit.pc),
        .sb_alloc_idx_i(sb_alloc_idx),
        .sb_alloc_en_o(sb_alloc_en)
    );

    decoupling_reg #(
        .regtype_t(signals_decode_t)
    ) decoupling_reg_2d_3e_inst (
        .clk,
        .reset_n,
        .stall_i(stall_3e),
        .d_i(s_2d_d),
        .q_o(s_2d_q)
    );

    // =========================================================================
    // = Stage 3: Execute
    // =========================================================================
    stage_3e #(
        .XLEN(XLEN)
    ) stage_3e_inst (
        .clk,
        .reset_n,
        // Pipeline input/output
        ._i(s_2d_q),
        ._o(s_3e_d),
        // Next pc selection
        .pc_sel_o(pc_sel),
        .taken_branch_o(taken_branch),
        // Bypass
        .bypass_4m_3e_data_i(s_4m_d.mem_result),
        // Trap
        .noop_i(noop_3e),
        .stall_i(stall_3e)
    );

    decoupling_reg #(
        .regtype_t(signals_execute_t)
    ) decoupling_reg_3e_4m_inst (
        .clk,
        .reset_n,
        .stall_i(stall_4m),
        .d_i(s_3e_d),
        .q_o(s_3e_q)
    );

    // =========================================================================
    // = Stage 4: Memory
    // =========================================================================
    stage_4m #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) stage_4m_inst (
        .clk,
        .reset_n,
        // Pipeline input/output
        ._i(s_3e_q),
        ._o(s_4m_d),
        // Interface with dmem
        .dmem_o(dmem_if_out),
        .dmem_i(dmem_if_in),
        // Trap
        .noop_i(noop_4m),
        .stall_i(stall_4m),
        .waiting_for_memory_o(waiting_for_memory_4m),
        .flush_i(rob_trap_valid),

        // SB Allocation (Connected to 2D)
        .sb_alloc_en_i(sb_alloc_en),
        .sb_alloc_idx_o(sb_alloc_idx),
        .sb_full_o(sb_full),

        // SB Commit (From ROB)
        .rob_commit_sb_valid_i(rob_commit_sb.valid),
        .rob_commit_sb_idx_i(rob_commit_sb.sbid)
    );

    decoupling_reg #(
        .regtype_t(signals_memory_t)
    ) decoupling_reg_4m_5w_inst (
        .clk,
        .reset_n,
        .stall_i('0),
        .d_i(s_4m_d),
        .q_o(s_4m_q)
    );

    // =========================================================================
    // = Stage 5: Write-back
    // =========================================================================
    always_comb begin
        case (s_4m_q.wb_sel)
            MUX_WB_ALU:
                s_5w_d.rd_data = s_4m_q.alu_result;
            MUX_WB_MEM:
                s_5w_d.rd_data = s_4m_q.mem_result;
            MUX_WB_PC_NEXT:
                s_5w_d.rd_data = s_4m_q.pc + 4;
            default:
                s_5w_d.rd_data = s_4m_q.pc + 4;
        endcase
    end

    always_comb begin
        if (noop_5w) begin
            s_5w_d.valid = 0;
            s_5w_d.is_wb = 0;
            s_5w_d.ins   = 32'h00000033;
        end else begin
            s_5w_d.valid = s_4m_q.valid;
            s_5w_d.is_wb = s_4m_q.is_wb;
            s_5w_d.ins   = s_4m_q.ins;
        end
    end
    assign s_5w_d.rd_addr = s_4m_q.rd_addr;
    assign s_5w_d.robid   = s_4m_q.robid;
    assign s_5w_d.xcpt    = s_4m_q.xcpt;
    assign s_5w_d.sbid    = s_4m_q.sbid;


    // =========================================================================
    // = Multiplication and Division Functional Unit
    // =========================================================================
    muldiv_fu #(
        .OP_DELAY(MULDIV_OP_DELAY)
    ) muldiv_fu_inst (
        .clk,
        .reset_n,
        ._i(muldiv_input),
        ._o(muldiv_output),
        .noop_i(noop_muldiv),
        .stall_i(stall_muldiv)
    );

    // =========================================================================
    // = CSR operations Functional Unit
    // =========================================================================

    csr_fu #(
        .XLEN(XLEN)
    ) csr_fu_inst (
        .clk,
        .reset_n,
        ._i(csr_input),
        ._o(csr_output),
        .noop_i(noop_csr),
        .stall_i(stall_csr)
    );

    // =========================================================================
    // = Hazards and bypasses
    // =========================================================================
    logic [XLEN-1:0] fwd_data_4m;
    always_comb begin
        if (s_4m_d.wb_sel == MUX_WB_MEM) begin
            fwd_data_4m = s_4m_d.mem_result;
        end else if (s_4m_d.wb_sel == MUX_WB_PC_NEXT) begin
            fwd_data_4m = s_4m_d.pc + 4;
        end else begin
            fwd_data_4m = s_4m_d.alu_result;
        end
    end

    logic [XLEN-1:0] fwd_data_3e;
    assign fwd_data_3e = (s_3e_d.wb_sel == MUX_WB_PC_NEXT) ? s_3e_d.pc + 4 : s_3e_d.alu_result;

    fwd_unit #(
        .XLEN(XLEN)
    ) fwd_unit_inst (
        .rs1_2d_i(rs1_addr),
        .rs2_2d_i(rs2_addr),
        .rs1_valid_2d_i(rs1_valid),
        .rs2_valid_2d_i(rs2_valid),
        .is_st_2d_i(is_st_2d),
        // stage 3 inputs
        .valid_3e_i(s_3e_d.valid),
        .rd_3e_i(s_3e_d.rd_addr),
        .rd_is_wb_3e_i(s_3e_d.is_wb & s_3e_d.valid & (s_3e_d.ins != 32'h00000033)),
        .is_ld_3e_i(s_3e_d.is_ld),
        .data_3e_i(fwd_data_3e),
        .robid_3e_i(s_3e_d.robid),
        // stage 4 inputs
        .rd_4m_i(s_4m_d.rd_addr),
        .rd_is_wb_4m_i(s_4m_d.is_wb & s_4m_d.valid & (s_4m_d.ins != 32'h00000033)),
        .data_4m_i(fwd_data_4m),
        .robid_4m_i(s_4m_d.robid),
        // stage 5 inputs
        .rd_5w_i(s_5w_d.rd_addr),
        .rd_is_wb_5w_i(s_5w_d.is_wb & s_5w_d.valid & (s_5w_d.ins != 32'h00000033)),
        .data_5w_i(s_5w_d.rd_data),
        .robid_5w_i(s_5w_d.robid),
        // rob inputs
        .rob_cam_rs1_i(rob_cam_rsp_rs1),
        .rob_cam_rs2_i(rob_cam_rsp_rs2),
        .rob_cam_csr_i(rob_cam_rsp_csr),
        // outputs
        .bypass_rs1_2d_sel_o(bypass_rs1_2d_sel),
        .bypass_rs2_2d_sel_o(bypass_rs2_2d_sel),
        .bypass_csr_2d_sel_o(bypass_csr_2d_sel),
        .bypass_rs1_2d_data_o(bypass_rs1_2d_data),
        .bypass_rs2_2d_data_o(bypass_rs2_2d_data),
        .bypass_csr_2d_data_o(bypass_csr_2d_data),
        .bypass_4m_3e_sel_o(bypass_4m_3e_sel),
        .fwd_unit_hazard_o(data_hazard)
    );

    localparam string _BP_ENABLE = `BP_ENABLE;

    generate
        if (_BP_ENABLE == "yes") begin
            branch_predictor bp_inst (
                .clk(clk),
                .reset_n(reset_n),
                // 1f interface
                .req_pc_i(pc),
                .pred_taken_o(bp_pred_taken),
                .pred_target_o(bp_pred_target),
                // 3e interface
                .upd_valid_i(is_control_3e && s_3e_d.valid),
                .upd_pc_i(s_3e_d.pc),
                .upd_taken_i(branch_real_taken_3e),
                .upd_target_i(branch_real_target_3e),
                .upd_is_cond_i(pc_sel == MUX_PC_BRANCH)
            );
        end
        else begin
            assign bp_pred_taken  = 1'b0;
            assign bp_pred_target = '0;
        end
    endgenerate

    assign is_control_3e = (pc_sel != MUX_PC_NEXT);

    always_comb begin
        branch_real_taken_3e = 1'b0;
        branch_real_target_3e = s_3e_d.pc + 4;

        case (pc_sel)
            MUX_PC_BRANCH: begin
                branch_real_taken_3e = taken_branch;
                if (taken_branch) branch_real_target_3e = s_3e_d.alu_result;
            end
            MUX_PC_JAL, MUX_PC_JALR: begin
                branch_real_taken_3e = 1'b1;
                if (pc_sel == MUX_PC_JALR)
                    branch_real_target_3e = {s_3e_d.alu_result[31:1], 1'b0};
                else
                    branch_real_target_3e = s_3e_d.alu_result;
            end
            default: ;
        endcase
    end

    // detect misprediction
    always_comb begin
        misprediction = 1'b0;
        if (s_3e_d.valid) begin
            if (is_control_3e) begin
                // direction mismatch
                if (s_3e_d.pred_taken != branch_real_taken_3e)
                    misprediction = 1'b1;
                // target mismatch (if taken)
                else if (s_3e_d.pred_taken && (s_3e_d.pred_target != branch_real_target_3e))
                    misprediction = 1'b1;
            end else begin
                // aliasing (predicted taken on non-control instr)
                // We must flush and redirect to the correct next sequential PC
                if (s_3e_d.pred_taken) misprediction = 1'b1;
            end
        end
    end

endmodule

