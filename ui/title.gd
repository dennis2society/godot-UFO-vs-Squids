extends Control
## Offers to pick the campaign back up, from any mission reached so far. With nothing
## saved it goes straight to the game.

const DEBUG_MENU := true ## Temporary level select. Remove with the Debug nodes.

@onready var continue_button: Button = $Center/Items/Continue
@onready var new_game_button: Button = $Center/Items/NewGame
@onready var demo_button: Button = $Center/Items/Demo
@onready var vsync_toggle: CheckButton = $Center/Items/VsyncToggle
@onready var quit_button: Button = $Center/Items/Quit
@onready var chooser: Control = $Center/Items/Chooser
@onready var missions: Container = $Center/Items/Chooser/Missions
@onready var back_button: Button = $Center/Items/Chooser/Back
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
	back_button.pressed.connect(_show_chooser.bind(false))
	new_game_button.pressed.connect(_start_new_game)
	demo_button.pressed.connect(_watch_demo)
	vsync_toggle.button_pressed = Settings.vsync
	vsync_toggle.toggled.connect(Settings.set_vsync)
	quit_button.pressed.connect(get_tree().quit)
	(continue_button if Progress.has_save() else new_game_button).grab_focus()
	debug_box.visible = DEBUG_MENU
	for level: String in Progress.LEVEL_NAMES:
		var button := Button.new()
		button.text = Progress.LEVEL_NAMES[level]
		button.pressed.connect(_debug_start.bind(level))
		debug_levels.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if chooser.visible and event.is_action_pressed("ui_cancel"):
		_show_chooser(false)


## One mission reached starts straight away, otherwise the player picks.
func _continue() -> void:
	if Progress.reached_levels().size() > 1:
		_show_chooser(true)
	else:
		_start_level(Progress.run.level)


func _start_level(level: String) -> void:
	get_tree().change_scene_to_file(level)


func _show_chooser(open: bool) -> void:
	for button: Control in [continue_button, new_game_button, demo_button, vsync_toggle, quit_button]:
		button.visible = not open
	chooser.visible = open
	debug_box.visible = DEBUG_MENU and not open
	if not open:
		continue_button.grab_focus()
		return
	for child in missions.get_children():
		missions.remove_child(child)
		child.queue_free()
	for level: String in Progress.reached_levels():
		var button := Button.new()
		button.text = Progress.LEVEL_NAMES[level]
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_start_level.bind(level))
		missions.add_child(button)
		if level == Progress.run.level:
			button.grab_focus()


func _watch_demo() -> void:
	Progress.demo_start()
	get_tree().change_scene_to_file(Progress.DEMO_LEVEL)


func _start_new_game() -> void:
	Progress.new_game()
	get_tree().change_scene_to_file(Progress.FIRST_LEVEL)


func _debug_start(level: String) -> void:
	Progress.debug_start(level, debug_powerups.button_pressed)
	get_tree().change_scene_to_file(level)
