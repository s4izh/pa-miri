#include "cosim_dpi_util.hpp"

uint8_t hex_to_int(char c) {
    uint8_t ret = 0;
    if (c >= '0' && c <= '9') {
        ret = c - '0';
    } else if (c >= 'a' && c <= 'f') {
        ret = c - 'a' + 10;
    } else if (c >= 'A' && c <= 'F') {
        ret = c - 'A' + 10;
    }
    return ret;
}

// pre: line is a \n terminated string
uint32_t hex_to_int(char *line) {
    uint32_t ret = 0;
    while (*line != '\n') {
        ret = (ret << 4) + hex_to_int(*line);
        ++line;
    }
    return ret;
}

int read_file_to_map(FILE *fd, std::map<uint32_t,uint32_t> *map) {
    size_t len;
    ssize_t read_len;
    uint32_t current_addr;
    char *line;
    len = 0;
    current_addr = 0;
    while ((read_len = getline(&line, &len, fd)) != -1) {
        if (read_len <= 1) {
            // Nothing to parse
            continue;
        }
        if (line[0] == '@') {
            // Parse an address
            current_addr = hex_to_int(line+1);
            continue;
        }
        // We parse data
        map->insert({current_addr, hex_to_int(line)});
        current_addr++;
    }
    return 0; // all ok
}

