-- TODO have a table to relate env variables to config variables
-- and verify that they are all set with a function internally
-- I essentially want the api to be harness.env and pass a config table with the variables
build_dir = os.getenv("BUILD_DIR")
if not build_dir then
    error("BUILD_DIR not set")
end

-- should be harness.env(key = value table) instead
harness.set_build_dir(build_dir)

local cosim = harness.add_task({
    tasks_namespace = "cosim",
    name = "build_dpi",
    source_dir = "cosim",
    command = "git submodule init && git submodule update && BUILD_DIR=$abs_out_dir make -C $source_dir $abs_out_dir/cosim_dpi.a",
    inputs = harness.list_files("cosim/**"),
    vars = {
        debug = "0"
    },
    outputs = {
        lib = "cosim_dpi.a"
    }
})

local crt = harness.add_task({
    name = "compile_crt",
    tasks_namespace = "env",
    command = "riscv32-none-elf-gcc $flags -c programs/crt.s -o $abs_out_dir/crt.o",
    inputs = { "programs/crt.s" },
    vars = {
        flags = "-march=rv32im -mabi=ilp32 -Iprograms"
    },
    outputs = {
        obj = "crt.o"
    }
})

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
            command = "riscv32-none-elf-gcc $flags -T $ld -nostdlib -Wl,-Map,$map $crt_obj $obj -o $elf",
            inputs = { "obj" },
            outputs = {
                { name = "elf", filename = "prog.elf" },
                { name = "map", filename = "prog.map" }
            }
        },
        {
            name = "rom",
            command = "riscv32-none-elf-objcopy -O verilog --verilog-data-width 16 " ..
                      "--only-section=.text* " ..
                      "$elf $out_dir/rom.tmp && " ..
                      "cat $out_dir/rom.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $rom && " ..
                      "rm $out_dir/rom.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "rom", filename = "rom.hex" }
            }
        },
        {
            name = "sram",
            command = "riscv32-none-elf-objcopy -O verilog --verilog-data-width 16 " ..
                      "--only-section=.rodata* " ..
                      "--only-section=.data* " ..
                      "--only-section=.sdata* " ..
                      "--only-section=.bss* " ..
                      "--only-section=.sbss* " ..
                      "$elf $out_dir/sram.tmp && " ..
                      "cat $out_dir/sram.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $sram && " ..
                      "rm $out_dir/sram.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "sram", filename = "sram.hex" }
            }
        },
        {
            name = "mem",
            command = "riscv32-none-elf-objcopy -O verilog --verilog-data-width 16 " ..
                      "--only-section=.text* " ..
                      "--only-section=.rodata* " ..
                      "--only-section=.data* " ..
                      "--only-section=.sdata* " ..
                      "--only-section=.bss* " ..
                      "--only-section=.sbss* " ..
                      "$elf $out_dir/sramunified.tmp && " ..
                      "cat $out_dir/sramunified.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $mem && " ..
                      "rm $out_dir/sramunified.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "mem", filename = "mem.hex" }
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
        flags = "-march=rv32im -mabi=ilp32",
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
        flags = "-march=rv32im -mabi=ilp32 -O3",
        ld = "programs/link.ld"
    },
    program_overrides = {},
    sw_deps = {}
})

harness.add_suite({
    name = "benchmarks",
    base_dir = "programs/benchmarks",
    pattern = "**/*.c",
    tool = "riscv_gcc",
    plusargs = {},
    default_vars = {
        flags = "-march=rv32im -mabi=ilp32",
        ld = "programs/link.ld",
        crt_obj = harness.abspath(crt.outputs.obj) 
    },
    program_overrides = {},
    sw_deps = { crt.outputs.obj } 
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
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "rv_pa3.cosim",
    filelist = "sim/rv_pa3/cosim/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT_CYCLES=10000",
    vars = {
          COSIM_DPI_LIB = harness.abspath(cosim.outputs.lib)
    },
    sw_deps = { cosim.outputs.lib },
})

harness.add_testbench({
    name = "gandul.anyrom",
    filelist = "sim/gandul/anyrom/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +SRAM_FILE=$mem +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "gandul.cosim",
    filelist = "sim/gandul/cosim/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +SRAM_FILE=$mem +TIMEOUT_CYCLES=10000",
    vars = {
          COSIM_DPI_LIB = harness.abspath(cosim.outputs.lib)
    },
    sw_deps = { cosim.outputs.lib },
})

harness.add_testbench({
    name = "common.rob",
    filelist = "sim/common/rob/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "common.store_buffer",
    filelist = "sim/common/store_buffer/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +TIMEOUT_CYCLES=10000",
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
    name = "rv_pa3_cosim",
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

harness.add_experiment({
    name = "store_buffer",
    testbench = "common.store_buffer",
    param_sets = { "base" },
    suites = {}, -- standalone HW test, no software suite involved
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul",
    testbench = "gandul.anyrom",
    param_sets = { "base" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul-benchmarks",
    testbench = "gandul.anyrom",
    param_sets = { "base" },
    suites = { "benchmarks" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul-cosim",
    testbench = "gandul.cosim",
    param_sets = { "base" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul-cosim-benchmarks",
    testbench = "gandul.cosim",
    param_sets = { "base", "unified" },
    suites = { "benchmarks" },
    simulators = { "verilator" }
})
