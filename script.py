import os

#TODO: take it from argument
path = "core~"

def isComment(line):
    comment = "###"
    if comment in line:
        return True
    return False

for (path, dirs, files) in os.walk(path):
    for file in files:
        data = ""
        inBlock = False
        with open(path + '/' + file, 'r') as f:
            for line in f:
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
        with open(path + '/' + file, 'w') as f:
            f.writelines(data)
