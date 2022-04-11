@tool
extends Node

#const OP_ASSIGN := ["=", "+=", "-=", "*=", "/="]
const OP_ASSIGN := [" = ", " += ", " -= ", " *= ", " /= "]
const OP_RELATION := ["==", "!=", ">", "<", ">=", "<="]
const OP_ARITHMETIC := ["+", "-", "*", "/", "%"]
const OP_LOGICAL := ["and", "or", "not", "&&", "||", "!"]
const OP_ALL := OP_ASSIGN + OP_RELATION + OP_ARITHMETIC + OP_LOGICAL
const BUILT_IN := ["true", "false", "null"]

var _commands := {}
var _expr := Expression.new()

func add_command(call: Variant, desc := "", id := ""):
	var obj: Object = call.get_object() if call is Callable else call[0]
	var method: String = call.get_method() if call is Callable else call[1]
	id = id if id else method
	var args = UObject.get_arg_info(obj, method)
	var arg_names := args.map(func(x): return "%s:%s" % [x.name, UType.get_name_from_type(x.type)])
	print("> '%s' [%s]: %s" % [id, " ".join(arg_names), desc])
	_commands[id] = {
		call=call,
		desc=desc,
		args=args
	}

func test(t: String) -> bool:
	if UString.is_wrapped(t, "(", ")"):
		t = UString.unwrap(t, "(", ")")
	# does at least one action pass?
	for action in UString.split_outside(t, " or "):
		if _test(action):
			return true
	return false

# do all actions pass?
func _test(t: String) -> bool:
	for action in UString.split_outside(t, " and "):
		if UString.is_wrapped(action, "(", ")"):
			if not test(action):
				return false
		else:
			var got: bool
			if action.begins_with("not "):
				action = action.trim_prefix("not ")
				got = false if do(action) else true
			else:
				got = true if do(action) else false
			
			if got:
				continue
			else:
				return false
	return true

func do(command: String, default: String = "~") -> Variant:
	if not len(command):
		return
	
	# MATCH case argument
	if command == "_":
		return "_"
	
	var head := UString.get_leading_symbols(command)
	if head in Soot.ALL_DOINGS:
		return _do(head, command)
	elif default in Soot.ALL_DOINGS:
		return _do(default, command)
	else:
		push_error("No 'do' symbol: %s." % default)
		return null

func _do(head: String, command: String):
	match head:
		"*": return to_var(command)
		"$", "$:", "$)": return do_state_action(command)
		"@", "@:", "@)": return do_group_action(command)
		"~", "~:", "~)": return do_state_action(command)

# vars are kept as strings, so can be auto type converted
func to_var(s: String) -> Variant:
	if s.begins_with("*"):
		s = s.substr(1)
	var out = []
	for part in UString.split_outside(s, " "):
		# dictionary key
		if ":" in part:
			if not len(out) or not out[-1] is Dictionary:
				out.append({})
			var kv = part.split(":", true, 1)
			out[-1][kv[0].strip_edges()] = kv[1].strip_edges()
		# array
		elif "," in part:
			out.append(Array(part.split(",")))
		# other
		else:
			out.append(part)
	out = out[0] if len(out) == 1 else out
	return out

# $state $)state $:state
func do_state_action(action: String) -> Variant:
	if action.begins_with("$"):
		action = action.substr(1).strip_edges()
	return _do_eval_or_func(action, State, false)

# ~self ~)self ~:self
func do_self_action(action: String, context: Variant) -> Variant:
	if action.begins_with("~"):
		action = action.substr(1).strip_edges()
	return _do_eval_or_func(action, context, false)

# while it can call many members of a group, it returns the last non null value it gets
# @actions
func do_group_action(action: String) -> Variant:
	if action.begins_with("@"):
		action = action.substr(1).strip_edges()
	
	var is_eval := false
	if action.begins_with(":"):
		is_eval = true
		action = action.substr(1).strip_edges()
	elif action.begins_with(")"):
		is_eval = false
		action = action.substr(1).strip_edges()
	
	if is_eval:
		return do_group_eval(action)
	else:
		return do_group_func(action)

# @:
func do_group_eval(eval: String) -> Variant:
	if eval.begins_with("@"):
		eval = eval.substr(1).strip_edges()
	
	var group: String
	# node call
	if "." in eval:
		var p = eval.split(".", true, 1)
		group = "@" + p[0]
		eval = p[1]
	# function call
	else:
		group = "@." + eval
	
	var nodes := Global.get_tree().get_nodes_in_group(group)
	if len(nodes):
		var out: Variant
		for node in nodes:
			var got = _do_eval(eval, node)
			if got != null:
				out = got
		return out
	else:
		push_error("No nodes in group %s for eval '%s'." % [group, eval])
		return null

# @)
func do_group_func(action: String) -> Variant:
	if action.begins_with("@"):
		action = action.substr(1).strip_edges()
	
	var args := UString.split_outside(action, " ")
	action = args.pop_front()
	return do_group_func_w_args(action, args, true)

# @actions
# while it can call many members of a group, it returns the last non null value it gets
func do_group_func_w_args(action: String, args: Array, as_string_args := false) -> Variant:
	if action.begins_with("@"):
		action = action.substr(1).strip_edges()
	
	var group: String
	# node call
	if "." in action:
		var p = action.split(".", true, 1)
		group = "@" + p[0]
		action = p[1]
	# function call
	else:
		group = "@." + action
	
	var nodes := Global.get_tree().get_nodes_in_group(group)
	if len(nodes):
		var out: Variant
		for node in nodes:
			var got = UObject.call_w_kwargs([node, action], args, as_string_args)
			if got != null:
				out = got
		return out
	else:
		push_error("No nodes in group %s for %s(%s)." % [group, action, args])
		return null

func _pipe(value: Variant, pipes: String) -> Variant:
	for pipe in pipes.split("|"):
		var args = UString.split_outside(pipe, " ")#UString.split_on_spaces(pipe)
		var method = args.pop_front()
		if State._has_method(method):
			value = State._call(method, [value] + args.map(State._eval))
		else:
			push_error("Can't pipe %s. No %s." % [value, method])
	return value

func _str_to_var(s: String) -> Variant:
	# builting
	match s:
		"true": return true
		"false": return false
		"null": return null
		"INF": return INF
		"-INF": return -INF
		"PI": return PI
		"TAU": return TAU
	
	# state variable?
	if s.begins_with("$"):
		return _get(s.substr(1))
	
	# is a string with spaces?
	if UString.is_wrapped(s, '"'):
		return UString.unwrap(s, '"')
	
	# evaluate
	if UString.is_wrapped(s, "<<", ">>"):
		var e := UString.unwrap(s, "<<", ">>")
		var got = State._eval(e)
#		print("EVAL %s -> %s" % [e, got])
		return got
	
	# array or dict?
	if "," in s or ":" in s:
		var args := s.split(",")
		var is_dict := ":" in args[0]
		var out = {} if is_dict else []
		for arg in args:
			if ":" in arg:
				var kv := arg.split(":", true, 1)
				var key := kv[0]
				var val = _str_to_var(kv[1])
				out[key] = val
			else:
				out.append(_str_to_var(arg))
		return out
	# float?
	if s.is_valid_float():
		return s.to_float()
	# int?
	if s.is_valid_int():
		return s.to_int()
	# must be a string?
	return s

func _do_eval_or_func(action: String, context: Variant, is_eval := true):
	# eval
	if action.begins_with(":"):
		action = action.substr(1).strip_edges()
		is_eval = true
	# func
	elif action.begins_with(")"):
		action = action.substr(1).strip_edges()
		is_eval = false
	
	if is_eval:
		return _do_eval(action, context)
	else:
		return _do_func(action, context)

func _do_func(action: String, context: Object) -> Variant:
	var args := UString.split_outside(action, " ")
	var method: String = args.pop_front()
	prints("FUNC", method, args)
	if context.has_method("_call"):
		return context._call(method, args, true)
	else:
		return UObject.call_w_kwargs([context, method], args, true)

func _context_has(context: Object, property: String) -> bool:
	if context.has_method("_has"):
		return context._has(property)
	else:
		return property in context

func _do_eval(eval: String, context: Variant, default = null) -> Variant:
	# state_manager modified this to make it work with all it's child functions
	if context.has_method("_preprocess_eval"):
		eval = context._preprocess_eval(eval)
	
	# state shortcut
	eval = eval.replace("$", "State.")
	
	# assignments?
	for op in StringAction.OP_ASSIGN:
		if op in eval:
			var p := eval.split(op, true, 1)
			var property := p[0].strip_edges()
			if _context_has(context, property):
				var old_val = context[property]
				var new_val = _do_eval(p[1].strip_edges(), context)
				match op:
					" = ": context[property] = new_val
					" += ": context[property] = old_val + new_val
					" -= ": context[property] = old_val - new_val
					" *= ": context[property] = old_val * new_val
					" /= ": context[property] = old_val / new_val
				return context[property]
			else:
				push_error("No property '%s' in %s." % [property, context])
				return default
#
#	# pipes
#	if "|" in expression:
#		var p := expression.split("|", true, 1)
#		var got = _eval(p[0])
#		return StringAction._pipe(got, p[1])
	
	if _expr.parse(eval, []) != OK:
		push_error("Failed _eval('%s'): %s." % [eval, _expr.get_error_text()])
	else:
		var result = _expr.execute([], context, false)
		if _expr.has_execute_failed():
			push_error("Failed _eval('%s'): %s." % [eval, _expr.get_error_text()])
		else:
			return result
	return default

# x = do_something(true, custom_func(0), sin(rotation))
# BECOMES
# x = _C.do_something.call(true, _C.custom_func.call(0), sin(rotation))
# this means functions defined in one Node, are usable by all as if they are their own.
func _globalize_functions(t: String) -> String:
	var i := 0
	var out := ""
	var off := 0
	while i < len(t):
		var j := t.find("(", i)
		# find a bracket.
		if j != -1:
			var k := j-1
			var method_name := ""
			# walk backwards
			while k >= 0 and t[k] in ".abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789":
				method_name = t[k] + method_name
				k -= 1
			# if head isn't empty, it's a function not wrapping brackets.
			if method_name != "":
				out += UString.part(t, i, k+1)
				# renpy inspired translations
				if method_name == "_":
					out += "tr("
				# don't wrap property methods, since those will be globally accessible from _get
				# don't wrap built in GlobalScope methods (sin, round, randf...)
				elif "." in method_name or method_name in UObject.GLOBAL_SCOPE_METHODS:
					out += "%s(" % method_name
				else:
					var parent = State._get_method_parent(method_name)
					out += "get_node(\"%s\").%s(" % [parent, method_name]
				out += UString.part(t, k+1+len(method_name), j)
				i = j + 1
				continue
		out += t[i]
		i += 1
	# add on the remainder.
	out += UString.part(t, i)
	return out
