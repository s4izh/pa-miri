AR = ar
CC = g++
ARFLAGS = rcs
CFLAGS = -Irve/include -Icosim

BUILD_DIR ?= build

COSIM_SOURCES = $(wildcard cosim/*.cpp)
RVE_SOURCES = rve/src/decoder.c

COSIM_TARGETS = $(patsubst %.cpp,${BUILD_DIR}/%.o,${COSIM_SOURCES})
RVE_TARGETS = $(patsubst %.c,${BUILD_DIR}/%.o,${RVE_SOURCES})

TARGETS = ${RVE_TARGETS} ${COSIM_TARGETS}


# all: cosim_dpi.a cosim_dpi.so
all: ${BUILD_DIR}/cosim_dpi.a

${BUILD_DIR}/cosim_dpi.a: ${TARGETS}
	$(AR) $(ARFLAGS) $@ $^

${BUILD_DIR}/%.o: %.cpp
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $< -c -o $@

${BUILD_DIR}/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $< -c -o $@

clean:
	rm -rf ${BUILD_DIR} *.a
