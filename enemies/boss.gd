extends "res://enemies/squid.gd"
## The Overmind: a vast armoured brain-squid that circles high above the arena's walls.
## On a fixed timer it charges up, warns, then rakes the player with fire nothing in the
## open survives. It keeps above the cover, so walls and roofs always stop its shots.

signal health_changed(health: float, maximum: float)
signal barrage_warned

enum Phase { HUNT, WINDUP, BARRAGE }

@export var fly_speed := 36.0
@export var hover_height := 38.0 ## Above the tallest wall.
@export var ground_clearance_min := 24.0
@export var orbit_radius_range := Vector2(28.0, 56.0)
@export var orbit_speed_range := Vector2(0.4, 1.3) ## Radians per second around the player.
@export var barrage_orbit_speed := 0.12 ## Slow, so cover stays cover.
@export var extra_height := 16.0 ## Most it climbs above the hover height.
@export var maneuver_time_range := Vector2(1.2, 3.5) ## Seconds between changes of plan.
@export_range(0.0, 1.0) var crossing_chance := 0.3 ## Swings to the player's far side.
@export var hunt_time := 7.0
@export var windup_time := 2.5
@export var barrage_time := 3.5
@export var barrage_interval := 0.09
@export var barrage_damage := 12.0
@export var aim_lead := 0.85 ## Share of the player's velocity it aims ahead by.
@export var aim_spread := 0.02 ## Radians.
@export var arm_count := 8
@export var arm_segments := 5
@export var arm_material: Material
@export var eye_material: StandardMaterial3D
@export var calm_eye := Color(1.0, 0.65, 0.1)
@export var angry_eye := Color(1.0, 0.05, 0.02)

var _state := Phase.HUNT
var _state_time := 0.0
var _shot_cooldown := 0.0
var _orbit := 0.0
var _orbit_speed := 0.8
var _orbit_radius := 46.0
var _height := 38.0
var _maneuver_timer := 0.0
var _arms: Array[Node3D] = []

@onready var ring_a: Node3D = $Body/RingA
@onready var ring_b: Node3D = $Body/RingB
@onready var cannon: Node3D = $Body/Cannon
@onready var charge_sound: AudioStreamPlayer = $ChargeSound


func _ready() -> void:
	rare_label = "☠ OVERMIND"
	bonus = true
	tentacle_count = 0
	super()
	_state_time = hunt_time * 0.5 # A short first breather.
	_orbit = randf() * TAU
	eye_material.emission = calm_eye
	_build_arms()


func _physics_process(delta: float) -> void:
	_time += delta
	_state_time -= delta
	if _state_time <= 0.0:
		_next_state()
	_fly(delta)
	_animate(delta)
	_bite(delta)
	if _state == Phase.BARRAGE:
		_shot_cooldown -= delta
		if _shot_cooldown <= 0.0:
			_shot_cooldown = barrage_interval
			_fire()


func _next_state() -> void:
	match _state:
		Phase.HUNT:
			_state = Phase.WINDUP
			_state_time = windup_time
			eye_material.emission = angry_eye
			charge_sound.play()
			barrage_warned.emit()
		Phase.WINDUP:
			_state = Phase.BARRAGE
			_state_time = barrage_time
		Phase.BARRAGE:
			_state = Phase.HUNT
			_state_time = hunt_time
			eye_material.emission = calm_eye


func _fly(delta: float) -> void:
	_maneuver_timer -= delta
	if _state == Phase.HUNT and _maneuver_timer <= 0.0:
		_pick_maneuver()
	var slow_orbit := signf(_orbit_speed) * barrage_orbit_speed
	_orbit += (_orbit_speed if _state == Phase.HUNT else slow_orbit) * delta
	var goal: Vector3 = player.global_position + Vector3(cos(_orbit), 0.0, sin(_orbit)) * _orbit_radius
	goal.x = clampf(goal.x, -player.bounds, player.bounds)
	goal.z = clampf(goal.z, -player.bounds, player.bounds)
	goal.y = maxf(_height, terrain.height_at(goal.x, goal.z) + ground_clearance_min)
	global_position = global_position.move_toward(goal, fly_speed * delta)
	var to_player := player.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), 1.0 - exp(-turn_speed * delta))


## A fresh direction, distance, height and pace, so its circling can't be predicted.
func _pick_maneuver() -> void:
	_maneuver_timer = randf_range(maneuver_time_range.x, maneuver_time_range.y)
	_orbit_speed = randf_range(orbit_speed_range.x, orbit_speed_range.y) * ([-1.0, 1.0].pick_random() as float)
	_orbit_radius = randf_range(orbit_radius_range.x, orbit_radius_range.y)
	_height = hover_height + randf() * extra_height
	if randf() < crossing_chance:
		_orbit += randf_range(PI * 0.6, PI * 1.4)


## Shots lead a moving target, so outrunning a barrage in the open doesn't work.
func _fire() -> void:
	var shot := shot_scene.instantiate()
	var from := cannon.global_position
	var flight: float = from.distance_to(player.global_position) / shot.speed
	var aim: Vector3 = player.global_position + player.velocity * flight * aim_lead
	var direction := from.direction_to(aim)
	shot.direction = direction.rotated(Vector3.UP, randf_range(-aim_spread, aim_spread)) \
			.rotated(Vector3.RIGHT, randf_range(-aim_spread, aim_spread))
	shot.position = from
	shot.damage = barrage_damage
	get_parent().add_child(shot)


func _animate(delta: float) -> void:
	var spin := 5.0 if _state != Phase.HUNT else 1.0
	ring_a.rotate_y(spin * delta)
	ring_b.rotate_x(spin * 0.6 * delta)
	for i in _arms.size():
		var sway := sin(_time * 1.8 + i * 0.9) * 0.2
		_arms[i].rotation.x = 0.5 + sway
		for joint in _arms[i].get_children():
			if joint is Node3D and joint.get_child_count() > 0:
				joint.rotation.x = sway * 0.7


## Eight tapering tentacles of chained segments hanging from the underside.
func _build_arms() -> void:
	for i in arm_count:
		var mount := Node3D.new()
		var angle := TAU * i / arm_count
		mount.position = Vector3(cos(angle) * 3.4, -2.6, sin(angle) * 3.4)
		mount.rotation.y = -angle - PI * 0.5
		body.add_child(mount)
		var arm := Node3D.new()
		mount.add_child(arm)
		_arms.append(arm)
		var parent := arm
		for segment in arm_segments:
			var thickness := 0.75 * (1.0 - float(segment) / arm_segments) + 0.15
			var part := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = thickness
			mesh.height = 2.6
			mesh.radial_segments = 12
			mesh.rings = 3
			mesh.material = arm_material
			part.mesh = mesh
			part.position.y = -1.0
			var joint := Node3D.new()
			joint.add_child(part)
			parent.add_child(joint)
			if segment > 0:
				joint.position.y = -2.0
			parent = joint


func _apply_rare_look() -> void:
	pass


func _flinch() -> void:
	pass


func _update_health_bar() -> void:
	health_changed.emit(_health, max_health)
