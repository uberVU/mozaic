#!/usr/bin/python

# docco-husky cannot parse CoffeeScript block comments so we have to manually
# transform them to single line ones while preserving the tab space

import sys
from os import walk

def isComment(line):
    return "###" in line

def main(argv):
    path = argv[0]
    for (path, dirs, files) in walk(path):
        for filename in files:
            data = ""
            inBlock = False
            for line in open(path + '/' + filename, 'r'):
                if isComment(line):
                    inBlock = not inBlock
                else:
                    if inBlock:
                        if line.strip():
                            start = len(line) - len(line.lstrip())
                            line = line[:start] + "# " + line[start:]
                        data += line
                    else:
                        data += line
            open(path + '/' + filename, 'w').writelines(data)

if __name__ == "__main__":
   main(sys.argv[1:])
