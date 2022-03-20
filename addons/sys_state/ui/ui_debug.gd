extends Node

var lines := []
var filter := ""
var only_modified := true

func _ready() -> void:
	$VBoxContainer/HBoxContainer/Button.pressed.connect(_update)
	$VBoxContainer/HBoxContainer/CheckButton.toggled.connect(_toggled)
	$VBoxContainer/HBoxContainer/LineEdit.text_changed.connect(_filter_changed)
	State.changed_from_to.connect(_changed)

func _toggled(t):
	only_modified = t
	_update()

func _changed(property, from, to):
	_update()

func _filter_changed(t: String):
	filter = t
	_redraw()

func _update():
	var state := State._get_changed_states() if only_modified else State._get_state()
	lines = JSON.new().stringify(state, "\t", false).split("\n")
	_redraw()
	
func _redraw():
	var text = []
	for line in lines:
		if filter == "" or filter in line.to_lower():
			text.append(line)
	$VBoxContainer/RichTextLabel.set_bbcode("\n".join(text))