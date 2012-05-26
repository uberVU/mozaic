
import sys
import re
from parse_modules import *
from node import *

visit = {}

graph_viz_header = ' digraph modules { concentrate=true; size="30,40"; '

graph_viz_footer = ' } '

# Retrieves all the tags from the define header
# Note: one define per file
def get_module_defines(filename):
	f = open(filename, 'r')
	ok_define = False
	for line in f:
		define_line = re.search("^\s*define\s*\[.*\]", line, 0)
		if define_line:
			ok_define = True
			define_list = re.search("'.*'", define_line.group(), 0)
			if define_list:
				define_list = define_list.group()
				define_list = define_list.split(", ")
				# return list of define modules 
				if len(define_list) > 0:
					# print define_list
					return [x.replace("cs!", "").
								replace("'", "") 
								for x in define_list]
				return []
			return []
	if not ok_define:
	  return []
				

# Build graph structure (depth first)
def depth_first(node):
	visit[node.get_key()] = True

	# get our defines from the file associated with node key
	module_defines = get_module_defines(hash_path[node.get_key()])
	
	# print node.get_key(), '->'
	for module_def in module_defines:
		# print module_def
		# define new child
		child = Node(module_def)
		# add child to parent
		node.add_child(child)

		if (child.get_key in visit) and (not visit[child.get_key()]):
			depth_first(node.get_children()[-1])


# Print parent->child using graphviz format
def format(parent, child):
	return '"' + parent + '" -> "' + child + '"'


# Print parent using graphviz format
def format_single(parent):
	return '"' + parent + '"'
		

# Print graph structure (depth first)
def print_graph(node):
	visit[node.get_key()] = True
	
	for child in node.get_children():
		print format(node.get_key(), child.get_key())
		if (child.get_key in visit) and (not visit[child.get_key()]):
			depth_first(child)


# Reset visit hash
def reset_visit(hashp):
	for k in hashp:
		visit[k] = False


# Build graph - main function
def build_graph(argv):
	hash_path = parse_modules(argv)
	graph_roots = []

	reset_visit(hash_path)

	for k, v in hash_path.items():
		if not visit[k]:		
			root = Node(k)
			graph_roots.append(root)
			depth_first(root)

	reset_visit(hash_path)

	# print using graph viz notation
	print graph_viz_header
	for root in graph_roots:
		if len(root.get_children()) > 0:
			print_graph(root)
		else:
			print format_single(root.get_key())
	print graph_viz_footer


# Running
build_graph(sys.argv)

