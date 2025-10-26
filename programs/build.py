#!/usr/bin/env python3
import argparse
import subprocess
import os
import sys
import atexit

# --- Global Configuration ---

# Docker image containing the RISC-V toolchain
IMAGE_NAME = "riscv-toolchain"

# RISC-V toolchain prefix
TOOL_PREFIX = "riscv32-unknown-elf-"

# Tool commands (avoids repeating strings)
CC = f"{TOOL_PREFIX}gcc"
AS = f"{TOOL_PREFIX}as"
OBJCOPY = f"{TOOL_PREFIX}objcopy"
OBJDUMP = f"{TOOL_PREFIX}objdump"

# Default flags for the compiler and linker. Can be overridden on the command line.
# These are typical for bare-metal rv32i development.
DEFAULT_COMPILER_FLAGS = ["-march=rv32i", "-mabi=ilp32"]
DEFAULT_LINKER_FLAGS = ["-nostdlib", "-Wl,-Map,output.map"]


# --- Helper Functions ---

# A set to keep track of temporary files for automatic cleanup on exit
_temp_files = set()

def cleanup_temp_files():
    """Clean up any temporary files created during the build."""
    if not _temp_files:
        return
    print("\n--- Cleaning up temporary files ---")
    for f in _temp_files:
        try:
            os.remove(f)
            print(f"Removed: {f}")
        except OSError:
            pass

# Register the cleanup function to be called on script exit
atexit.register(cleanup_temp_files)


def run_command(command, **kwargs):
    """A helper function to execute a command, print it, and check for errors."""
    print(f"+ {' '.join(command)}")
    try:
        subprocess.run(command, check=True, **kwargs)
    except subprocess.CalledProcessError as e:
        print(f"\nError: Command failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)
    except FileNotFoundError:
        print("\nError: 'docker' command not found. Is Docker installed and in your PATH?", file=sys.stderr)
        sys.exit(1)


def is_assembly(filename):
    """Check if a file is an assembly file based on its extension."""
    return filename.lower().endswith('.s')


def main():
    """Main function to parse arguments and run the build process."""
    parser = argparse.ArgumentParser(
        description="A Python build tool for RISC-V projects using a Docker toolchain.",
        add_help=False
    )

    g = parser.add_argument_group('Build Tool Options')
    g.add_argument('source_files', nargs='+', help="One or more source files (.c, .s) to compile.")
    g.add_argument('-o', '--output', required=True, help="Name of the final output ELF file.")
    g.add_argument('--asm', metavar='FILE', help="Optional: Generate an assembly listing file.")
    g.add_argument('--hex', metavar='FILE', help="Optional: Generate a Verilog HEX file for ROMs.")
    g.add_argument('-h', '--help', action='help', help="Show this help message and exit.")
    
    args, passthrough_flags = parser.parse_known_args()

    # --- Docker Command Setup ---
    try:
        user_flag = f"{os.getuid()}:{os.getgid()}"
    except AttributeError: # For Windows compatibility
        user_flag = ""

    docker_base_cmd = [
        'docker', 'run', '--rm',
        '--user', user_flag,
        '-v', f'{os.getcwd()}:/work',
        '--workdir', '/work',
        IMAGE_NAME
    ]

    # --- Build Logic ---
    object_files = []
    
    # Step 1: Compile each source file into an object file (.o)
    print("--- Step 1: Compiling source files ---")
    for source_file in args.source_files:
        obj_file = os.path.splitext(source_file)[0] + ".o"
        object_files.append(obj_file)
        _temp_files.add(obj_file) # Register for cleanup

        compile_cmd = docker_base_cmd + [
            CC,
            '-c',  # Compile only, do not link
            '-o', obj_file,
            source_file,
            *DEFAULT_COMPILER_FLAGS,
            *passthrough_flags  # User-provided flags override defaults
        ]
        run_command(compile_cmd)
    
    # Step 2: Link all object files into a final ELF file
    print("\n--- Step 2: Linking object files ---")
    # Update the default map file name to match the output
    linker_flags = [flag.replace('output.map', f'{os.path.splitext(args.output)[0]}.map') for flag in DEFAULT_LINKER_FLAGS]
    
    link_cmd = docker_base_cmd + [
        CC,
        '-o', args.output,
        *object_files,
        *linker_flags,
        *passthrough_flags # Pass flags to linker as well
    ]
    run_command(link_cmd)

    # Step 3: (Optional) Disassemble the ELF
    if args.asm:
        print("\n--- Step 3: Generating Assembly Listing ---")
        objdump_cmd = docker_base_cmd + [OBJDUMP, '-d', args.output]
        with open(args.asm, 'w') as f_asm:
            run_command(objdump_cmd, stdout=f_asm)
        print(f"Assembly listing saved to '{args.asm}'")

    # Step 4: (Optional) Convert ELF to Verilog HEX
    if args.hex:
        print("\n--- Step 4: Generating Verilog HEX File ---")
        temp_hex_file = f"{args.output}.tmp.hex"
        _temp_files.add(temp_hex_file)

        # Step 4a: Create intermediate hex file
        objcopy_cmd = docker_base_cmd + [
            OBJCOPY, '-O', 'verilog', '--verilog-data-width=4', args.output, temp_hex_file
        ]
        run_command(objcopy_cmd)

        # Step 4b: Reformat to be simulator-friendly
        print("Formatting final HEX file...")
        with open(temp_hex_file, 'r') as f_in, open(args.hex, 'w') as f_out:
            content = f_in.read().replace(' ', '\n').replace('\r', '')
            f_out.write(content)
        print(f"Verilog HEX file saved to '{args.hex}'")

    print(f"\nBuild successful. Final ELF output is '{args.output}'.")


if __name__ == "__main__":
    main()
