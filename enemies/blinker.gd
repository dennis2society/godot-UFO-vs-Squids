extends "res://enemies/squid.gd"
## A rare crystal enemy that hangs still, then teleports to a new spot near the player.
## Spins up as a warning shortly before it jumps, and launches homing missiles that a
## boosting ship can only just outrun.

signal missile_fired

@export var stay_time := 5.0 ## Seconds between teleports.
@export var warning_time := 1.0 ## Spins faster for this long before jumping.
@export var min_jump_distance := 30.0
@export var max_jump_distance := 70.0
@export var hover_above_ground := 8.0
@export var missile_scene: PackedScene
@export var missile_interval := 9.0
@export var missile_damage := 30.0
@export var missile_speed_share := 0.93 ## Of the ship's full boost speed.

var spawn_range := 150.0

var _stay := 0.0
var _missile_timer := 3.0

@onready var rings: Array[Node3D] = [$Body/RingA, $Body/RingB]
@onready var flash: MeshInstance3D = $Flash
@onready var blink_sound: AudioStreamPlayer3D = $BlinkSound


func _ready() -> void:
	rare_label = "◈ BLINKER"
	super()
	_stay = stay_time


func _physics_process(delta: float) -> void:
	_time += delta
	_stay -= delta
	var spin := 8.0 if _stay < warning_time else 2.0
	rings[0].rotate_y(spin * delta)
	rings[1].rotate_x(spin * 0.7 * delta)
	var to_player := player.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), 1.0 - exp(-turn_speed * delta))
	_bite(delta)
	if _stay <= 0.0:
		_stay = stay_time
		_teleport()
	_missile_timer -= delta
	if _missile_timer <= 0.0:
		_missile_timer = missile_interval
		_fire_missile()


func _fire_missile() -> void:
	var missile := missile_scene.instantiate()
	missile.position = global_position + Vector3.UP * 2.0 * size
	missile.player = player
	missile.speed = player.speed * player.boost_multiplier * missile_speed_share
	missile.damage = missile_damage
	get_parent().add_child(missile)
	missile_fired.emit()


## A reachable random point around the player, clear of the ground and on the map.
func spot_near_player() -> Vector3:
	var angle := randf() * TAU
	var distance := randf_range(min_jump_distance, max_jump_distance)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * distance
	var at: Vector3 = player.global_position + offset
	at.x = clampf(at.x, -spawn_range, spawn_range)
	at.z = clampf(at.z, -spawn_range, spawn_range)
	var ground: float = terrain.height_at(at.x, at.z) + hover_above_ground * size
	at.y = maxf(player.global_position.y + randf_range(-5.0, 15.0), ground)
	return at


func _teleport() -> void:
	global_position = spot_near_player()
	reset_physics_interpolation()
	blink_sound.play()

	var material: StandardMaterial3D = flash.get_active_material(0).duplicate()
	flash.material_override = material
	flash.show()
	flash.scale = Vector3.ONE * 0.5
	material.albedo_color.a = 1.0
	body.scale = Vector3.ONE * 0.1
	var tween := create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.5, 0.35)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(body, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_rare_look() -> void:
	pass
