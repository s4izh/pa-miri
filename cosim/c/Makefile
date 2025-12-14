AR = ar
CC = g++
ARFLAGS = rcs
CCFLAGS = -lc

# all: cosim_dpi.a cosim_dpi.so
all: cosim_dpi.a

cosim_dpi.a: cosim_dpi.o
	$(AR) $(ARFLAGS) $@ $^

cosim_dpi.so: cosim_dpi.o
	$(CC) $(CFLAGS) -shared -Wl,-soname,lib$@ $^ -o $@

cosim_dpi.o: cosim_dpi.cpp cosim_dpi.hpp
	$(CC) $(CFLAGS) $< -c -o $@

clean:
	rm *.o *.a
