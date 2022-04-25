@tool
extends Data
class_name PatchableData
func get_class() -> String:
	return "PatchableData"

const DEFAULT_FORMAT := "[b]{name}[]"
var _props := {}
var _calls := {}

func _init(d := {}):
	UObject.set_state(self, d, true, true)
	for k in d:
		if not k in self:
			_props[k] = d[k]
	_post_init.call_deferred()

# along with public properties, include the _extra keys when saving/loading
func _get_state_properties() -> Array:
	return UObject._get_state_properties(self) + _props.keys()

# add a property from DataParser
func _patch_property(property: String, value: Variant):
	_props[property] = value

# add an object from DataParser
func _patch_object(property: String, type: String) -> Object:
	_props[property] = PatchableData.new() if type == "" else UClass.create(type)
	return _props[property]

# add a list of properties from DataParser
func _patch_list_property(property: String, value: Variant):
	UDict.append(_props, property, value)

# add a list of objects from DataParser
func _patch_list_object(property: String, type: String) -> Object:
	var obj: Object = PatchableData.new() if type == "" else UClass.create(type)
	UDict.append(_props, property, obj)
	return obj

func _get(property: StringName):
	if str(property) in _props:
		return _props[str(property)]

func _set(property: StringName, value) -> bool:
	if str(property) in _props:
		_props[str(property)] = value
		return true
	return false

#func get_string(id := "") -> String:
#	match id:
#		"speaker_name":
#			if "format" in self:
#				if self.format == "":
#					if Global.config.has_section_key("default_formats", get_class()):
#						var fmt = Global.config.get_value("default_formats", get_class(), DEFAULT_FORMAT)
#						return fmt.format(UObject.get_state(self))
#				else:
#					return self.format.format(UObject.get_state(self))
#	return DEFAULT_FORMAT.format(UObject.get_state(self))
