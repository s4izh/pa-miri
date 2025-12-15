AR = ar
CC = g++
ARFLAGS = rcs
CFLAGS = -Irve/include

BUILD_DIR = build

DPI_SOURCES = $(wildcard dpi/*.cpp)
# RVE_SOURCES = $(wildcard rve/src/*.c)
RVE_SOURCES = rve/src/decoder.c

DPI_TARGETS = $(patsubst %.cpp,${BUILD_DIR}/%.o,${DPI_SOURCES})
RVE_TARGETS = $(patsubst %.c,${BUILD_DIR}/%.o,${RVE_SOURCES})

TARGETS = ${DPI_TARGETS} ${RVE_TARGETS}


# all: cosim_dpi.a cosim_dpi.so
all: cosim_dpi.a

cosim_dpi.a: ${TARGETS}
	$(AR) $(ARFLAGS) $@ $^

${BUILD_DIR}/%.o: %.cpp
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $< -c -o $@

${BUILD_DIR}/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $< -c -o $@

clean:
	rm -rf ${BUILD_DIR} *.a
