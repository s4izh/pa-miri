#pragma once

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <map>
#include <sys/types.h>

int read_file_to_map(FILE *fd, std::map<uint32_t,uint32_t> *map, uint32_t cacheline_bytes);
