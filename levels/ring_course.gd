extends Node3D
## Mission 1: fly through every ring of a snaking course in order. Medal times follow
## from the course length at the bare ship's boost speed, so every random course is
## equally hard, and gold takes a faster ship than that. Starts when the player moves.

@export var ring_scene: PackedScene
@export var terrain: Node3D
@export var player: Node3D
@export var hud: CanvasLayer
@export var menu: CanvasLayer
@export_file("*.tscn") var next_level := "res://levels/main.tscn"
@export var ring_count := 22
@export var course_start := 96.0 ## Z of the first ring end of the course.
@export var course_end := -112.0
@export var snake_width := 72.0 ## Sideways reach of each bend.
@export var snake_bends := 3.5 ## Full left-right waves along the course.
@export var climb_waves := 2.5
@export var position_jitter := 5.0
@export var min_clearance := 8.0
@export var max_clearance := 34.0
@export var bronze_pace := 1.6 ## Also the time limit. Multiples of the time to fly the
@export var silver_pace := 1.4 ## course's length in straight lines at full boost.
@export var gold_pace := 1.05 ## Out of reach without a few ranks of Thrusters.

var bronze_time := 0.0
var silver_time := 0.0
var gold_time := 0.0

var _rings: Array[Node3D] = []
var _current := 0
var _time := 0.0
var _started := false
var _last_position: Vector3


func _ready() -> void:
	_last_position = player.global_position
	var ideal: float = _build_rings() / (player.base_speed * player.base_boost)
	bronze_time = ideal * bronze_pace
	silver_time = ideal * silver_pace
	gold_time = ideal * gold_pace
	_rings[0].set_active(true)
	hud.set_hint("Mouse look  ·  WASD fly  ·  Space/Ctrl up/down  ·  Shift boost")
	_update_hud()


func _physics_process(delta: float) -> void:
	_started = _started or player.velocity.length() > 1.0
	if _started:
		_time += delta
	var position_now: Vector3 = player.global_position
	if _rings[_current].crossed_by(_last_position, position_now):
		_pass_ring()
	_last_position = position_now
	if _current < _rings.size() and _time > bronze_time:
		set_physics_process(false)
		hud.set_waypoint(null)
		menu.show_result("Time's Up")
	elif _current < _rings.size():
		_update_hud()


## Snakes the rings ahead of the player, climbing and diving through the bends, each
## one square to the path. Returns the course length.
func _build_rings() -> float:
	var points: Array[Vector3] = [player.global_position]
	for i in ring_count:
		var along := (i + 1.0) / ring_count
		var x := sin(along * snake_bends * TAU) * snake_width
		var z := lerpf(course_start, course_end, along)
		x += randf_range(-position_jitter, position_jitter)
		z += randf_range(-position_jitter, position_jitter)
		var climb := 0.5 + 0.5 * sin(along * climb_waves * TAU)
		points.append(Vector3(x, terrain.height_at(x, z) + lerpf(min_clearance, max_clearance, climb), z))

	var length := 0.0
	for i in ring_count:
		var ring := ring_scene.instantiate()
		ring.position = points[i + 1]
		ring.basis = Basis.looking_at(points[mini(i + 2, ring_count)].direction_to(points[i]))
		add_child(ring)
		_rings.append(ring)
		length += points[i].distance_to(points[i + 1])
	return length


func _pass_ring() -> void:
	_rings[_current].hide()
	_current += 1
	player.pickup_sound.play()
	if _current == _rings.size():
		set_physics_process(false)
		hud.set_waypoint(null)
		hud.set_objective("All rings cleared")
		var medal := _medal_for(_time)
		Rewards.award("Mission 1", medal, _time)
		var earned: Dictionary = Rewards.MEDALS[medal]
		menu.show_result("%s Medal\n%.2f s" % [earned.name, _time], next_level, Color(earned.color))
	else:
		_rings[_current].set_active(true)


func _medal_for(time: float) -> int:
	if time <= gold_time:
		return 2
	return 1 if time <= silver_time else 0


## The best medal still within reach, for the HUD.
func _next_target() -> String:
	var target := gold_time if _time <= gold_time else silver_time if _time <= silver_time else bronze_time
	return "%s %.1f" % [Rewards.MEDALS[_medal_for(minf(_time, target))].name, target]


func _update_hud() -> void:
	hud.set_objective("Ring %d / %d     Time %.1f     %s" % [
		_current + 1, _rings.size(), _time, _next_target()
	])
	hud.set_waypoint(_rings[_current].global_position)
