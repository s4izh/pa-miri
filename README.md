# pa-miri

## Dev environment

Just run:

```
nix develop
```

And start developing:

```
$ make help
Usage: make <target> [FILELIST=<filelist_path>][CORE=<core_name>]

Available targets:
  all        - Compile and simulate the component (default)
  simulate   - Run the simulation and generate waveforms
  compile    - Compile the source files if they have changed
  waves      - Look at the generated wavefile
  check      - Check SystemVerilog syntax
  clean      - Remove all generated files
  cores      - List all available cores
  help       - Show this help message
```

Available cores are under `cores/*`, to run an action
for a specific core just run:

```
make <action> CORE=<core>
```

Every command has a dependency on every other command it needs, so theres no
need to run all the commands if you just want to see the waves, just go `make
waves CORE=pa_cpu_mini1`.

## Cores

### `pa_cpu_mini1`

```
make check CORE=pa_cpu_mini1
make compile CORE=pa_cpu_mini1
make simulate CORE=pa_cpu_mini1
make waves CORE=pa_cpu_mini1
```

## Libraries

All libraries under `lib/src` will get automatically added to the compilation
if the modules need them.

TODO: add testbenches for the libraries.
