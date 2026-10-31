extends Node
## Player preferences. They have their own file, so a new game doesn't reset them.

signal hints_changed(value: bool)

const PATH := "user://settings.cfg"

var music := true
var hints := true


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		music = file.get_value("audio", "music", true)
		hints = file.get_value("ui", "hints", true)


func set_music(value: bool) -> void:
	music = value
	_save()


func set_hints(value: bool) -> void:
	hints = value
	_save()
	hints_changed.emit(value)


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music)
	file.set_value("ui", "hints", hints)
	file.save(PATH)
