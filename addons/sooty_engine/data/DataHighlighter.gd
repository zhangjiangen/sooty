@tool
extends EditorSyntaxHighlighter

var hl := preload("res://addons/sooty_engine/data/DataHighlighterRuntime.gd").new()

func _get_name() -> String:
	return "Soda"

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	return hl._get_line_syntax_highlighting2(get_text_edit().get_line(line))

#const C_PROPERTY := Color.TAN
#const C_SYMBOL := Color(1, 1, 1, 0.25)
#const C_FIELD := Color.LIGHT_GRAY
#const C_OBJECT := Color.GOLD
#const C_LIST_ITEM := Color.SPRING_GREEN
#
#const C_ERROR := Color.TOMATO
#
#var _out := {}
#var _text := ""
#var _deep := 0
#
#
#
#func _c(i: int, clr: Color):
#	_out[i] = { color=clr }
#
#func _hl_dict(from: int) -> int:
#	var a := _text.find("{", from)
#	if a != -1:
#		_c(a, C_SYMBOL)
#		var b := _text.find("}", a+1)
#		if b != -1:
#			_c(b, C_SYMBOL)
#			var inner := _text.substr(a+1, b-a-1)
#			var off = a+1
#			for part in inner.split(","):
#				var i := part.find(":")
#				if i != -1:
#					_c(off, C_PROPERTY.darkened((_deep+1) * .2))
#					_c(off+i, C_SYMBOL)
#					_c(off+i+1, C_FIELD)
#				else:
#					# dict key needed
#					_c(off, C_ERROR)
#				# comma
#				_c(off+len(part), C_SYMBOL)
#				off += len(part)+1
#		return b+1
#	return -1
#
#func _hl_list(from: int) -> int:
#	var a := _text.find("[", from)
#	if a != -1:
#		_c(a, C_SYMBOL)
#		var b := _text.find("]", a+1)
#		if b != -1:
#			_c(b, C_SYMBOL)
#			var inner := _text.substr(a+1, b-a-1)
#			var off = a+1
#			for part in inner.split(","):
#				var i := part.find(":")
#				if i != -1:
#					_c(off, C_PROPERTY.darkened((_deep+1) * .2))
#					_c(off+i, C_SYMBOL)
#					_c(off+i+1, C_FIELD)
#				else:
#					_c(off, C_FIELD)
#				# comma
#				_c(off+len(part), C_SYMBOL)
#				off += len(part)+1
#		return b+1
#	return -1
#
#func _get_line_syntax_highlighting(line: int) -> Dictionary:
#	_out = {}
#	_text = get_text_edit().get_line(line)
#	_deep = UString.count_leading_tabs(_text)
#	var stripped = _text.strip_edges()
#	var i := 0
#
#	if stripped.begins_with("- ") or stripped == "-":
#		i = _text.find("-")
#		_c(i, C_LIST_ITEM)
#		_c(i+1, C_FIELD)
#		i += 2
#	else:
#		# start as a field, for multiline
#		_c(0, C_FIELD)
#
#	# property name `:`
#	var a := _find_property_split(_text, i)
#	if a != -1:
#		var c := C_PROPERTY.darkened(_deep * .05)
#		c.h = wrapf(c.h - .2 * _deep, 0.0, 1.0)
#		_c(i, c)#C_PROPERTY.darkened(_deep * .2))
#		_c(a, C_SYMBOL)
#		_c(a+1, C_FIELD)
#
#		# object initializer
#		var e = _text.find("=", i)
#		if e != -1 and e < a:
#			_c(e, C_SYMBOL)
#			_c(e+1, C_OBJECT)
#
#		i = a + 1
#
#	# multiline tag `""""`
#	a = _text.find('""""', i)
#	if a != -1:
#		_c(a, C_SYMBOL)
#		i = a + 4
#
#	# dict
#	a = _hl_dict(i)
#	if a != -1:
#		i = a
#
#	# list
#	a = _hl_list(i)
#	if a != -1:
#		i = a
#
#	# comment
#	a = _text.find("#", i)
#	if a != -1:
#		_c(a, C_SYMBOL)
#		i += 1
#
#	return _out
#
#func _find_property_split(text: String, from: int) -> int:
#	for i in range(from, len(text)):
#		match text[i]:
#			"{", "[": break
#			":":
#				if (i == len(text)-1 or text[i+1] in " \n\t"):
#					return i
#	return -1
