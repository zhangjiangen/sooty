@tool
extends EditorSyntaxHighlighter

func _get_name() -> String:
	return "Soot"

# operators
const OP_RELATIONS := ["==", "!=", "<", "<=", ">", ">="]
const OP_ASSIGNMENTS := ["=", "+=", "-="]
const OP_EVALS := ["if", "elif", "else", "match", "rand"]
const OP_KEYWORDS := ["and", "or", "not"]
const OP_ALL := OP_RELATIONS + OP_ASSIGNMENTS + OP_EVALS + OP_KEYWORDS

# colors
const C_TEXT := Color.GAINSBORO
const C_SPEAKER := Color(1, 1, 1, 0.5)
const C_TAG := Color(1, 1, 1, .5)
const C_SYMBOL := Color(1, 1, 1, 0.33)

const C_FLAG := Color.SALMON
const C_LANG := Color.YELLOW_GREEN

const C_PROPERTY := Color(1, 1, 1, .25)
const C_VAR_BOOL := Color.AQUAMARINE
const C_VAR_FLOAT := Color.DARK_TURQUOISE
const C_VAR_INT := Color.DARK_TURQUOISE
const C_VAR_STR := Color.CADET_BLUE
const C_VAR_CONSTANT := Color.DARK_GRAY
const C_VAR_STATE_PROPERTY := Color.SPRING_GREEN

const C_COMMENT := Color(1.0, 1.0, 1.0, 0.25)
const C_COMMENT_LANG := Color(0.5, 1.0, 0.0, 0.5)

#const C_ACTION_EVAL := Color(0, 1, 0.5, 0.8)
const C_ACTION_GROUP := Color.MEDIUM_PURPLE
const C_ACTION_STATE := Color.DEEP_SKY_BLUE

const C_EVAL := Color(0, 1, 0.5, 0.8)
const C_EVAL_TAG := Color(0, 1, 0.5, 0.8*.5)

const C_FLOW := Color.WHEAT
const C_FLOW_GOTO := Color.TAN
const C_FLOW_CALL := Color.TAN
const C_FLOW_END := Color.TOMATO

const C_OPTION_FLAG := Color(0.25, 0.88, 0.82, 0.5)
const C_OPTION_TEXT := Color.WHEAT

# strings
const S_FLAG := "\t#?"

#const S_PROPERTY := "-"
const S_OPTION := "|>"
const S_OPTION_ADD := "+>"

const S_EVAL := "~"
const S_GROUP_FUNC := "@"
const S_STATE_FUNC := "$"

const S_FLATLINE := "||"

const S_SELECTOR_START := "{["
const S_SELECTOR_END := "]}"
const S_COND_START := "{{"
const S_COND_END := "}}"

const S_PROP_START := "(("
const S_PROP_END := "))"

var index := 0
var state := {}
var text := ""

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	text = get_text_edit().get_line(line)
	state = {}
	index = 0
	var stripped = text.strip_edges()
	var out = state
	
	# meta fields
	if text.begins_with("#."):
		_c(0, C_SYMBOL)
		_c(2, Color.PALE_VIOLET_RED)
		var i := text.find(":", 2)
		if i != -1:
			_c(i, C_SYMBOL)
			_c(i+1, Color.PINK)
		return out
	
	# flag line
	elif text.begins_with(S_FLAG):
		var drk = C_FLAG.darkened(.33)
		_c(1, drk)
		_c(1+len(S_FLAG), C_FLAG)
		for i in range(1+len(S_FLAG)+1, len(text)):
			if text[i] in ",;:&|":
				_c(i, C_SYMBOL)
				_c(i+1, C_FLAG)
		return out
	
	# lang lines
	elif text.begins_with(Soot.LANG):
		_c(0, C_SYMBOL)
		_c(len(Soot.LANG), C_LANG)
	# gone lang lines 
	elif text.begins_with(Soot.LANG_GONE):
		_c(0, C_SYMBOL)
		_c(len(Soot.LANG), Color.TOMATO)
	
	# new document
	elif text.begins_with("---"):
		_c(0, Color.ORANGE)
	
	# normal lines
	else:
		var from := 0
		
		# alternative line
		# TODO: Remove
#		if stripped.begins_with("?"):
#			var start := text.find("?")
#			var end := text.find(" ", start+1)
#			_c(start, C_SYMBOL)
#			_c(start+1, Color.ORANGE)
#			for i in range(start+1, end):
#				if text[i] in ",:":
#					_c(i, C_SYMBOL)
#					_c(i+1, Color.ORANGE)
#			from = end+1
			
		_c(from, C_TEXT)
#		var to = _h_flatline(C_TEXT, from)
		
		# flow
		if text.begins_with(Soot.FLOW):
			_c(0, C_SYMBOL)
			_c(len(Soot.FLOW), C_FLOW)
		
		else:
			# condition
#			var a := text.find(S_COND_START)
#			var b := text.rfind(S_COND_END)
#			var f := from
#			if a != -1 and b != -1:
#				_c(a, C_SYMBOL)
#				_c(b, C_SYMBOL)
#				_c(b+len(S_COND_END), C_TEXT)
#				_h_conditional(a+len(S_COND_START), b-1)
#				f = b+len(S_COND_END)
#
#				# highlight line before conditional
#				_h_line(from, a)
#
#				# highlight line after conditional, in case of 'match'
#				_h_line(f, to if to>0 else len(text))
			
#			else:
			_h_line(from, len(text))
			
			var f = text.find('""""')
			if f != -1:
				_c(f, C_SYMBOL)
	
	# comments
	index = text.find(Soot.COMMENT)
	if index != -1:
		_c(index, C_COMMENT)
		# erase all colors afterwards
		for k in state.keys():
			if k > index:
				state.erase(k)
	
	# line id for lang
	index = text.rfind(Soot.COMMENT_LANG)
	if index != -1:
		_c(index, C_SYMBOL)
		_c(index+len(Soot.COMMENT_LANG), C_COMMENT_LANG)
	
	return state

static func split_string(s: String) -> Array:
	var out := [""]
	var in_quotes := false
	for c in s:
		if c == '"':
			if in_quotes:
				in_quotes = false
				out[-1] += '"'
			else:
				in_quotes = true
				if out[-1] == "":
					out[-1] += '"'
				else:
					out.append('"')
		
		elif c == " " and not in_quotes:
			if out[-1] != "":
				out.append("")
		
		else:
			out[-1] += c
	return out

#func _co(clr: Color, offset := 0):
#	state[index] = {color=clr}
#	index += offset

func _c(i: int, clr: Color):#, offset := 0):
#	index = i
	state[i] = {color=clr}
#	_co(clr, offset)

func _set_var_color(i: int, v: String, is_function := false, func_color := C_EVAL):
	if UString.is_wrapped(v, "<<", ">>"):
		_c(i, C_EVAL_TAG)
		_c(i+2, C_EVAL)
		_c(i+len(v)-2, C_EVAL_TAG)
	elif " " in v:
		var off := i
		for part in v.split(" "):
			_set_var_color(off, part)
			off += len(part) + 1
	# dict key
	elif ":" in v:
		var p := v.split(":", true, 1)
		_c(i, C_PROPERTY)
		_c(i+len(p[0]), C_SYMBOL)
		_set_var_color(i+len(p[0])+1, p[1])
	# array
	elif "," in v:
		var off := i
		for part in v.split(","):
			_set_var_color(off, part)
			off += len(part)
			state[off] = {color=C_SYMBOL}
			off += 1
	# match "default"
	elif v in ["_", "==", "!=", "=", "+=", "-=", ">", ">=", "<", "<="]:
		_c(i, C_SYMBOL)
	# state property
	elif v.begins_with("$"):
		# only highlight last part
		var d := v.rfind(".")
		_c(i, C_VAR_STATE_PROPERTY.darkened(.25))
		if d != -1:
			_c(i+d+1, C_VAR_STATE_PROPERTY)
		else:
			_c(i+1, C_VAR_STATE_PROPERTY)
	elif v.begins_with("@") or is_function:
		# only highlight last part
		var d := v.rfind(".")
		_c(i, func_color.darkened(.25))
		if d != -1:
			_c(i+d, func_color)
		else:
			_c(i, func_color)
	elif v.is_valid_int():
		_c(i, C_VAR_INT)
	elif v.is_valid_float():
		_c(i, C_VAR_FLOAT)
	elif v in ["true", "false", "null"]:
		_c(i, C_VAR_BOOL)
	elif v == v.to_upper():
		_c(i, C_VAR_CONSTANT)
	else:
		_c(i, C_VAR_STR)

func _h_action(from: int, to: int, c: Color):
	_c(from, C_SYMBOL)
	var inner := text.substr(from, to-from)
	var parts := split_string(inner)
	for i in len(parts):
		var part = parts[i]
		_set_var_color(from, part, i==0, c)
		from += len(part) + 1

func _h_action_expression(from: int, to: int):
	_c(from, C_SYMBOL)
	_c(from+1, C_EVAL)
	for i in range(from+1, to):
		if text[i] in ",.[](){}\"'-+=<>":
			_c(i, C_SYMBOL)
			_c(i+1, C_EVAL)

func _h_conditional(from: int, to: int, begins_with: bool):
	var inner := text.substr(from, to-from)
	var off := from
	for part in inner.split(" "):
		if part in OP_ALL:
			_c(from, C_EVAL_TAG)
		else:
			_c(from, C_EVAL)
		from += len(part)+1
	return
#
#	var is_assign = len(parts)==3 and parts[1] in OP_ALL
#	var is_match := false
#
#	for i in len(parts):
#		var part = parts[i]
#
#		# match
#		if part.begins_with("*"):
#			part = part.substr(1)
#			state[off] = { color=C_SYMBOL }
#			is_match = true
#			off += 1
#
#		_set_var_color(off, part)
#		off += len(part) + 1

#func _h_flatline(default: Color, from: int):
#	return from
#	var i := text.find(S_FLATLINE_START, from)
#	if i != -1:
#		var j := text.find(S_FLATLINE_END, i+len(S_FLATLINE_START))
#		if j != -1:
#			_c(i+len(S_FLATLINE_START), C_TEXT)
#
#			var inner := text.substr(i+len(S_FLATLINE_START), j-i-len(S_FLATLINE_START))
#			var off := i+len(S_FLATLINE_START)
#			for part in inner.split(S_FLATLINE):
#				_h_line(off, off+len(part))
#				off += len(part)
#				_c(off, C_SYMBOL)
#				off += len(S_FLATLINE)
#
#			# opening symbol
#			_c(i, C_SYMBOL)
#			# closing symbol
#			_c(j, C_SYMBOL)
#	return i
	
func _h_bbcode(from: int, to: int, default: Color):
	var i := from
	while i < to:
		if text[i] == "[":
			var b := text.find("]", i+1)
			if b != -1:
				var inner := text.substr(i+1, b-i-1)
				var off = i + 1
				for tag in inner.split(";"):
					if tag.begins_with("!"):
						tag = tag.substr(1)
						_c(off, C_SYMBOL)
						off += 1
					# colorize action tags
					if tag.begins_with(S_EVAL):
						_h_action(off, off+len(tag), C_EVAL)
#					elif tag.begins_with(S_ACTION_NODE):
#						_h_action(off, off+len(tag), C_ACTION_NODE)
					elif tag.begins_with(S_GROUP_FUNC):
						_h_action(off, off+len(tag), C_ACTION_GROUP)
					elif tag.begins_with(S_STATE_FUNC):
						_h_action(off, off+len(tag), C_ACTION_STATE)
					# colorize normal tags
					else:
						_c(off, C_TAG)
					off += len(tag)
					# colorize ; seperator
					_c(off, C_SYMBOL)
					off += 1
				# colorize open and close tags
				_c(i, C_SYMBOL)
				_c(b, C_SYMBOL)
				# back to normal text color
				_c(b+1, default)
				i = b
		
		# markdown: * ** ***
		elif text[i] == "*":
			_c(i, C_SYMBOL)
			_c(i+1, default)
	
		i += 1

func _h_flow(from := 0):
	# => and ==
	for tag in [[Soot.FLOW_GOTO, C_FLOW_GOTO], [Soot.FLOW_CALL, C_FLOW_CALL]]:
		var i := from
		while true:
			var j := text.find(tag[0], i)
			if j == -1:
				break
			var lit = tag[1]
			_c(j, C_SYMBOL)
			j += len(tag[0])
			# path divider exists?
			var d := text.find(Soot.FLOW_PATH_DIVIDER, j)
			if d != -1:
				# darken head of the path
				_c(j, lit.darkened(.33))
				j = d+1
			# colorize path
			_c(j, lit)
			j += len(tag[0])
			i = j

func _h_properties(from: int, to: int):
	for part in text.substr(from, to-from).split(" "):
		_set_var_color(from, part)
		from += len(part) + 1

func _h_line(from: int, to: int):
	var t := text.substr(from, to-from)
	var len_old = len(t)
	t = t.strip_edges(true, false)
	from += len_old - len(t)
	t = t.strip_edges(false, true)
	
	var parts := t.split(S_FLATLINE)
	
	for part in parts:
		var next_from = from + len(part) + 2
		from += len(part) - len(part.strip_edges(true, false))
		to = from + len(part.strip_edges())
		part = part.strip_edges()
		_c(from, C_TEXT)
		_c(to+1, C_SYMBOL) # ;; divider
		
		# line begining with a condition.
		if part.begins_with(S_COND_START):
			# head tag {{
			_c(from, C_SYMBOL)
			_c(from+1, C_EVAL_TAG)
			
			var e := part.find(S_COND_END)
			if e != -1:
				to = from + e
				# tail tag }}
				_c(to, C_EVAL_TAG)
				_c(to+1, C_SYMBOL)
				# condition
				_h_conditional(from + len(S_COND_START), to, true)
				from += e + len(S_COND_END) + 1
				to = next_from-2
				part = text.substr(from, to-from)
			else:
				part = ""
		# line ending with a condition.
		elif part.ends_with(S_COND_END):
			_c(to-len(S_COND_END), C_SYMBOL) # }} symbol
			var s := part.rfind(S_COND_START, to)
			if s != -1:
				_c(from+s, C_SYMBOL)
				_h_conditional(from+s + len(S_COND_START), to - len(S_COND_END), false)
				to = from+s
				part = text.substr(from, to-from)
		
		# language tag
		var start := part.find("#{")
		if start != -1:
			_c(from+start, C_SYMBOL)
			_c(from+start+len("#{"), Color.CYAN)
			
			var end := part.find("}", start)
			if end != -1:
				_c(from+end, C_SYMBOL)
				to=from+end
				part = text.substr(from, to-from)
		
		# properties
		var prop_start := part.find("((")
		if prop_start != -1:
			# head tag
			_c(from+prop_start, C_SYMBOL)
			
			var prop_end := part.find("))", prop_start)
			if prop_end != -1:
				# tail tag
				_c(from+prop_end, C_SYMBOL)
			else:
				prop_end = len(part)
			
			# inner
			_h_properties(from+prop_start+len("(("), from+prop_end)
			
			to = from+prop_start
			part = text.substr(from, to-from)
		
		
		# properties
#		if part.begins_with(S_PROPERTY):
#			var j := from + len(S_PROPERTY)
#			_c(from, C_SYMBOL)
#			_set_var_color(j, text.substr(j))
		
		# selector lines
		if part.begins_with(S_SELECTOR_START):
			# head tag
			_c(from, C_SYMBOL)
			_c(from+1, Color(Color.LIGHT_SALMON, .5))
			# inner
			_c(from+2, Color.LIGHT_SALMON)
			
			var end := part.find(S_SELECTOR_END, len(S_SELECTOR_START))
			if end != -1:
				# tail tag
				_c(from+end, Color(Color.LIGHT_SALMON, .5))
				_c(from+end+1, C_SYMBOL)
		
		# state calls
		elif part.begins_with(S_STATE_FUNC):
			_h_action(from, to, C_ACTION_STATE)
		# group calls
		elif part.begins_with(S_GROUP_FUNC):
			_h_action(from, to, C_ACTION_GROUP)
		# eval calls
		elif part.begins_with(S_EVAL):
			_h_action_expression(from, to)
		
		# options
		elif part.begins_with(S_OPTION):
			_c(from, C_SYMBOL)
			_c(from+len(S_OPTION), C_OPTION_TEXT)
			_h_bbcode(from+len(S_OPTION), to, C_OPTION_TEXT)
			_h_flow()
		
		# options: add
		elif part.begins_with(S_OPTION_ADD):
			var c_option_add = C_OPTION_TEXT
			c_option_add.h = wrapf(c_option_add.h - .22, 0.0, 1.0)
			c_option_add.v = clampf(c_option_add.v - 0.25, 0.0, 1.0)
			_c(from, C_SYMBOL)
			_c(from+len(S_OPTION_ADD), c_option_add)
			var s := text.find("*", from+len(S_OPTION_ADD))
			if s != -1:
				_c(s, C_SYMBOL)
				_c(s+1, c_option_add)
		
		# flow actions == =>
		elif part.begins_with(Soot.FLOW_GOTO) or part.begins_with(Soot.FLOW_CALL):
			_h_flow()
		# flow ended ><
		elif part.begins_with(Soot.FLOW_ENDD):
			_c(from, C_FLOW_END)
			_c(from+len(Soot.FLOW_ENDD), C_FLOW_END.darkened(.33))
		# flow end all >><<
		elif part.begins_with(Soot.FLOW_END_ALL):
			_c(from, C_FLOW_END)
			_c(from+len(Soot.FLOW_END_ALL), C_FLOW_END.darkened(.33))
		# flow pass __
		elif part.begins_with(Soot.FLOW_PASS):
			_c(from, Color.YELLOW)
			_c(from+len(Soot.FLOW_PASS), Color.YELLOW.darkened(.33))
		# flow checkpoint <>
		elif part.begins_with(Soot.FLOW_CHECKPOINT):
			_c(from, Color.DEEP_SKY_BLUE)
			_c(from+len(Soot.FLOW_CHECKPOINT), Color.DEEP_SKY_BLUE.darkened(.33))
		# flow back <<
		elif part.begins_with(Soot.FLOW_BACK):
			_c(from, Color.DEEP_SKY_BLUE)
			_c(from+len(Soot.FLOW_BACK), Color.DEEP_SKY_BLUE.darkened(.33))
		
		else:
			# text
			
			var i := _find_speaker_split(part)#from)
			if i != -1:
				_c(from, C_SPEAKER)
				_c(from+i, C_SYMBOL)
				_c(from+i+1, C_TEXT)
				from = i+1
#				var sub = text.substr(from, i-from)
#				# colorize in brackets
#				if "(" in sub:
#					var a := sub.find("(")
#					var b := sub.rfind(")")
#					_c(a, C_SYMBOL)
#					_c(a+1, C_ACTION_GROUP)
#					_c(b, C_SYMBOL)
			
			_h_bbcode(from, to, C_TEXT)
		
		from = next_from
	
func _find_speaker_split(s: String) -> int:#from: int) -> int:
	var in_bbcode := false
	for i in len(s):#range(from, len(text)):
		match s[i]:
			"[": in_bbcode = true
			"]": in_bbcode = false
			":":
				if not in_bbcode and (i==0 or s[i-1] != "\\"):
					return i
	return -1

func _find_speaker_start(from: int) -> int:
	for i in range(from, -1, -1):
		if text[i] in "}":
			return i+1
	return 0
