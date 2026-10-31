extends CanvasLayer
## Esc pause menu, also shown as the result screen when a mission ends. T jumps
## straight to the skill tree.

@export var player: Node
@export var stats: Label
@export var demo_end_delay := 4.0 ## Seconds the demo's result stays on screen.

var _next_scene := ""
var _finished := false
var _leaving := false
var _tree_from_game := false ## Leaving the tree resumes play instead of showing the menu.

@onready var center: Control = $Center
@onready var skill_tree: Control = $SkillTree
@onready var title: Label = $Center/Items/Title
@onready var rewards: RichTextLabel = $Center/Items/Rewards
@onready var continue_button: Button = $Center/Items/Continue
@onready var resume_button: Button = $Center/Items/Resume
@onready var skill_tree_button: Button = $Center/Items/SkillTree
@onready var restart_button: Button = $Center/Items/Restart
@onready var stats_toggle: CheckButton = $Center/Items/StatsToggle
@onready var music_toggle: CheckButton = $Center/Items/MusicToggle
@onready var hints_toggle: CheckButton = $Center/Items/HintsToggle
@onready var main_menu_button: Button = $Center/Items/MainMenu
@onready var quit_button: Button = $Center/Items/Quit


func _ready() -> void:
	hide()
	Progress.enter_level(get_tree().current_scene.scene_file_path)
	Music.start()
	continue_button.pressed.connect(_continue)
	resume_button.pressed.connect(_close)
	skill_tree_button.pressed.connect(_open_skill_tree)
	skill_tree.closed.connect(_close_skill_tree)
	restart_button.pressed.connect(_restart)
	main_menu_button.pressed.connect(_main_menu)
	quit_button.pressed.connect(get_tree().quit)
	music_toggle.button_pressed = Settings.music
	music_toggle.toggled.connect(Music.set_enabled)
	hints_toggle.button_pressed = Settings.hints
	hints_toggle.toggled.connect(Settings.set_hints)
	stats_toggle.button_pressed = stats.enabled
	stats_toggle.toggled.connect(stats.set_enabled)
	stats.enabled_changed.connect(stats_toggle.set_pressed_no_signal)
	player.destroyed.connect(_on_player_destroyed)
	if Progress.demo:
		_start_demo()


## Any key or click leaves the demo.
func _input(event: InputEvent) -> void:
	if not Progress.demo or event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventMouseButton:
		_main_menu()


func _start_demo() -> void:
	var pilot: Node = preload("res://player/demo_pilot.gd").new()
	pilot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pilot)
	pilot.setup(player, get_parent().get_node("Terrain"))
	var hud: CanvasLayer = get_parent().get_node("Hud")
	(func() -> void:
		hud.set_hint("DEMO: press any key to exit")
		hud.hint.show()
	).call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if Progress.demo:
		return
	if skill_tree.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("skill_tree"):
			_close_skill_tree()
	elif event.is_action_pressed("skill_tree"):
		_tree_from_game = not visible
		if not visible:
			_open("Paused")
		_open_skill_tree()
	elif not event.is_action_pressed("ui_cancel") or _finished:
		return
	elif visible:
		_close()
	else:
		_open("Paused")


## Ends the mission. A non-empty next_scene offers Continue instead of a retry.
func show_result(heading: String, next_scene := "", color := Color.WHITE) -> void:
	_finished = true
	_next_scene = next_scene
	if next_scene != "":
		Progress.complete_level(next_scene)
	title.modulate = color
	if Progress.demo:
		get_tree().create_timer(demo_end_delay).timeout.connect(_main_menu)
	_open(heading)


func _open(heading: String) -> void:
	title.text = heading
	rewards.text = "[center]%s[/center]" % Rewards.summary()
	rewards.visible = Rewards.summary() != ""
	resume_button.visible = not _finished
	stats_toggle.visible = not _finished
	music_toggle.visible = not _finished
	hints_toggle.visible = not _finished
	continue_button.visible = _next_scene != ""
	restart_button.visible = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for button: Button in [continue_button, resume_button, restart_button]:
		if button.visible:
			button.grab_focus()
			break


func _open_skill_tree() -> void:
	center.hide()
	skill_tree.open()


func _close_skill_tree() -> void:
	skill_tree.hide()
	center.show()
	if _tree_from_game:
		_tree_from_game = false
		_close()
	else:
		skill_tree_button.grab_focus()


func _close() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _continue() -> void:
	Progress.advance()
	get_tree().paused = false
	get_tree().change_scene_to_file(_next_scene)


func _main_menu() -> void:
	if not is_inside_tree() or _leaving:
		return
	_leaving = true
	Progress.leave_level()
	Music.stop()
	get_tree().paused = false
	get_tree().change_scene_to_file(Progress.TITLE_SCREEN)


func _on_player_destroyed() -> void:
	if not _finished:
		show_result("Game Over")
