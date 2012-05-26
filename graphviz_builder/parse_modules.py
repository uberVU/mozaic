# Module loader

import sys
import re
import os

extensions = ['.coffee', '.js']
hash_path = {}

# Module loader function
# argv = command line arguments
def parse_modules(argv):
	base_dir = argv[1] + '/'
	
	for filename in argv[2:]:
		f = open(base_dir + filename, 'r')
		for line in f:
			try: 
				module_line = re.search('\'.*\': \'.*\'', line, 0)
			except:
				pass
			if module_line:
				key = module_line.group().split("'")[1]
				path = module_line.group().split("'")[3]
				# print key, ' -> ', path
				for ext in extensions:
					if os.path.exists(base_dir + path + ext):
						hash_path[key] = base_dir + path + ext
						# print path + ext
						break

	return hash_path



#parse_modules(sys.argv)
					
		

