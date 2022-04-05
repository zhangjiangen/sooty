@tool
extends Resource
class_name DialogueParser

const DEBUG_KEEP_DICTS := false # don't clean useless info from steps?
const REWRITE := 6 # total times rewritten from scrath :{

const S_PROPERTY_HEAD := "|"

var _file := ""
var _last_speaker := ""
var _ignore_flags := false

func _init(ignore_flags := false) -> void:
	_ignore_flags = ignore_flags

func parse(file: String) -> Dictionary:
	_file = file
	
	var original_text := UFile.load_text(file)
	var text_lines := original_text.split("\n")
	var dict_lines := []
	
	# Convert text lines to dict lines.
	var i := 0
	var in_multiline := false
	var multiline_id := ""
	var multiline_line := 0
	var multiline_head := ""
	var multiline_depth := 0
	var multiline := []
	
	var flags_pass := true
	
	while i < len(text_lines):
		var current_line := text_lines[i]
		var line := i
		
		# import time flags
		# these prevent certain lines, depending on flags
		if current_line.begins_with("\t#?"):
			flags_pass = true
			for flag in current_line.substr(3).strip_edges().split(" "):
				if len(flag) and not flag in Dialogues.flags:
					flags_pass = false
					break
			i += 1
			continue
		
		# skip lines that didn't pass the flag.
		elif not _ignore_flags and not flags_pass:
			i += 1
			continue
		
		# remove comment
		var uncommented := current_line
		if Soot.COMMENT in uncommented:
			uncommented = uncommented.split(Soot.COMMENT, true, 1)[0]
		
		var id := ""
		var stripped := uncommented.strip_edges()
		
		if '""""' in stripped:
			in_multiline = not in_multiline
			if not in_multiline:
				id = multiline_id
				line = multiline_line
				stripped = multiline_head.replace("%TEXT_HERE%", "\n".join(multiline))
				multiline = []
			else:
				multiline_id = id
				multiline_line = i
				multiline_head = uncommented.replace('""""', '%TEXT_HERE%').strip_edges()
				multiline_depth = _count_leading_tabs(text_lines[i])
				i += 1
				continue
		
		# if part of multline, just collect
		if in_multiline:
			multiline.append(uncommented.substr(multiline_depth))
		
		# ignore empty lines
		elif len(stripped):
			var d_id: String = UFile.get_file_name(file)
			var deep := _count_leading_tabs(text_lines[i])
			dict_lines.append({
				d_id=d_id,
				id=id,
				file=0,
				line=line,
				type="_",
				text=stripped,
				deep=deep,
				tabbed=[]
			})
			# unflatten lines.
			var flat_lines := _extract_flat_lines(dict_lines[-1])
			dict_lines.append_array(flat_lines)
		
		i += 1
	
	# Collect tabs, recursively.
	i = 0
	var new_list := []
	while i < len(dict_lines):
		var o = _collect_tabbed(dict_lines, i)
		i = o[0]
		new_list.append(o[1])
	
	var out_flows := {}
	var out_lines := {}
	for i in len(new_list):
		match new_list[i].type:
			"flow":
				out_flows[new_list[i].text] = new_list[i]
				_clean(new_list[i], out_lines)
	
	return {
		original_text=original_text,
		flows=out_flows,
		lines=out_lines
	}

func _clean_array(lines: Array, all_lines: Dictionary):
	for i in len(lines):
		if DEBUG_KEEP_DICTS: # DEBUG SANITY
			_clean(lines[i], all_lines)
		else:
			lines[i] = _clean(lines[i], all_lines)

func _clean_nested_array(lines_list: Array, all_lines: Dictionary):
	for i in len(lines_list):
		_clean_array(lines_list[i], all_lines)

func _clean(line: Dictionary, all_lines: Dictionary) -> String:
	var id := "%s!%s" % [line.file, line.line]
	if "flat" in line:
		id += "_%s" % [line.flat]
		line.erase("flat")
	
	if not DEBUG_KEEP_DICTS:
		_erase(line, ["d_id", "deep", "tabbed"])
#		_erase(line, ["file", "line"])
	
	match line.type:
		"flow":
			_clean_array(line.then, all_lines)
			_erase(line, ["text"])
			return id
		
		"option":
			if line.then:
				_clean_array(line.then, all_lines)
			else:
				line.erase("then")
#			_erase(line, ["text"])
		"goto", "call":
			_erase(line, ["text"])
		"text":
			if "options" in line:
				_clean_array(line.options, all_lines)
		"action":
			_erase(line, ["text"])
		"cond":
			match line.cond_type:
				"if": _clean_nested_array(line.cond_lines, all_lines)
				"match": _clean_nested_array(line.case_lines, all_lines)
			line.type = line.cond_type
			_erase(line, ["text", "cond", "cond_type"])
		_: pass
	
	if id in all_lines:
		var old = all_lines[id]
		push_error("%s Line at %s %s replaced with %s" % [_file, id, old, line])
	all_lines[id] = line
	return id

func _collect_tabbed(dict_lines: Array, i: int) -> Array:
	var line = dict_lines[i]
#	_extract_properties(line)
	i += 1
	# collect tabbed
	while i < len(dict_lines) and dict_lines[i].deep > line.deep:
		var o = _collect_tabbed(dict_lines, i)
		line.tabbed.append(o[1])
		i = o[0]
		
	# get properties
	for j in range(len(line.tabbed)-1, -1, -1):
		if line.tabbed[j].type == "prop":
			var props: Dictionary = line.tabbed[j].prop
			if not "prop" in line:
				line.prop = props
			else:
				for k in props:
					line.prop[k] = props[k]
			line.tabbed.remove_at(j)

	# combine if-elif-else
	var new_tabbed := []
	for j in len(line.tabbed):
		var ln: Dictionary = line.tabbed[j]
		match ln.type:
			"cond":
				match ln.cond_type:
					"if", "match":
						new_tabbed.append(ln)
					"elif", "else":
						if j != 0:
							var prev: Dictionary = line.tabbed[j-1]
							if prev.type == "cond" and prev.cond_type == "if":
								prev.conds.append(ln.cond)
								prev.cond_lines.append(ln.tabbed)
						else:
							push_error("'%s' must follow an 'if'." % [ln.cond_type])
			_:
				new_tabbed.append(ln)
	line.tabbed = new_tabbed

	_process_line(line)
	return [i, line]

func _process_line(line: Dictionary):
	var t: String = line.text
	if t.begins_with(Soot.FLOW): return _line_as_flow(line)
	if t.begins_with("{{"): return _line_as_condition(line)
	_extract_conditional(line)
	# option
	if t.begins_with("- "): return _line_as_option(line)
	# actions
	if t.begins_with("~"): return _line_as_action(line)
	if t.begins_with("$"): return _line_as_action(line)
	if t.begins_with("#"): return _line_as_action(line)
	if t.begins_with("@"): return _line_as_action(line)
	# flows
	if t.begins_with(Soot.FLOW_GOTO): return _line_as_flow_goto(line)
	if t.begins_with(Soot.FLOW_CALL): return _line_as_flow_call(line)
	if t.begins_with(Soot.FLOW_ENDD): return _line_as_flow_end(line)
	# property
	if t.begins_with(S_PROPERTY_HEAD): return _line_as_properties(line)
	return _line_as_dialogue(line)

func _line_as_condition(line: Dictionary):
	line.type = "cond"
	line.cond_type = "if"
	_extract_conditional(line)
	
	var cond: String = line.cond
	
	# if-elif-else condition
	if cond.begins_with("if "):
		line.cond_type = "if"
		line.cond = cond.substr(len("if ")).strip_edges()
	elif cond.begins_with("elif "):
		line.cond_type = "elif"
		line.cond = cond.substr(len("elif ")).strip_edges()
	elif cond == "else":
		line.cond_type = "else"
		line.cond = "true"
	
	# match condition
	elif cond.begins_with("match "):
		line.cond_type = "match"
		line.match = line.cond.trim_prefix("match ").strip_edges()
		line.cases = []
		line.case_lines = []
		for tabbed_line in line.tabbed:
			if tabbed_line.type == "cond":
				line.cases.append(tabbed_line.cond)
				line.case_lines.append(tabbed_line.tabbed)
				
				# treat as an unprocessed line now.
				# and then add it to the front of it's list.
				if tabbed_line.text.strip_edges() != "":
					_erase(tabbed_line, ["cond", "cond_type", "conds", "cond_lines"])
					tabbed_line.tabbed = []
					_process_line(tabbed_line)
					line.case_lines[-1].push_front(tabbed_line)
	
	if line.cond_type == "if":
		line.conds = [line.cond]
		line.cond_lines = [line.tabbed]

func _line_as_option(line: Dictionary):
	var t: String = line.text
	var a := t.find("-")
	
	line.type = "option"
	line.text = t.substr(a+1).strip_edges()
	
	_extract_action(line)
	
	# extract flow lines
	var lines := []
	for li in line.tabbed:
		match li.type:
			_: lines.append(li)
	
	if Soot.FLOW_GOTO in line.text:
		var p = line.text.split(Soot.FLOW_GOTO, true, 1)
		line.text = p[0].strip_edges()
		var i = 1000
		var id =  "%s_%s"%[line.flat, i] if "flat" in line else str(i)
		var fstep = _add_flow_action({d_id=line.d_id, file=line.file, line=line.line, flat=id}, "goto", p[1].strip_edges())
		lines.append(fstep)
	
	line.then = lines

func _line_as_flow_goto(line: Dictionary):
	var p = line.text.rsplit(Soot.FLOW_GOTO, true, 1)
	line.text = p[0].strip_edges()
	_add_flow_action(line, "goto", p[1].strip_edges())

func _line_as_flow_call(line: Dictionary):
	var p = line.text.split(Soot.FLOW_CALL, true, 1)
	line.text = p[0].strip_edges()
	_add_flow_action(line, "call", p[1].strip_edges())

func _line_as_flow_end(line: Dictionary):
	line.type = "end"
	line.end = line.text.trim_prefix(Soot.FLOW_ENDD).strip_edges()

func _add_flow_action(line: Dictionary, type: String, f_action: String):
	line.type = type
	# if full path wasn't typed out, add file id as head.
	line[type] = f_action if Soot.is_path(f_action) else Soot.join_path([line.d_id, f_action])
	return line

func _line_as_action(line: Dictionary):
	line.type = "action"
	line.action = line.text.strip_edges()

func _line_as_properties(line: Dictionary):
	var properties := {}
	for prop in line.text.substr(len("|")).split(" "):
		var p = prop.split(":", true, 1)
		properties[p[0]] = p[1]
	line.type = "prop"
	line.prop = properties

func _line_as_flow(line: Dictionary):
	_last_speaker = ""
	
	line.type = "flow"
	line.text = line.text.substr(len("===")).strip_edges()
	line.then = line.tabbed

func _line_as_dialogue(line: Dictionary):
	var text: String = line.text
	line.type = "text"
	var i := _find_speaker_split(text, 0)
	if i != -1:
		var p := text.split(":", true, 1)
		line.from = text.substr(0, i).strip_edges().replace("\\:", ":")
		line.text = text.substr(i+1, len(text)-i).strip_edges()
		
		# get action
		if "(" in line.from:
			var a := UString.extract(line.from, "(", ")", true)
			line.from = a.outside
			var action := []
			for part in a.inside.split(";"):
				action.append("@%s.%s" % [line.from, part])
			line.action = action
		
		# remember last speaker
		if line.from.strip_edges() == "":
			line.from = _last_speaker
		else:
			_last_speaker = line.from
	
	line.text = line.text.replace("\\:", ":")
	
	var options := []
	var lines := []
	for tabbed_line in line.tabbed:
		match tabbed_line.type:
			"option": options.append(tabbed_line)
			_: lines.append(tabbed_line)
	
	line.tabbed = lines
	
	if options:
		line.options = options

func _find_speaker_split(text: String, from: int) -> int:
	var in_bbcode := false
	for i in range(from, len(text)):
		match text[i]:
			"[": in_bbcode = true
			"]": in_bbcode = false
			":":
				if not in_bbcode and (i==0 or text[i-1] != "\\"):
					return i
	return -1

func _extract_flat_lines(line: Dictionary) -> Array:
	var out := []
	if _extract(line, "((", "))", "flat_lines"):
		var p = line.flat_lines.split(";;")
		for i in len(p):
			var id = "%s_%s"%[line.flat, i] if "flat" in line else str(i)
			var f_line = {
				id="",
				d_id=line.d_id,
				file=line.file,
				line=line.line,
				deep=line.deep+1,
				flat=id,
				type="_",
				text=p[i].strip_edges(),
				tabbed=[],
			}
			# recursively check.
			out.append(f_line)
			out.append_array(_extract_flat_lines(f_line))
		line.erase("flat_lines")
	return out

func _extract_action(line: Dictionary) -> bool:
	return _extract(line, "[[", "]]", "action")

func _extract_conditional(line: Dictionary) -> bool:
	return _extract(line, "{{", "}}", "cond")

func _extract(line: Dictionary, head: String, tail: String, key: String) -> bool:
	var p := UString.extract(line.text, head, tail)
	line.text = p.outside
	if p.inside != "":
		line[key] = p.inside
		return true
	return false

func _erase(d: Dictionary, keys: Array):
	for k in keys:
		d.erase(k)

func _trailing_tokens(s: String, splitters: Array) -> Array:
	var f := UString.split_on_next(s, splitters)
	var token: String = f[0]
	var left_side: String = f[1]
	var left_over: String = f[2]
	if token == "":
		return [s, []]
	var tokens := [[token, left_over]]
	while true:
		f = UString.split_on_next(left_over, splitters)
		if f[0] == "":
			break
		tokens[-1][1] = f[1]
		left_over = f[2]
		tokens.append([f[0], left_over])
	return [left_side, tokens]

func _count_leading_tabs(s: String) -> int:
	var out := 0
	for c in s:
		match c:
			"\t": out += 4
			" ": out += 1
			_: break
	out /= 4
	return out
