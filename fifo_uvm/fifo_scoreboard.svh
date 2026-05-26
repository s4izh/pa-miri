class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp_expected #(fifo_item, fifo_scoreboard) expected_export;
    uvm_analysis_imp_actual   #(fifo_item, fifo_scoreboard) actual_export;

    fifo_item        expected_q[$];
    int unsigned     passed, failed;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        expected_export = new("expected_export", this);
        actual_export   = new("actual_export",   this);
    endfunction

    // Called synchronously when the driver attempts a write.
    // Mirrors the DUT: only accept the item if the model isn't already full.
    function void write_expected(fifo_item item);
        if (expected_q.size() < 8)   // DEPTH=8 -- matches tb instantiation
            expected_q.push_back(item);
    endfunction

    // Called synchronously when the monitor sees a read complete.
    function void write_actual(fifo_item item);
        fifo_item exp;
        if (expected_q.size() == 0) begin
            `uvm_error("SCOREBOARD", "actual item arrived with empty expected queue")
            failed++;
            return;
        end
        exp = expected_q.pop_front();
        if (item.data !== exp.data) begin
            `uvm_error("SCOREBOARD", $sformatf(
                "MISMATCH: expected 0x%02h  got 0x%02h", exp.data, item.data))
            failed++;
        end else begin
            `uvm_info("SCOREBOARD", $sformatf(
                "OK  data=0x%02h", item.data), UVM_MEDIUM)
            passed++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD", $sformatf(
            "Results: %0d passed, %0d failed", passed, failed), UVM_NONE)
        if (failed == 0 && expected_q.size() == 0)
            `uvm_info("SCOREBOARD", "TEST PASSED", UVM_NONE)
        else
            `uvm_error("SCOREBOARD", "TEST FAILED")
    endfunction

endclass
