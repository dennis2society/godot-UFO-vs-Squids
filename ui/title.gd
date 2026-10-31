extends Control
## Offers to pick the campaign back up. With nothing saved it goes straight to the game.

const DEBUG_MENU := true ## Temporary level select. Remove with the Debug nodes.

@onready var continue_button: Button = $Center/Items/Continue
@onready var new_game_button: Button = $Center/Items/NewGame
@onready var demo_button: Button = $Center/Items/Demo
@onready var quit_button: Button = $Center/Items/Quit
@onready var debug_box: Control = $Center/Items/Debug
@onready var debug_levels: Container = $Center/Items/Debug/Levels
@onready var debug_powerups: CheckButton = $Center/Items/Debug/UsePowerups


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Levels capture it, and may not hand it back.
	if not Progress.has_save() and not DEBUG_MENU:
		_start_new_game.call_deferred()
		return
	continue_button.visible = Progress.has_save()
	continue_button.text = "Continue: %s" % Progress.level_name()
	continue_button.pressed.connect(_continue)
	new_game_button.pressed.connect(_start_new_game)
	demo_button.pressed.connect(_watch_demo)
	quit_button.pressed.connect(get_tree().quit)
	(continue_button if Progress.has_save() else new_game_button).grab_focus()
	debug_box.visible = DEBUG_MENU
	for level: String in Progress.LEVEL_NAMES:
		var button := Button.new()
		button.text = Progress.LEVEL_NAMES[level]
		button.pressed.connect(_debug_start.bind(level))
		debug_levels.add_child(button)


func _continue() -> void:
	get_tree().change_scene_to_file(Progress.run.level)


func _watch_demo() -> void:
	Progress.demo_start()
	get_tree().change_scene_to_file(Progress.DEMO_LEVEL)


func _start_new_game() -> void:
	Progress.new_game()
	get_tree().change_scene_to_file(Progress.FIRST_LEVEL)


func _debug_start(level: String) -> void:
	Progress.debug_start(level, debug_powerups.button_pressed)
	get_tree().change_scene_to_file(level)
