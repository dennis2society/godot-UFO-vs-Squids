extends Node
## Player preferences. They have their own file, so a new game doesn't reset them.

signal hints_changed(value: bool)

const PATH := "user://settings.cfg"

var music := true
var hints := true
var vsync := true
var music_volume := 1.0 ## From 0 to 1.
var sfx_volume := 1.0


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		music = file.get_value("audio", "music", true)
		hints = file.get_value("ui", "hints", true)
		vsync = file.get_value("video", "vsync", true)
		music_volume = file.get_value("audio", "music_volume", 1.0)
		sfx_volume = file.get_value("audio", "sfx_volume", 1.0)
	_apply_vsync()
	_apply_volume("Music", music_volume)
	_apply_volume("SFX", sfx_volume)


func set_music(value: bool) -> void:
	music = value
	_save()


func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_volume("Music", value)
	_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_apply_volume("SFX", value)
	_save()


func _apply_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))
	AudioServer.set_bus_mute(bus, value <= 0.0)


func set_hints(value: bool) -> void:
	hints = value
	_save()
	hints_changed.emit(value)


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_vsync()
	_save()


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("audio", "sfx_volume", sfx_volume)
	file.set_value("ui", "hints", hints)
	file.set_value("video", "vsync", vsync)
	file.save(PATH)
