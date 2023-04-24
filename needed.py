#!/usr/bin/python3
# apt install graphviz
# pip3 install angr angr-utils
import angr
import sys
import dataclasses
import os
import subprocess
import pathlib
import itertools
import networkx
import logging
logging.getLogger('angr').setLevel('CRITICAL')
logging.getLogger('cle').setLevel('CRITICAL')
start = None


glibc_list = ["memset","strncmp","strlen","snprintf",'strcmp',  'memcmp', 'strncmp', 'memset',"memcpy"]
mocked_list = ["__dynamic_pr_debug","down_write","down_read","up_read", "up_write","__request_module",
			   "wait_for_completion_killable_timeout","try_module_get","__module_get","kmalloc_node",
			   "panic","check_panic_on_warn","__ubsan_handle_out_of_bounds","kzalloc","kmalloc_caches",
			   "_printk","kmemdup","kmalloc_trace","module_put","strscpy","strlcpy","kfree_sensitive",
			   "kfree","__kmalloc"] + glibc_list

@dataclasses.dataclass
class CGItem:
    """Class for keeping track of an item in inventory."""
    function: str
    calls: list
    obj: str
    is_import: bool
    is_export: bool
  
  
# Build an internal name we use for this function.
#	Exported functions: funcname
#	Other    functions: objfile__funcname
def getname(f, o, exports, imports):
	name = f.name
	if start == name:
		return name
	if name not in imports and name  not in exports:
		name = o + "__" + name
	return name

def get_exported_functions(obj):
	exports = []
	for symbol in obj.symbols:
		if str(symbol._type) != "SymbolType.TYPE_FUNCTION":
			#print(symbol._type, symbol.name)
			continue
		if not symbol.is_export:
			continue
		exports.append(symbol.name)
	return exports


# Build a simple call-graph made in the form 
#	[dict: name -> CGItem] where name comes from getname()
def simple_cg(o):
	print("Handling: %s"%o, file=sys.stderr)
	
	proj = angr.Project(o, load_options={'auto_load_libs': False})
	cfg = proj.analyses.CFGFast()
	queue = list(cfg.kb.functions.values())
	obj = proj.loader.main_object
	imports = list(obj.imports.keys())
	exports = get_exported_functions(obj)
	
	ret = {}
	seen = set()
	
	# For each function in the obj file
	while len(queue) != 0:
		f = queue.pop()
		if f in seen:
			continue
		
		seen.add(f)
		
		cg = CGItem(f.name, [], o, f.name in imports, f.name in exports)
		ret[getname(f, o, exports, imports)] = cg
		
		# For each call from this function
		for cs in f.get_call_sites():
			t = f.get_call_target(cs)
			called = cfg.kb.functions[t]
			cg.calls.append(getname(called, o, exports, imports))
			queue.append(called)
			#print(f.name ," -> ", called.name)
			#print(called)
			#print(block.pp())
			
	return ret

searched = set()

# This is a slow, ugly and imprecise way of finding obj files that may contain a function name 
def find_possibility(func):
	if func in searched:
		return []
	searched.add(func)
	
	# Grep for that function name in .c files
	cmd = f"grep -l --include '*.c' -RE '^(|[^=+]+\s)\s*{func}[^;=+]+$' linux/"
	o = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE).stdout
	ret = []
	for opt in o.decode().splitlines():
		# If a corresponding o file exists, add it as a possibility
		optfile = opt[:-1] + "o"
		if os.path.exists(optfile):
			ret.append(optfile)
	
	# If our horrible search returns too many results, ignore them
	if len(ret) > 3:
		print(f"Cannot find good option for {func}", file=sys.stderr)
		return []
		
	return ret

# Given a simple_cg, list all imports that are neither mocked nor in the simple_cg
#	starts should be function names, if used for non-exported functions, see naming in getname()
def find_used_imports(s_cg, starts):
	seen = set()
	if type(starts) is not str:
		queue = list(starts)
	else:
		queue = [start]
		
	used = set()
	missing = set()
	while len(queue) != 0:
		atn = queue.pop()
		if atn in seen:
			continue
			
		seen.add(atn)
		if atn not in s_cg or atn in mocked_list:
			missing.add(atn)
			continue
		at = s_cg[atn]
		used.add(at.obj)
		
		for call in at.calls:
			if call not in s_cg or call in mocked_list:
				missing.add(call)
			else:
				queue.append(call)
	return used, missing


# Takes a simple cg and a starting function,
# returns a filtered callgraph including only called & exported functions.
# The format is a list of function name tuples where t[0] is the calling function, and t[1] is the called function
def simplecg_to_stringcg(s_cg, start):
	def get_ext_calls(at, seen=set()):
		for call in at.calls:
			if call in seen:
				continue
			seen.add(call)
			if call not in s_cg or s_cg[call].is_export or call in mocked_list:
				yield call
			else:
				yield from get_ext_calls(s_cg[call], seen)
			
	graph = []
	count = 0
	mcount = 0
	seen = set()
	queue = [start]
	#print("Queue is: ",queue,file=sys.stderr)
	ret = set()
	while len(queue) != 0:
		atn = queue.pop()
		if atn in seen:
			continue
		#print("Atn is: ",atn,file=sys.stderr)
		seen.add(atn)
		at = s_cg[atn]
		#print(at)
		for call in get_ext_calls(at):
			#print("Call: ",call)
			graph.append((atn, call))
			if call in mocked_list:
				graph.append((call, "mocked_%d"%(mcount)))
				mcount +=1 
			elif call in s_cg:
				queue.append(call)
			else:
				graph.append((call, "unknown_%d"%(count)))
				count += 1
	return graph

# Get o files in the same directory (if recurse, also looks in subdirectories)
def get_related_o_files(o, recurse=True):
	seen = set()
	basepath = os.path.dirname(o)
	
	for path in pathlib.Path(basepath).rglob('*.o'):
		p = path.as_posix()
		seen.add(p)
		yield p
	
	if not recurse:
		return
		
	while os.path.basename(basepath) != "linux":
		for p in get_related_o_files(basepath, False):
			if p in seen:
				continue
			yield p
		basepath = os.path.dirname(basepath)

# Load cg from file o and merge all functions (except imported) into the simple_cg r
def add_objfile(o, r, loaded):
	if o in loaded:
		return False
	loaded.append(o)
	rm = simple_cg(o)
	for k in rm.keys():
		v = rm[k]
		if v.is_import:
			continue
		r[k] = v
	return True

	
if __name__ == "__main__":
	r = {}
	# 
	if len(sys.argv) < 3:
		print("Usage: ./script Function_to_start_At objfile_to_start_at [additional_obj_files...]")
		print("Attempts to identify obj-files that you need to be able to run Function_to_start_At.")
		print("Outputs a call-graph in a .dot format to stdout (and the as the needed .o files to stderr)")
		print("Adjust in-source param DEPTH if you want a deeper graph. The parameter does not mean exact number of call depth, but rather search iterations")
		exit(1)
	
	DEPTH = 4
	flist = sys.argv[2:]
	start = sys.argv[1]
	
	loaded = []
	for f in flist:
		add_objfile(f, r, loaded)

	cont = True
	queue = [start]
	used = set()
	for i in range(DEPTH):
		print("DEBUG: Queue is: ", queue, file=sys.stderr)
		new_used, new_missing = find_used_imports(r, queue)
		used = used.union(new_used)
		missing = new_missing
		
		new = False
		for func in missing:
			if func in mocked_list:
				continue
			
			for possibility in find_possibility(func):
				if add_objfile(possibility, r, loaded):
					new = True
		if new:
			queue = list(missing)
			continue
			
		print("DEBUG: We miss:", file=sys.stderr)
		print(missing, file=sys.stderr)
		print("DEBUG: We use:", file=sys.stderr)
		print(used, file=sys.stderr)
		while True:
			print("Next: ",file=sys.stderr, end="")
			n = input()
			if n == '':
				break
			if not os.path.exists(n):
				print("Could not find file: %s"%n, file=sys.stderr)
				continue
			break
		
		if n == '':
			break
		add_objfile(n, r, loaded)
		queue = list(missing)
	
	print("We miss:", file=sys.stderr)
	print(missing, file=sys.stderr)
	print("We use:", file=sys.stderr)
	print(used, file=sys.stderr)
	graph = simplecg_to_stringcg(r, start)
	print("digraph graphname {")
	for (a,b) in graph:
		print(f"{a} -> {b};")
	print("}")
