import re
import argparse
import sys

# Instruction Set Architecture (ISA) Definition
# 'format_type': 'R', 'I', 'J'
# 'opcode': The 4-bit binary value for the instruction
# 'funct': The 13-bit binary value for Type-R instructions
#  we dont use the format type yet, just hardcode the assembler
ISA = {
    'add': {'format_type': 'R', 'opcode': '0000', 'funct': '0000000000001'},
    'lw':  {'format_type': 'I', 'opcode': '0001'},
    'sw':  {'format_type': 'I', 'opcode': '0010'},
    'beq': {'format_type': 'I', 'opcode': '0011'},
    'blt': {'format_type': 'I', 'opcode': '0100'},
    'bge': {'format_type': 'I', 'opcode': '0101'},
    'jmp': {'format_type': 'R', 'opcode': '0110', 'funct': '0000000000000'},
    'li':  {'format_type': 'I', 'opcode': '0111'},
}

BITS_CONFIG = {
    'funct': 13,
    'rb': 5,
    'ra': 5,
    'rd': 5,
    'opcode': 4,
    'offset': 18,
    'address': 28
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
    # Split mnemonic from the rest of the line (corrected to use maxsplit keyword)
    parts = re.split(r'[, ]+', asm_code.strip(), maxsplit=1)
    
    mnemonic = parts[0].lower()
    operands_str = parts[1] if len(parts) > 1 else ""

    if mnemonic not in ISA: raise AssemblerError(f"Unknown instruction: '{mnemonic}'")
    
    instr_info = ISA[mnemonic]
    format_type = instr_info['format_type']
    opcode = instr_info['opcode']
    machine_code = ""

    # Instructions that DO NOT use '->' syntax (branches, jumps)
    if mnemonic in ['beq', 'blt', 'bge']:
        operands = re.split(r'[, ]+', operands_str)
        if len(operands) != 3: raise AssemblerError(f"Incorrect syntax. Expected 3 operands (e.g., beq r1, r2, 100).")
        ra = to_binary(parse_register(operands[0]), BITS_CONFIG['ra'])
        rd = to_binary(parse_register(operands[1]), BITS_CONFIG['rd'])
        offset = to_binary(int(operands[2]), BITS_CONFIG['offset'])
        machine_code = offset + ra + rd + opcode
    elif mnemonic == 'jmp':
        if len(operands_str.split()) != 1: raise AssemblerError(f"Incorrect syntax. Expected 1 operand (e.g., jmp r31).")
        ra = to_binary(parse_register(operands_str), BITS_CONFIG['ra'])
        rd = to_binary(0, BITS_CONFIG['rd'])
        rb = to_binary(0, BITS_CONFIG['rb'])
        funct = instr_info['funct']
        machine_code = funct + rb + ra + rd + opcode
    # Instructions that DO use 'source -> destination' syntax
    else:
        if '->' not in operands_str:
            raise AssemblerError(f"Incorrect syntax for '{mnemonic}'. Expected 'source -> destination' format.")
        
        source_str, dest_str = [s.strip() for s in operands_str.split('->')]
        if not source_str or not dest_str:
            raise AssemblerError("Incomplete 'source -> destination' syntax.")

        if mnemonic == 'add':
            rd = to_binary(parse_register(dest_str), BITS_CONFIG['rd'])
            sources = re.split(r'[, ]+', source_str)
            if len(sources) != 2: raise AssemblerError("ADD requires two source registers (e.g., add r1, r2 -> r3).")
            ra = to_binary(parse_register(sources[0]), BITS_CONFIG['ra'])
            rb = to_binary(parse_register(sources[1]), BITS_CONFIG['rb'])
            funct = instr_info['funct']
            machine_code = funct + rb + ra + rd + opcode
        elif mnemonic == 'li':
            rd = to_binary(parse_register(dest_str), BITS_CONFIG['rd'])
            offset = to_binary(int(source_str), BITS_CONFIG['offset'])
            ra = to_binary(0, BITS_CONFIG['ra']) # 'ra' field is not used, set to zero
            machine_code = offset + ra + rd + opcode
        elif mnemonic == 'lw':
            rd = to_binary(parse_register(dest_str), BITS_CONFIG['rd'])
            mem_match = re.match(r'(-?\d+)\s*\(\s*(r\d+)\s*\)', source_str)
            if not mem_match: raise AssemblerError(f"Incorrect memory format in source: '{source_str}'.")
            offset = to_binary(int(mem_match.group(1)), BITS_CONFIG['offset'])
            ra = to_binary(parse_register(mem_match.group(2)), BITS_CONFIG['ra'])
            machine_code = offset + ra + rd + opcode
        elif mnemonic == 'sw':
            # For SW, the source register is encoded in the 'rd' field
            rd = to_binary(parse_register(source_str), BITS_CONFIG['rd'])
            mem_match = re.match(r'(-?\d+)\s*\(\s*(r\d+)\s*\)', dest_str)
            if not mem_match: raise AssemblerError(f"Incorrect memory format in destination: '{dest_str}'.")
            offset = to_binary(int(mem_match.group(1)), BITS_CONFIG['offset'])
            ra = to_binary(parse_register(mem_match.group(2)), BITS_CONFIG['ra'])
            machine_code = offset + ra + rd + opcode

    if len(machine_code) != 32: raise AssemblerError(f"Internal error: Generated machine code is not 32 bits long.")
    
    hex_code = f"{int(machine_code, 2):08X}"
    return machine_code, hex_code

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
            
    # Write to output file or print to console
    if output_path:
        with open(output_path, 'w') as f:
            f.write('\n'.join(output_lines) + '\n')
        print(f"Assembly completed successfully. Output saved to '{output_path}'.")
    else:
        print('\n'.join(output_lines))

def run_tests():
    """Runs a set of predefined tests."""
    print("--- Running Test Mode (Syntax: source -> destination) ---")
    test_cases = [
        # Valid cases
        ("add r2, r3 -> r1", True), ("li 1024 -> r5", True), ("lw 128(r2) -> r5", True),
        ("sw r10 -> -4(r30)", True), ("beq r1, r2, 100", True), ("jmp r31", True),
        # Expected error cases
        ("add r1, r2, r3", False),
        ("li r1, 100", False),
        ("add r1 -> r2", False),
        ("li -> r1", False),
        ("sw 128(r2) -> r5", False),
    ]
    
    passed_count = 0
    for i, (case, should_pass) in enumerate(test_cases, 1):
        try:
            _, hex_code = assemble_instruction(case)
            if should_pass:
                print(f"Test {i:02d}: PASSED - '{case}' -> {hex_code}")
                passed_count += 1
            else:
                print(f"Test {i:02d}: FAILED - '{case}' should have failed but was assembled.")
        except AssemblerError as e:
            if not should_pass:
                print(f"Test {i:02d}: PASSED - '{case}' failed as expected ({e})")
                passed_count += 1
            else:
                print(f"Test {i:02d}: FAILED - '{case}' should have been assembled but failed ({e})")
    
    print(f"--- Result: {passed_count}/{len(test_cases)} tests passed ---")

def main():
    """Main function that handles command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Assembler for a simple RISC processor with 'source -> destination' syntax.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument('input_file', nargs='?', help="Path to the input assembly code file (.asm).")
    parser.add_argument('-o', '--output', help="Path to the output file. If not specified, prints to the console.")
    parser.add_argument(
        '-f', '--format',
        choices=['bin', 'hex', 'both'],
        default='both',
        help="Output format:\n"
             "bin:  Binary machine code only.\n"
             "hex:  Hexadecimal machine code only.\n"
             "both: Hexadecimal with original code as comments (default)."
    )
    parser.add_argument('-t', '--test', action='store_true', help="Runs the internal tests instead of assembling a file.")
    
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
