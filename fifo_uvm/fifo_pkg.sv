package fifo_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_expected)
    `uvm_analysis_imp_decl(_actual)

    `include "fifo_item.svh"
    `include "fifo_sequencer.svh"
    `include "fifo_sequence.svh"
    `include "fifo_driver.svh"
    `include "fifo_monitor.svh"
    `include "fifo_scoreboard.svh"
    `include "fifo_agent.svh"
    `include "fifo_env.svh"
    `include "fifo_test.svh"

endpackage
