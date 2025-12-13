AR = ar
CC = gcc
ARFLAGS = rcs
CCFLAGS = -L/path/to/verilator/lib -lverilator

all: cosim_dpi.a cosim_dpi.so

cosim_dpi.a: cosim_dpi.o
	$(AR) $(ARFLAGS) $@ $^

cosim_dpi.so: cosim_dpi.o
	$(CC) $(CFLAGS) -shared -Wl,-soname,lib$@ $^ -o $@

cosim_dpi.o: cosim_dpi.c
	$(CC) $(CFLAGS) -c $^ -o $@

clean:
	rm *.o *.so *.a
