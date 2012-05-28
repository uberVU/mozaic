# Class Node - for graph structure
class Node():
	def __init__(self, key):
		self._key = key
		self._next = []

	def get_key(self):
		return self._key

	def add_child(self, child):
		self._next.append(child)

	def get_children(self):
		return self._next


