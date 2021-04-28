from os import urandom
import sys

def main():
    with open(sys.argv[1], 'w') as f:
        salt = urandom(32)
        f.write(salt.hex())

if __name__ == "__main__":
    main()

