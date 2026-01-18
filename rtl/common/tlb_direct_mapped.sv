`ifndef _TLB_DIRECT_MAPPED_M_
`define _TLB_DIRECT_MAPPED_M_

module tlb_direct_mapped#(
    parameter int ADDR_WIDTH = 32,
    parameter int PAGE_SIZE = 4096,
    parameter int NUM_ENTRIES = 16
)(
    input logic clk,
    input logic reset_n,

    // Insert a new translation (tw = translation write).
    // it will be readable in the next cycle
    input logic we_i,
    input logic [ADDR_WIDTH-1:0] vaddr_tw_i,
    input logic [ADDR_WIDTH-1:0] paddr_tw_i,

    // Read a translation.
    // The translation is being output(ed) in the same cycle it is requested
    input logic [ADDR_WIDTH-1:0] vaddr_i,
    output logic [ADDR_WIDTH-1:0] paddr_o,
    output logic hit_o
);
    localparam int OFFSET_WIDTH = $clog2(PAGE_SIZE);
    localparam int INDEX_WIDTH = $clog2(NUM_ENTRIES);
    localparam int TAG_WIDTH = ADDR_WIDTH - OFFSET_WIDTH - INDEX_WIDTH;

    typedef struct packed {
        logic [TAG_WIDTH-1:0] tag;
        logic [ADDR_WIDTH-1:0] paddr;
        logic valid;
    } tlb_entry_t;

    tlb_entry_t tlb[NUM_ENTRIES];

    logic [TAG_WIDTH-1:0] vtag;
    logic [INDEX_WIDTH-1:0] index;
    logic [OFFSET_WIDTH-1:0] offset;

    assign vtag = vaddr_i[ADDR_WIDTH-1 -: TAG_WIDTH];
    assign index = vaddr_i[OFFSET_WIDTH +: INDEX_WIDTH];
    assign offset = vaddr_i[0 +: OFFSET_WIDTH];

    logic [TAG_WIDTH-1:0] vtag_tw;
    logic [INDEX_WIDTH-1:0] index_tw;
    logic [OFFSET_WIDTH-1:0] offset_tw;

    assign vtag_tw = vaddr_tw_i[ADDR_WIDTH-1 -: TAG_WIDTH];
    assign index_tw = vaddr_tw_i[OFFSET_WIDTH +: INDEX_WIDTH];
    assign offset_tw = vaddr_tw_i[0 +: OFFSET_WIDTH];

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                tlb[i].valid <= 0;
            end
        end else if (we_i) begin
            tlb[index_tw].tag <= vtag_tw;
            tlb[index_tw].paddr <= index_tw;
            tlb[index_tw].valid <= 1;
        end
    end

    always_comb begin
        if (tlb[index].valid && (tlb[index].tag == vtag)) begin
            hit_o = 1;
            paddr_o = {tlb[index].paddr[ADDR_WIDTH-1 -: TAG_WIDTH], offset};
        end else begin
            hit_o = 0;
            paddr_o = '0;
        end
    end

`endif
