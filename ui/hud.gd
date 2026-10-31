extends CanvasLayer
## Shows life, shield, the current objective, skills, and a marker towards the next waypoint.

const Weapon := preload("res://weapons/weapon.gd")
const BRANCH_COLORS := {
	"Laser": Color(1.0, 0.55, 0.1), "Spread": Color(1.0, 0.8, 0.3), "Plasma": Color(1.0, 0.25, 0.25),
	"Missiles": Color(0.3, 0.6, 1.0), "Shield": Color(0.4, 0.85, 1.0), "Engines": Color(0.5, 1.0, 0.55),
}

@export var player: Node
@export var full_color := Color(0.3, 0.9, 0.3)
@export var empty_color := Color(0.9, 0.15, 0.1)
@export var edge_margin := 40.0
@export var skill_point_color := Color(1.0, 0.82, 0.2)

var _waypoint: Variant = null
var _waypoint_text := ""

@onready var life_bar: ProgressBar = $LifeBar
@onready var shield_bar: ProgressBar = $ShieldBar
@onready var boss_bar: ProgressBar = $BossBar
@onready var mission_name: Label = $MissionName
@onready var objective: Label = $Objective
@onready var hint: Label = $Hint
@onready var toast: Label = $Toast
@onready var upgrades_panel: Control = $UpgradesPanel
@onready var upgrades: RichTextLabel = $UpgradesPanel/Upgrades
@onready var waypoint_label: Label = $Waypoint


func _ready() -> void:
	player.health_changed.connect(_on_health_changed)
	player.shield_changed.connect(_on_shield_changed)
	player.weapon.missile_switched.connect(_on_missile_switched)
	player.weapon.plasma_not_ready.connect(_on_plasma_not_ready)
	Progress.skills_changed.connect(_on_skills_changed)
	Progress.point_gained.connect(_on_point_gained)
	$Crosshair.weapon = player.weapon
	Settings.hints_changed.connect(hint.set_visible)
	hint.visible = Settings.hints
	mission_name.text = Progress.LEVEL_NAMES.get(get_tree().current_scene.scene_file_path, "")
	$Minimap.player = player
	$Compass.player = player
	_on_skills_changed()


func _process(_delta: float) -> void:
	waypoint_label.visible = _waypoint != null
	if _waypoint == null:
		return

	var camera := get_viewport().get_camera_3d()
	var bounds := get_viewport().get_visible_rect().size
	var at := camera.unproject_position(_waypoint)
	if camera.is_position_behind(_waypoint):
		# Unprojection mirrors points behind the camera, so push them to the screen edge.
		at = bounds * 0.5 - (at - bounds * 0.5).normalized() * bounds.length()
	at = at.clamp(Vector2.ONE * edge_margin, bounds - Vector2.ONE * edge_margin)

	var distance: float = camera.global_position.distance_to(_waypoint)
	waypoint_label.text = "%s\n%d m" % [_waypoint_text, distance]
	waypoint_label.position = at - waypoint_label.size * 0.5


func set_objective(text: String) -> void:
	objective.text = text


func set_hint(text: String) -> void:
	hint.text = text


## Pass a world position to mark, or null to hide the marker.
func set_waypoint(world_position: Variant, text := "◆") -> void:
	_waypoint = world_position
	_waypoint_text = text
	waypoint_label.visible = world_position != null


func set_boss_health(health: float, maximum: float) -> void:
	boss_bar.show()
	boss_bar.max_value = maximum
	boss_bar.value = health


func hide_boss_health() -> void:
	boss_bar.hide()


func show_toast(text: String, color: Color) -> void:
	toast.text = text
	toast.modulate = color
	create_tween().tween_property(toast, "modulate:a", 0.0, 2.0).set_delay(0.8)


func _on_health_changed(health: float) -> void:
	life_bar.value = health
	var fill: StyleBoxFlat = life_bar.get_theme_stylebox("fill")
	fill.bg_color = empty_color.lerp(full_color, health / player.max_health)


func _on_shield_changed(shield: float) -> void:
	shield_bar.value = shield


func _on_skills_changed() -> void:
	life_bar.max_value = player.max_health
	shield_bar.max_value = player.max_shield
	shield_bar.visible = player.max_shield > 0.0
	_on_health_changed(player.health)
	_on_shield_changed(player.shield)
	_refresh_upgrades()


func _on_point_gained() -> void:
	show_toast("Skill point! Press T to spend it", skill_point_color)


func _on_plasma_not_ready(seconds: float) -> void:
	show_toast("Plasma recharging: %d s" % ceili(seconds), Weapon.WEAPON_COLORS["plasma"])


func _on_missile_switched(type: Dictionary) -> void:
	show_toast("%s missiles" % type.name, Weapon.WEAPON_COLORS["missile"])
	_refresh_upgrades()


func _refresh_upgrades() -> void:
	var lines := PackedStringArray()
	if Progress.points > 0:
		lines.append("[color=#%s]★ Skill points %d  (T)[/color]" % [
			skill_point_color.to_html(false), Progress.points
		])
	for branch: String in BRANCH_COLORS:
		var held := Progress.branch_ranks(branch)
		if held > 0:
			lines.append("[color=#%s]%s %d[/color]" % [BRANCH_COLORS[branch].to_html(false), branch, held])
	lines.append("[color=#%s]▶ %s missiles  (wheel)[/color]" % [
		Weapon.WEAPON_COLORS["missile"].to_html(false),
		Weapon.MISSILE_TYPES[player.weapon.missile_type].name,
	])
	upgrades.text = "\n".join(lines)
	upgrades_panel.visible = not lines.is_empty()
