#!/bin/bash

if [ -z $1 ]; then
    echo "USAGE: ./modelsim.sh <tcl-file>"
    exit 1
fi

TCL_FILE=$(readlink -m $1)

# Imatge de docker d'Àlex Torregrossa
sudo docker run\
    --rm\
    -ti\
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw\
    -v "${PROJ_DIR}":${PROJ_DIR}:rw\
    -e DISPLAY=${DISPLAY}\
    -e LD_LIBRARY_PATH=/root/altera/13.0sp1/modelsim_ase/lib32\
    -e HOME=${HOME}\
    -e PROJ_DIR=${PROJ_DIR}\
    -e SV_FILES="${SV_FILES}"\
    --user=$(id -u):$(id -g)\
    --ipc=host --cap-add=SYS_PTRACE\
    --security-opt seccomp=unconfined\
    registry.gitlab.com/axtaor/practicas-ac2:latest\
    bash -c "cd ${PROJ_DIR} && /root/altera/13.0sp1/modelsim_ase/linux/vsim -do ${TCL_FILE}"

