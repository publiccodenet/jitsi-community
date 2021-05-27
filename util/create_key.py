from os import urandom
import sys
from base64 import b64encode

def main():
    file_path = sys.argv[1]
    config_variable = sys.argv[2]

    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    line_to_replace = None
    for i in range(len(lines)):
        if lines[i].startswith(config_variable):
            parts = lines[i].split('=')
            if len(parts) < 2 or parts[1].strip() == "":
                line_to_replace = i
            else:
                return
    
    key = b64encode(urandom(32)).decode('ascii')
    config_line = f'{config_variable} = "{key}"\n' 
    if line_to_replace == None:
        lines.append(config_line)
    else:
        lines[line_to_replace] = config_line

    with open(file_path, 'w') as f:
        f.writelines(lines)

if __name__ == "__main__":
    main()

