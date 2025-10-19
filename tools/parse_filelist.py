import sys
import re
import os

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <filename>")
        sys.exit(1)
    filename = sys.argv[1]
    result_string = ""
    for file in read_filelist(filename):
        result_string += file + ' ';
    print(result_string[:-1])

def bash_substitute(s: str, variables: dict = None) -> str:
    """
    Perform bash-like variable substitution on a string.
    Args:
        s (str): Input string containing $VAR, ${VAR} or $(VAR).
        variables (dict, optional): Dictionary of variables to use. If None, environment
                variables are used.
    Returns:
        str: String with variables substituted.
    """
    if variables is None:
        variables = os.environ

    # Match $VAR or ${VAR}
    pattern = re.compile(r'\$(\w+)|\$\{([^}]+)\}|\$\(([^)]+)\)')

    def replacer(match):
        var_name = match.group(3)
        return variables[var_name]

    return pattern.sub(replacer, s)

def read_filelist(filename: str) -> str:
    """
    Read filelist with path "filename" and returns all recursively-read contents appended
            by a space characters (" ").
    Args:
        filename (str): path to the file to read and analyze.
    Returns:
        str: String with filelist contents variable-substituted.

    """
    ret = []
    file = open(filename, 'r')
    for line in file:
        line = bash_substitute(line)
        if line.startswith("//"):
            continue
        elif line.startswith("-f"):
            ret = ret + (read_filelist(line[3:-1:]))
        else:
            ret.append(line[0:-1:])
    return ret


if __name__ == "__main__":
    main()
