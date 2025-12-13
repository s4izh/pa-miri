#!/bin/bash

make -C c/
verilator -sv --cc --exe --build --main sv/test.sv $(pwd)/c/cosim_dpi.a
