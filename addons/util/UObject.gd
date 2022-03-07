@tool
extends Resource
class_name UObject

static func get_class_name(o: Object) -> String:
	return o.get_script().resource_path.get_file().split(".", true, 1)[0]

static func get_state(o: Object) -> Dictionary:
	var out := {}
	for prop in o.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and prop.name[0] != "_":
			match prop.type:
				TYPE_OBJECT:
					out[prop.name] = get_state(o[prop.name])
				TYPE_DICTIONARY:
					out[prop.name] = _get_dict_state(o[prop.name])
				_:
					out[prop.name] = o[prop.name]
	return out

static func _get_dict_state(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		match typeof(dict[k]):
			TYPE_OBJECT:
				out[k] = get_state(dict[k])
			TYPE_DICTIONARY:
				out[k] = _get_dict_state(dict[k])
			_:
				out[k] = dict[k]
	return out

static func set_state(o: Object, data: Dictionary):
	for prop in o.get_property_list():
		if prop in data and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and prop.name[0] != "_":
			match prop.type:
				TYPE_OBJECT:
					set_state(o[prop.name], data[prop.name])
				_:
					o[prop.name] = data[prop.name]

static func patch(target: Variant, patch: Dictionary) -> int:
	var lines_changed := 0
	for k in patch:
		if k in target:
			if patch[k] is Dictionary:
				lines_changed += patch(target[k], patch[k])
			
			elif target[k] != patch[k]:
				target[k] = patch[k]
				lines_changed += 1
		
		elif target is Dictionary:
			target[k] = patch[k]
			lines_changed += 1
		
		else:
			push_error("Couldn't find '%s' in %s." % [k, target])
	return lines_changed

# Properly divides an array as arguments for a function. Like python.
static func call_w_args(obj: Object, method: String, in_args: Array = []) -> Variant:
	if not obj.has_method(method):
		push_error("No method '%s(%s)' in %s." % [method, in_args, obj])
		return
	
	var arg_info := get_method_arg_info(obj, method)
	var old := in_args.duplicate(true)
	var out := []
	var kwargs := {}
	
	# pop last dictionary, regardless
	if len(in_args) and in_args[-1] is Dictionary:
		if "kwargs" in arg_info:
			kwargs = in_args.pop_back()
		else:
			in_args.pop_back()
		
	# add the initial values up front
	for property in arg_info:
		if property in ["args", "kwargs"]:
			break
		elif len(in_args):
			var v = in_args.pop_front()
#			if arg_info[property].type != typeof(v):
#				var d = arg_info[property].get("default", null)
#				push_error("call_w_args: Wrong type '%' (%s) given for '%s'. Using default (%s) instead." % [arg_info[property].type_name, v, property, d ])
#				out.append(d)
#			else:
			out.append(v)
		else:
			out.append(arg_info[property].get("default", null))
	
	# insert the array
	if "args" in arg_info:
		if len(in_args):
			out.append(in_args)
		else:
			out.append(arg_info.args.get("default", []))
	
	# pop back in the kwargs
	if "kwargs" in arg_info:
		out.append(kwargs)
	
#	print(method.to_upper())
#	for i in len(out):
#		print("\t* %s\t\t%s\t\t%s" % [old[i] if i < len(old) else "??", out[i], arg_info.values()[i]])
	var got = obj.callv(method, out)
	return got

static func get_method_arg_info(obj: Object, meth: String) -> Dictionary:
	return get_methods(obj).get(meth, {})

static func get_methods(obj: Object) -> Dictionary:
	var script = obj.get_script()
	if script == null:
		return {}
	var out := {}
	for line in script.source_code.split("\n", false):
		if line.begins_with("func "):
			var p = line.substr(5).split("(")
			var fname = p[0]
			var args = _parese_method_arguments(p[1].rsplit(")")[0])
			out[fname] = args
	return out

static func _parese_method_arguments(s: String) -> Dictionary:
	if s.strip_edges() == "":
		return {}
	
	var args = [["", ""]]
	var open := {}
	var in_name := true
	
	for c in s:
		if not len(open):
			if c == ":":
				in_name = false
				continue
			elif c == ",":
				args.append(["", ""])
				in_name = true
				continue
		match c:
			"{": UDict.tick(open, "{")
			"}": UDict.tick(open, "{", -1)
			"[": UDict.tick(open, "[")
			"]": UDict.tick(open, "[", -1)
			"(": UDict.tick(open, "(")
			")": UDict.tick(open, "(", -1)
		args[-1][0 if in_name else 1] += c
	
	var out := {}
	for i in len(args):
		var k = args[i][0].strip_edges()
		var v = args[i][1].split("=", true, 1)
		var type_name = v[0].strip_edges()
		out[k] = {}
		out[k].type_name = type_name
		out[k].type = UObject.get_type_from_name(type_name)
		if len(v) == 2:
			out[k].default = str2var(v[1].strip_edges())
	return out

static func get_type_from_name(name: String) -> int:
	match name:
		"null": return TYPE_NIL
		"bool": return TYPE_BOOL
		"int": return TYPE_INT
		"float": return TYPE_FLOAT
		"String": return TYPE_STRING
		"Vector2": return TYPE_VECTOR2
		"Vector2i": return TYPE_VECTOR2I
		"Rect2": return TYPE_RECT2
		"Rect2i": return TYPE_RECT2I
		"Vector3": return TYPE_VECTOR3
		"Vector3i": return TYPE_VECTOR3I
		"Transform2D": return TYPE_TRANSFORM2D
		"Plane": return TYPE_PLANE
		"Quaternion": return TYPE_QUATERNION
		"AABB": return TYPE_AABB
		"Basis": return TYPE_BASIS
		"Transform3D": return TYPE_TRANSFORM3D
		"Color": return TYPE_COLOR
		"StringName": return TYPE_STRING_NAME
		"NodePath": return TYPE_NODE_PATH
		"RID": return TYPE_RID
		"Object": return TYPE_OBJECT
		"Callable": return TYPE_CALLABLE
		"Signal": return TYPE_SIGNAL
		"Dictionary": return TYPE_DICTIONARY
		"Array": return TYPE_ARRAY
		"PackedByteArray": return TYPE_PACKED_BYTE_ARRAY
		"PackedInt32Array": return TYPE_PACKED_INT32_ARRAY
		"PackedInt64Array": return TYPE_PACKED_INT64_ARRAY
		"PackedFloat32Array": return TYPE_PACKED_FLOAT32_ARRAY
		"PackedFloat64Array": return TYPE_PACKED_FLOAT64_ARRAY
		"PackedStringArray": return TYPE_PACKED_STRING_ARRAY
		"PackedVector2Array": return TYPE_PACKED_VECTOR2_ARRAY
		"PackedVector3Array": return TYPE_PACKED_VECTOR3_ARRAY
		"PackedColorArray": return TYPE_PACKED_COLOR_ARRAY
		_: return TYPE_NIL

static func get_name_from_type(type: int) -> String:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_RECT2: return "Rect2"
		TYPE_RECT2I: return "Rect2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_COLOR: return "Color"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "???"
