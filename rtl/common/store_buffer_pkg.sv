`ifndef _STORE_BUFFER_PKG_M_
`define _STORE_BUFFER_PKG_M_

`include "harness_params.svh"

package store_buffer_pkg;
    typedef logic[$clog2(`N_ENTRIES_SB)-1:0] sbid_t;
endpackage

`endif
