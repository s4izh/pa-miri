#include "cosim_dpi_util.hpp"

static uint8_t hex_to_int(char c);
static uint32_t hex_to_uint32(char *line);

static uint8_t hex_to_int(char c) {
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
static uint32_t hex_to_uint32(char *line) {
    uint32_t ret = 0;
    for (int i = 0; i < sizeof(uint32_t)*2 || line[i] == '\n' || line[i] == '\0'; ++i) {
        ret = (ret << 4) + hex_to_int(line[i]);
    }
    return ret;
}

int read_file_to_map(FILE *fd, std::map<uint32_t,uint32_t> *map, uint32_t cacheline_bytes) {
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
            current_addr = hex_to_uint32(line+1) * (cacheline_bytes/4);
            continue;
        }
        // We parse data
        for (int i = 0; i < cacheline_bytes/4; ++i) {
            uint32_t word_addr = current_addr+(cacheline_bytes/4)-1-i;
            uint32_t word_data = hex_to_uint32(line+(i*8)); // 8 = sizeof(uint32_t)*2
            map->insert( { word_addr, word_data } );
            printf("Inserted word 0x%08x into address 0x%08x\n", word_data, word_addr<<2); // fixme
        }
        current_addr += cacheline_bytes/4;
    }
    return 0; // all ok
}

