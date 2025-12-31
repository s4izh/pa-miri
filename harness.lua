harness.set_build_dir("build")

harness.add_tool({
    name = "riscv_gcc",
    actions = {
        {
            name = "compile",
            command = "riscv32-none-elf-gcc $flags -Iprograms -c $in -o $obj",
            inputs = {},
            outputs = {
                { name = "obj", filename = "prog.o" }
            }
        },
        {
            name = "link",
            command = "riscv32-none-elf-gcc $flags -T $ld -nostdlib -Wl,-Map,$map $obj -o $elf",
            inputs = { "obj" },
            outputs = {
                { name = "elf", filename = "prog.elf" },
                { name = "map", filename = "prog.map" }
            }
        },
        {
            name = "rom",
            command = "riscv32-none-elf-objcopy -O verilog --verilog-data-width 16 --only-section=.text* $elf $out_dir/rom.tmp && " ..
                      "cat $out_dir/rom.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $rom && " ..
                      "rm $out_dir/rom.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "rom", filename = "rom.hex" }
            }
        },
        {
            name = "sram",
            command = "riscv32-none-elf-objcopy -O verilog --verilog-data-width 16 --only-section=.data* --only-section=.sdata* --only-section=.bss* --only-section=.sbss* $elf $out_dir/sram.tmp && " ..
                      "cat $out_dir/sram.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $sram && " ..
                      "rm $out_dir/sram.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "sram", filename = "sram.hex" }
            }
        }
    }
})

-- Software Suite definitions
harness.add_suite({
    name = "isa",
    base_dir = "programs/tohost_tests",
    pattern = "**/*.s",
    tool = "riscv_gcc",
    plusargs = {},
    default_vars = {
        flags = "-march=rv32i -mabi=ilp32",
        ld = "programs/link.ld"
    },
    program_overrides = {},
    sw_deps = {}
})

harness.add_suite({
    name = "isa_opt",
    base_dir = "programs/tohost_tests",
    pattern = "**/*.s",
    tool = "riscv_gcc",
    plusargs = {},
    default_vars = {
        flags = "-march=rv32i -mabi=ilp32 -O3",
        ld = "programs/link.ld"
    },
    program_overrides = {},
    sw_deps = {}
})

-- Simulator definitions
harness.add_simulator({
    name = "verilator",
    compile_rule = "verilator -j 8 --cc --binary --build -O3 --trace-fst --trace-structs --timing -f $filelist --top-module top_tb_wrapper --Mdir $out_dir -o Vtop",
    outputs = {
        { name = "bin", filename = "Vtop" }
    },
    default_run_rule = "$bin $plusargs"
})

-- Testbench definitions
harness.add_testbench({
    name = "rv_pa3.anyrom",
    filelist = "sim/rv_pa3/anyrom/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "rv_pa3.cosim",
    filelist = "sim/rv_pa3/cosim/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT=10000",
    sw_deps = { "cosim_dpi" }
})

harness.add_testbench({
    name = "common.rob",
    filelist = "sim/common/rob/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +TIMEOUT=10000",
    sw_deps = {}
})

-- Parameter set definitions
harness.add_param_set({
    name = "base",
    defines = { UNIFIED = "0" },
    plusargs = {},
    sim_templates = {}
})

harness.add_param_set({
    name = "unified",
    defines = { UNIFIED = "1" },
    plusargs = {},
    sim_templates = {}
})

harness.add_experiment({
    name = "regression",
    testbench = "rv_pa3.anyrom",
    param_sets = { "base", "unified" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "opt",
    testbench = "rv_pa3.anyrom",
    param_sets = { "base" },
    suites = { "isa", "isa_opt" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "cosim",
    testbench = "rv_pa3.cosim",
    param_sets = { "base" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "rob",
    testbench = "common.rob",
    param_sets = { "base" },
    suites = {}, -- standalone HW test, no software suite involved
    simulators = { "verilator" }
})
