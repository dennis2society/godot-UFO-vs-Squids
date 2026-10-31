extends Node3D
## Mission 4: the boss arena. Faster kills earn better medals. Without squids to drop
## them, health packs and shield gems are delivered to spots under cover.

@export var boss_scene: PackedScene
@export var health_pack_scene: PackedScene
@export var shield_scene: PackedScene
@export var terrain: Node3D
@export var walls: Node3D
@export var player: Node3D
@export var hud: CanvasLayer
@export var menu: CanvasLayer
@export var mission_name := "Mission 4"
@export_file("*.tscn") var next_level := ""
@export var arrival_delay := 4.0 ## Seconds to look around before the boss turns up.
@export var boss_start := Vector3(0.0, 45.0, -80.0)
@export var base_threat := 25
@export var boss_health := 3000.0
@export var boss_health_per_threat := 120.0
@export var boss_skill_points := 3
@export var supply_interval := 22.0
@export var silver_time := 300.0 ## Seconds to the kill. Any kill earns at least bronze.
@export var gold_time := 180.0

var _boss: Node3D
var _time := 0.0
var _arrival := 0.0
var _supply_timer := 0.0
var _supply_spot := 0


func _ready() -> void:
	_arrival = arrival_delay
	_supply_timer = supply_interval
	hud.set_hint("Take cover when it charges  ·  Hit back between barrages  ·  Wheel: missile type  ·  T: skill tree")
	_update_objective()


func _process(delta: float) -> void:
	_time += delta
	if _boss == null:
		_arrival -= delta
		if _arrival <= 0.0:
			_spawn_boss()
	else:
		hud.set_waypoint(_boss.global_position, _boss.rare_label)
	_supply_timer -= delta
	if _supply_timer <= 0.0:
		_supply_timer = supply_interval
		_deliver_supplies()
	_update_objective()


func threat() -> int:
	return base_threat + Progress.threat()


func _spawn_boss() -> void:
	_boss = boss_scene.instantiate()
	_boss.player = player
	_boss.terrain = terrain
	_boss.max_health = boss_health + boss_health_per_threat * threat()
	_boss.position = boss_start
	_boss.health_changed.connect(hud.set_boss_health)
	_boss.barrage_warned.connect(_on_barrage_warned)
	_boss.died.connect(_on_boss_died)
	add_child(_boss)
	hud.set_boss_health(_boss.max_health, _boss.max_health)
	hud.show_toast("The Overmind has arrived", Color(1.0, 0.3, 0.2))


func _on_barrage_warned() -> void:
	hud.show_toast("TAKE COVER!", Color(1.0, 0.2, 0.15))


## Takes turns between the cover spots. A shield gem replaces the health pack whenever
## the shield skill has room to use one.
func _deliver_supplies() -> void:
	var spots: Array[Vector3] = walls.cover_spots
	_supply_spot = (_supply_spot + 1) % spots.size()
	var wants_shield: bool = Progress.rank("shield") > 0 and player.shield < player.max_shield
	var scene := shield_scene if wants_shield else health_pack_scene
	for child in get_children():
		if child is Area3D and child != _boss:
			child.queue_free() # Only the latest delivery stays on the map.
	var pickup: Node3D = scene.instantiate()
	pickup.position = spots[_supply_spot]
	add_child(pickup)


func _on_boss_died(_at: Vector3) -> void:
	set_process(false)
	hud.set_waypoint(null)
	hud.hide_boss_health()
	for i in boss_skill_points:
		Progress.add_point()
	var medal := 2 if _time <= gold_time else 1 if _time <= silver_time else 0
	var earned: Dictionary = Rewards.MEDALS[medal]
	Rewards.award(mission_name, medal, _time)
	menu.show_result("%s Medal\nOvermind destroyed in %s" % [earned.name, Rewards.format_clock(_time)],
			next_level, Color(earned.color))


func _update_objective() -> void:
	var target := gold_time if _time <= gold_time else silver_time
	var medal := "Gold" if _time <= gold_time else "Silver"
	hud.set_objective("Threat %d     Time %s     %s %s" % [
		threat(), Rewards.format_clock(_time), medal, Rewards.format_clock(target),
	])
