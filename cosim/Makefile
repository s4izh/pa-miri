AR = ar
CC = g++
ARFLAGS = rcs
CCFLAGS = -lc

# all: cosim_dpi.a cosim_dpi.so
all: cosim_dpi.a

cosim_dpi.a: cosim_dpi.o
	$(AR) $(ARFLAGS) $@ $^

cosim_dpi.o: c/cosim_dpi.cpp c/cosim_dpi.hpp
	$(CC) $(CFLAGS) $< -c -o $@

clean:
	rm *.o *.a
