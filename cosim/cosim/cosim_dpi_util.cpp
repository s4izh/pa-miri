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
    for (int i = 0; (i < sizeof(uint32_t)*2); ++i) {
        ret = (ret << 4) + hex_to_int(line[i]);
    }
    return ret;
}

int read_file_to_map(FILE *fd, std::map<uint32_t,uint32_t> *map, uint32_t cacheline_bytes) {
    size_t len;
    ssize_t read_len;
    uint32_t current_addr;
    char *line;
    const uint32_t cacheline_words = cacheline_bytes/4;
    len = 0;
    current_addr = 0;
    while ((read_len = getline(&line, &len, fd)) != -1) {
        if (read_len <= 1) {
            // Nothing to parse
            continue;
        }
        if (line[0] == '@') {
            // Parse an address
            current_addr = hex_to_uint32(line+1) * cacheline_words;
            printf("Changed address to 0x%08x\n", current_addr);
            continue;
        }
        // Parse data
        char *tmp = line;
        while (*tmp != '\n' && *tmp != '\0') ++tmp;
        int words_in_line = (tmp - line)/8;
        printf("Found line with %d words\n", words_in_line);

        for (int i = 0; i < words_in_line; ++i) {
            uint32_t word_addr = current_addr+(words_in_line)-1-i;
            uint32_t word_data = hex_to_uint32(line+(i*8)); // 8 = sizeof(uint32_t)*2
            map->insert( { word_addr, word_data } );
            printf("Inserted word 0x%08x into address 0x%08x\n", word_data, word_addr<<2);
        }
        current_addr += words_in_line;
    }
    return 0; // all ok
}

