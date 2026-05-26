class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)

    virtual fifo_if vif;
    uvm_analysis_port #(fifo_item) read_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        read_port = new("read_port", this);
        if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "No virtual interface in config_db")
    endfunction

    // rd_valid is asserted by the DUT one cycle after a successful rd_en.
    // rd_data holds the popped value. Sample both at posedge+#1 after NBAs settle.
    task run_phase(uvm_phase phase);
        fifo_item item;
        forever begin
            @(posedge vif.clk); #1;
            if (vif.rd_valid) begin
                item      = fifo_item::type_id::create("read_item");
                item.op   = FIFO_READ;
                item.data = vif.rd_data;
                read_port.write(item);
            end
        end
    endtask

endclass
