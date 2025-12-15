#pragma once

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <map>
#include <sys/types.h>

uint8_t hex_to_int(char c);
uint32_t hex_to_int(char *line);
int read_file_to_map(FILE *fd, std::map<uint32_t,uint32_t> *map);
