import rv_datapath_pkg::*;
import rv_branch_compare_pkg::*;
import memory_controller_pkg::*;
import alu_pkg::*;
import rv_isa_pkg::*;

module rv_pa3# (
    parameter int XLEN = 32,
    parameter int N_PHY_REG = 32,
    parameter int WAYS = 4,
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128
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
    logic trap_valid, xcpt_illegal_ins, xcpt_icache, xcpt_dcache;
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

    // Hazard control
    logic rs1_valid, rs2_valid;
    logic [$clog2(N_PHY_REG)-1:0] rs1_addr, rs2_addr;
    logic noop_1f, noop_2d, noop_3e, noop_4m;
    logic stall_1f, stall_2d, stall_3e, stall_4m;
    logic data_hazard;
    // Signals from 2d to forwarding unit (to avoid UNOPTFLAT)
    logic is_st_2d;
    // Bypass control
    logic bypass_rs1_2d_sel, bypass_rs2_2d_sel;
    logic [XLEN-1:0] bypass_rs1_2d_data, bypass_rs2_2d_data;
    logic bypass_4m_3e_sel;

    logic waiting_for_memory_4m;

    logic icache_dreq_ready;
    logic icache_drsp_hit;
    logic [XLEN-1:0] icache_drsp_data;

    // local assigns
    // assign trap_valid =
    //     imem_trap_i.valid |
    //     (dmem_trap_i.valid & s_4m_d.valid) |
    //     (xcpt_illegal_ins & s_2d_d.valid);

    // are we jumping or branching in the execute stage?
    logic jump_or_branch_3e;
    assign jump_or_branch_3e = (taken_branch || pc_sel[1]) && s_2d_q.valid;

    // use s_1f_q.valid (input to decode) instead of s_2d_d.valid (output of decode)
    // this avoids the circular loop where trap -> noop -> s_2d_d.valid=0 -> trap=0
    // we must manually mask with jump_or_branch_3e because a branch should kill the trap
    logic trap_valid_1f, trap_valid_2d, trap_valid_4m;

    assign trap_valid_1f = xcpt_icache & s_1f_d.valid & ~jump_or_branch_3e;
    assign trap_valid_2d = xcpt_illegal_ins & s_1f_q.valid & ~jump_or_branch_3e;
    assign trap_valid_4m = xcpt_dcache & s_3e_q.valid;

    assign trap_valid = trap_valid_1f | trap_valid_2d | trap_valid_4m;

    assign noop_1f  = jump_or_branch_3e | trap_valid;
    assign noop_2d  = jump_or_branch_3e | trap_valid;
    assign noop_3e  = trap_valid_4m;
    assign noop_4m  = trap_valid_4m;

    assign stall_1f = waiting_for_memory_4m | ~icache_drsp_hit | data_hazard;
    assign stall_2d = waiting_for_memory_4m | ~icache_drsp_hit | data_hazard;
    assign stall_3e = waiting_for_memory_4m | ~icache_drsp_hit;
    assign stall_4m = waiting_for_memory_4m;

    // Data memory interface
    assign dmem_if_in.valid = dmem_valid_i;
    assign dmem_if_in.data  = dmem_data_i;

    assign dmem_valid_o = dmem_if_out.valid;
    assign dmem_we_o    = dmem_if_out.we;
    assign dmem_addr_o  = dmem_if_out.addr;
    assign dmem_data_o  = dmem_if_out.data;

    // =========================================================================
    // = Stage 1: Fetch
    // =========================================================================
    // pc
    always @(posedge clk) begin
        if (!reset_n) begin
            pc <= 'h1000;
        end else begin
            if (trap_valid) begin
                pc <= 'h2000;
            end else begin
                if (!stall_1f) begin
                    case (pc_sel)
                        MUX_PC_NEXT:
                            pc <= pc + 4;
                        MUX_PC_BRANCH:
                            if (taken_branch)
                                pc <= s_3e_d.alu_result;
                            else
                                pc <= pc + 4;
                        MUX_PC_JAL:
                            pc <= s_3e_d.alu_result;
                        MUX_PC_JALR:
                            pc <= {s_3e_d.alu_result[31:1], 1'b0};
                    endcase
                end
            end
        end
    end

    icache #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) icache_inst (
        .clk,
        .reset_n,
        // Data req
        .dreq_valid_i(reset_n & !(trap_valid_2d | trap_valid_4m)),
        .dreq_ready_o(icache_dreq_ready),
        .dreq_addr_i(pc),
        // Data rsp
        .drsp_hit_o(icache_drsp_hit),
        .drsp_data_o(icache_drsp_data),
        .drsp_xcpt_o(xcpt_icache),
        // Fill req
        .freq_valid_o(imem_valid_o),
        .freq_addr_o(imem_addr_o),
        // Fill rsp
        .frsp_valid_i(imem_valid_i),
        .frsp_data_i(imem_data_i)
    );

    // pipeline
    assign s_1f_d.valid = icache_drsp_hit;
    assign s_1f_d.pc = pc;
    always_comb begin
        if (noop_1f | stall_1f | !(icache_drsp_hit)) begin
            s_1f_d.ins = 32'h00000033; // noop (add x0, x0, x0)
        end else begin
            s_1f_d.ins = icache_drsp_data;
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
        ._o(s_2d_d),
        // Write-back
        .rd_we_i(s_5w_d.is_wb),
        .rd_addr_i(s_5w_d.rd_addr),
        .rd_data_i(s_5w_d.rd_data),
        // Exceptions
        .xcpt_illegal_ins_o(xcpt_illegal_ins),
        // Hazard detection
        .noop_i(noop_2d),
        .stall_i(stall_2d),
        .bypass_rs1_sel_i(bypass_rs1_2d_sel),
        .bypass_rs2_sel_i(bypass_rs2_2d_sel),
        .bypass_rs1_data_i(bypass_rs1_2d_data),
        .bypass_rs2_data_i(bypass_rs2_2d_data),
        .bypass_4m_3e_sel_i(bypass_4m_3e_sel),
        .rs1_addr_o(rs1_addr),
        .rs1_valid_o(rs1_valid),
        .rs2_addr_o(rs2_addr),
        .rs2_valid_o(rs2_valid),
        .is_st_o(is_st_2d)
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
        .dcache_xcpt_o(xcpt_dcache)
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

    assign s_5w_d.ins     = s_4m_q.ins;
    assign s_5w_d.is_wb   = s_4m_q.is_wb && s_4m_q.valid;
    assign s_5w_d.rd_addr = s_4m_q.rd_addr;

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

    // hazard_unit hazard_unit_inst (
    //     .jump_or_branch_3e_i(jump_or_branch_3e),
    //     .trap_i(trap_valid),
    //     .data_hazard_i(data_hazard),
    //     .noop_o(noop),
    //     .stall_o(stall)
    // );


    fwd_unit #(
        .XLEN(XLEN)
    ) fwd_unit_inst (
        .rs1_2d_i(rs1_addr),
        .rs2_2d_i(rs2_addr),
        .rs1_valid_2d_i(rs1_valid),
        .rs2_valid_2d_i(rs2_valid),
        .is_st_2d_i(is_st_2d),
        // stage 3 inputs
        .rd_3e_i(s_3e_d.rd_addr),
        .rd_is_wb_3e_i(s_3e_d.is_wb),
        .is_ld_3e_i(s_3e_d.is_ld),
        .data_3e_i(s_3e_d.alu_result), // I think that if 3E is PC_NEXT (JAL), this is wrong
        // stage 4 inputs
        .rd_4m_i(s_4m_d.rd_addr),
        .rd_is_wb_4m_i(s_4m_d.is_wb),
        .data_4m_i(fwd_data_4m), // TODO: proper mux this in stage 4
        // stage 5 inputs
        .rd_5w_i(s_5w_d.rd_addr),
        .rd_is_wb_5w_i(s_5w_d.is_wb),
        .data_5w_i(s_5w_d.rd_data),
        // outputs
        .bypass_rs1_2d_sel_o(bypass_rs1_2d_sel),
        .bypass_rs2_2d_sel_o(bypass_rs2_2d_sel),
        .bypass_rs1_2d_data_o(bypass_rs1_2d_data),
        .bypass_rs2_2d_data_o(bypass_rs2_2d_data),
        .bypass_4m_3e_sel_o(bypass_4m_3e_sel),
        .fwd_unit_hazard_o(data_hazard)
    );

endmodule

