@tool
extends EditorScript

class Ass:
	var name := ""

var a: Array[int] = [0, 2]
var b: Array[String] = ["ok", "yes"]

func _run():
	prints(a, typeof(a), UType.get_name_from_type(typeof(a)))
	
	var c = "1234024"
	print(str2var("123_4123_32"))
	
#	var dp = DataParser.new()
#	var d = dp.parse("res://data.soda")
#	print(dp.dict_to_str(d))
