extends Label
## Shows the frame rate and the size the game renders at.
## F3 or the pause menu toggles it. Hidden by default, and the choice carries over between levels.

signal enabled_changed(value: bool)

static var enabled := false


func _ready() -> void:
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		set_enabled(not enabled)


func set_enabled(value: bool) -> void:
	enabled = value
	_apply()
	enabled_changed.emit(value)


func _process(_delta: float) -> void:
	var render := Vector2i(Vector2(get_tree().root.size) * get_tree().root.scaling_3d_scale)
	text = "%d FPS   %d x %d" % [Engine.get_frames_per_second(), render.x, render.y]


func _apply() -> void:
	visible = enabled
	set_process(enabled)
