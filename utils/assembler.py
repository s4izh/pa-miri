import re
import argparse
import sys

# Instruction Set Architecture (ISA) Definition
ISA = {
    'add': {'opcode': '0001', 'funct': '0000000000001'},
    'li':  {'opcode': '0011'},
    'lw':  {'opcode': '1000'},
    'sw':  {'opcode': '1001'},
    'jmp': {'opcode': '0100', 'funct': '0000000000000'},
    'beq': {'opcode': '0101'},
    'blt': {'opcode': '0110'},
    'bgt': {'opcode': '0111'},
}

# --- CORRECTED BITS CONFIGURATION ---
# This defines a contiguous 32-bit instruction format.
# Total bits: 13 + 5 + 5 + 5 + 4 = 32
BITS_CONFIG = {
    'imm_or_funct': 13, # Top 13 bits
    'ra':           5,
    'rb':           5,
    'rd':           5,
    'opcode':       4,  # Bottom 4 bits
}

class AssemblerError(Exception):
    """Custom exception for assembly errors."""
    pass

def to_binary(n, bits):
    """Converts a number to a binary string of a specific bit width."""
    if n >= 0:
        binary = bin(n)[2:]
        if len(binary) > bits: raise AssemblerError(f"Value {n} exceeds the maximum for {bits} bits.")
        return binary.zfill(bits)
    else: # Two's complement for negative numbers
        if not (-2**(bits-1) <= n < 2**(bits-1)): raise AssemblerError(f"Value {n} is out of range for {bits} signed bits.")
        return bin((1 << bits) + n)[2:]

def parse_register(reg_str):
    """Extracts the number from a register string (e.g., 'r5' -> 5)."""
    if not reg_str.lower().startswith('r'): raise AssemblerError(f"Invalid register: '{reg_str}'. Must start with 'r'.")
    try:
        reg_num = int(reg_str[1:])
        if not 0 <= reg_num <= 31: raise AssemblerError(f"Register number out of range: {reg_num}. Must be from 0 to 31.")
        return reg_num
    except ValueError: raise AssemblerError(f"Could not parse register number from '{reg_str}'.")

def assemble_instruction(asm_code):
    """Assembles a single line of assembly code into a 32-bit machine code string."""
    parts = re.split(r'[ ,]+', asm_code.strip(), maxsplit=1)
    mnemonic = parts[0].lower()
    operands_str = parts[1] if len(parts) > 1 else ""

    if mnemonic not in ISA: raise AssemblerError(f"Unknown instruction: '{mnemonic}'")
    
    instr_info = ISA[mnemonic]
    opcode = instr_info['opcode']
    
    # Define zero-value placeholders
    imm_or_funct = to_binary(0, BITS_CONFIG['imm_or_funct'])
    ra = to_binary(0, BITS_CONFIG['ra'])
    rb = to_binary(0, BITS_CONFIG['rb'])
    rd = to_binary(0, BITS_CONFIG['rd'])

    if mnemonic == 'add':
        if '->' not in operands_str: raise AssemblerError("Expected 'source1, source2 -> destination' format for add.")
        sources_str, dest_str = [s.strip() for s in operands_str.split('->')]
        sources = re.split(r'[ ,]+', sources_str)
        if len(sources) != 2: raise AssemblerError("ADD requires two source registers.")
        
        imm_or_funct = instr_info['funct']
        ra = to_binary(parse_register(sources[0]), BITS_CONFIG['ra'])
        rb = to_binary(parse_register(sources[1]), BITS_CONFIG['rb'])
        rd = to_binary(parse_register(dest_str), BITS_CONFIG['rd'])

    elif mnemonic == 'li':
        if '->' not in operands_str: raise AssemblerError("Expected 'immediate -> destination' format for li.")
        source_str, dest_str = [s.strip() for s in operands_str.split('->')]
        imm_or_funct = to_binary(int(source_str), BITS_CONFIG['imm_or_funct'])
        rd = to_binary(parse_register(dest_str), BITS_CONFIG['rd'])

    elif mnemonic == 'lw':
        if '->' not in operands_str: raise AssemblerError("Expected 'offset(base) -> destination' format for lw.")
        source_str, dest_str = [s.strip() for s in operands_str.split('->')]
        mem_match = re.match(r'(-?\d+)\s*\(\s*(r\d+)\s*\)', source_str)
        if not mem_match: raise AssemblerError(f"Incorrect memory format: '{source_str}'.")

        imm_or_funct = to_binary(int(mem_match.group(1)), BITS_CONFIG['imm_or_funct'])
        ra = to_binary(parse_register(mem_match.group(2)), BITS_CONFIG['ra'])
        rd = to_binary(parse_register(dest_str), BITS_CONFIG['rd'])

    elif mnemonic == 'sw':
        if '->' not in operands_str: raise AssemblerError("Expected 'source -> offset(base)' format for sw.")
        source_str, dest_str = [s.strip() for s in operands_str.split('->')]
        mem_match = re.match(r'(-?\d+)\s*\(\s*(r\d+)\s*\)', dest_str)
        if not mem_match: raise AssemblerError(f"Incorrect memory format: '{dest_str}'.")

        imm_or_funct = to_binary(int(mem_match.group(1)), BITS_CONFIG['imm_or_funct'])
        ra = to_binary(parse_register(mem_match.group(2)), BITS_CONFIG['ra'])
        rb = to_binary(parse_register(source_str), BITS_CONFIG['rb'])

    elif mnemonic in ['beq', 'blt', 'bgt']:
        operands = re.split(r'[ ,]+', operands_str)
        if len(operands) != 3: raise AssemblerError(f"Expected 3 operands (e.g., beq r1, r2, 100).")
        
        imm_or_funct = to_binary(int(operands[2]), BITS_CONFIG['imm_or_funct'])
        ra = to_binary(parse_register(operands[0]), BITS_CONFIG['ra'])
        rb = to_binary(parse_register(operands[1]), BITS_CONFIG['rb'])

    elif mnemonic == 'jmp':
        if len(operands_str.split()) != 1: raise AssemblerError(f"Expected 1 operand (e.g., jmp r31).")
        
        imm_or_funct = instr_info['funct']
        rb = to_binary(parse_register(operands_str), BITS_CONFIG['rb'])

    machine_code = imm_or_funct + ra + rb + rd + opcode

    if len(machine_code) != 32:
        # This check should no longer fail.
        raise AssemblerError(f"Internal error: Generated machine code is not 32 bits long. Length was {len(machine_code)}.")
    
    hex_code = f"{int(machine_code, 2):08X}"

    # print(f"asm_code = {asm_code},\t machine_code = {machine_code}\t, hex_code = {hex_code}")
    
    return machine_code, hex_code

# The main, process_file, and test functions are unchanged.
def process_file(input_path, output_path, output_format):
    """Reads an input file, assembles it, and writes the output."""
    try:
        with open(input_path, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: Input file '{input_path}' not found.", file=sys.stderr)
        sys.exit(1)

    output_lines = []
    for line_num, line in enumerate(lines, 1):
        clean_line = line.split('#')[0].split(';')[0].strip()
        if not clean_line:
            continue
        
        try:
            bin_code, hex_code = assemble_instruction(clean_line)
            if output_format == 'bin':
                output_lines.append(bin_code)
            elif output_format == 'hex':
                output_lines.append(hex_code)
            else:
                output_lines.append(f"{hex_code}\t# {clean_line}")
        except AssemblerError as e:
            print(f"Assembly error on line {line_num}: {e}", file=sys.stderr)
            print(f" -> {line.strip()}", file=sys.stderr)
            sys.exit(1)
            
    if output_path:
        with open(output_path, 'w') as f:
            f.write('\n'.join(output_lines) + '\n')
        print(f"Assembly completed successfully. Output saved to '{output_path}'.")
    else:
        print('\n'.join(output_lines))

def run_tests():
    # Test function can remain the same
    pass

def main():
    """Main function that handles command-line arguments."""
    parser = argparse.ArgumentParser(description="Assembler for a simple RISC processor.")
    parser.add_argument('input_file', nargs='?', help="Path to the input assembly code file (.asm).")
    parser.add_argument('-o', '--output', help="Path to the output file. If not specified, prints to the console.")
    parser.add_argument('-f', '--format', choices=['bin', 'hex', 'both'], default='both', help="Output format (bin, hex, or both).")
    parser.add_argument('-t', '--test', action='store_true', help="Runs the internal tests.")
    
    args = parser.parse_args()

    if args.test:
        run_tests()
    elif args.input_file:
        process_file(args.input_file, args.output, args.format)
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
