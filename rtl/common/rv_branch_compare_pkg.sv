`ifndef _RV_BRANCH_COMPARE_PKG_
`define _RV_BRANCH_COMPARE_PKG_

package rv_branch_compare_pkg;

    typedef enum logic [2:0] {
        COMPARE_OP_BEQ,
        COMPARE_OP_BNE,
        COMPARE_OP_BLT,
        COMPARE_OP_BGE,
        COMPARE_OP_BGEU,
        COMPARE_OP_BLTU,
        COMPARE_OP_NONE
    } compare_op_e;

endpackage

`endif
