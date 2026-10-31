extends Area3D
## A hovering squid that hunts the player when near. Takes extra damage in the eyes,
## and flying into it pops it but hurts the player.

signal died(at: Vector3)

@export var tentacle_count := 6
@export var tentacle_mesh: Mesh
@export var drift_radius := 4.0
@export var aggro_range := 70.0
@export var ground_clearance := 3.0
@export var eye_hit_radius := 0.42
@export var turn_speed := 4.0
@export var bonus_material: Material ## Worn instead of violet by bonus targets.
@export var bonus_bite_interval := 1.0 ## Bonus targets survive contact and bite again.
@export var shot_scene: PackedScene
@export var shot_range := 60.0

var player: Node3D
var terrain: Node3D
var max_health := 2.0
var chase_speed := 3.0
var contact_damage := 20.0
var size := 1.0
var bonus := false ## Rare targets survive contact and bite instead.
var rare_label := "★ BONUS"
var shot_interval := 0.0 ## Seconds between shots, or 0 for a squid that doesn't shoot.
var shot_damage := 6.0

var _health := 2.0
var _home: Vector3
var _phase := randf() * TAU
var _time := 0.0
var _tentacles: Array[Node3D] = []
var _bite_cooldown := 0.0
var _shot_timer := 0.0

@onready var body: Node3D = $Body
@onready var burst: CPUParticles3D = $Burst
@onready var collision: CollisionShape3D = $Collision
@onready var explosion_sound: AudioStreamPlayer3D = $ExplosionSound
@onready var health_bar: MeshInstance3D = $HealthBar
@onready var eyes: Array[Node3D] = [$Body/EyeLeft, $Body/EyeRight]


func _ready() -> void:
	_home = position
	_health = max_health
	_shot_timer = randf() * shot_interval
	scale = Vector3.ONE * size
	add_to_group("enemies")
	body_entered.connect(_on_body_entered)
	for i in tentacle_count:
		var angle := TAU * i / tentacle_count
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(angle) * 0.3, -0.55, sin(angle) * 0.3)
		pivot.rotation.y = -angle
		var tentacle := MeshInstance3D.new()
		tentacle.mesh = tentacle_mesh
		tentacle.position.y = -0.55
		pivot.add_child(tentacle)
		body.add_child(pivot)
		_tentacles.append(pivot)
		if bonus:
			tentacle.material_override = bonus_material

	if bonus:
		_apply_rare_look()
		_update_health_bar()


func _physics_process(delta: float) -> void:
	_time += delta
	var t := _time + _phase

	var to_player := player.global_position - global_position
	if to_player.length() < aggro_range:
		_home += to_player.normalized() * _chase_speed() * delta
		var facing := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-turn_speed * delta))
	var floor_height := ground_clearance * size
	_home.y = maxf(_home.y, terrain.height_at(_home.x, _home.z) + floor_height)

	var next := _home + Vector3(
		cos(t * 0.3) * drift_radius,
		sin(t * 1.5) * 0.5,
		sin(t * 0.4) * drift_radius
	)
	next.y = maxf(next.y, terrain.height_at(next.x, next.z) + floor_height)
	position = next
	for i in _tentacles.size():
		_tentacles[i].rotation.z = 0.35 + sin(t * 3.0 + i) * 0.2

	_bite(delta)
	_shoot(delta)


func _chase_speed() -> float:
	return chase_speed


func _apply_rare_look() -> void:
	aggro_range = INF
	for part: MeshInstance3D in [$Body/Mantle, $Body/FinLeft, $Body/FinRight]:
		part.material_override = bonus_material


func _bite(delta: float) -> void:
	_bite_cooldown -= delta
	if bonus and _bite_cooldown <= 0.0 and body.visible:
		for other in get_overlapping_bodies():
			if other.has_method("take_damage"):
				_bite_cooldown = bonus_bite_interval
				other.take_damage(contact_damage)


func _shoot(delta: float) -> void:
	if shot_interval <= 0.0:
		return
	_shot_timer -= delta
	if _shot_timer > 0.0 or global_position.distance_to(player.global_position) > shot_range:
		return
	_shot_timer = shot_interval * randf_range(0.8, 1.2)
	var shot := shot_scene.instantiate()
	shot.position = global_position
	shot.direction = global_position.direction_to(player.global_position)
	shot.damage = shot_damage
	get_parent().add_child(shot)


## A bolt hit. Shots passing close to an eye that faces them count as crits.
func take_hit(damage: float, crit_multiplier: float, from: Vector3, direction: Vector3) -> void:
	var crit := _hits_eye(from, direction)
	apply_damage(damage * crit_multiplier if crit else damage, crit)


func apply_damage(amount: float, crit := false) -> void:
	if not body.visible:
		return
	_health -= amount
	_show_damage_number(amount, crit)
	if _health <= 0.0:
		_die()
		return

	_update_health_bar()
	_flinch()


func _flinch() -> void:
	body.scale = Vector3.ONE * 1.2
	create_tween().tween_property(body, "scale", Vector3.ONE, 0.15)


func _update_health_bar() -> void:
	health_bar.show()
	health_bar.scale.x = _health / max_health


func _hits_eye(from: Vector3, direction: Vector3) -> bool:
	var reach := from + direction * 12.0 * size
	for eye in eyes:
		var outward := global_position.direction_to(eye.global_position)
		var closest := Geometry3D.get_closest_point_to_segment(eye.global_position, from, reach)
		if outward.dot(direction) < 0.0 \
				and closest.distance_to(eye.global_position) < eye_hit_radius * size:
			return true
	return false


func _show_damage_number(amount: float, crit: bool) -> void:
	var label := Label3D.new()
	label.text = ("CRIT %.1f" if crit else "%.1f") % amount
	label.modulate = Color(1.0, 0.85, 0.1) if crit else Color.WHITE
	label.font_size = 96 if crit else 64
	label.pixel_size = 0.0005
	label.fixed_size = true
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var spread := Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 0.8), 0.0)
	label.position = global_position + (Vector3.UP * 1.5 + spread) * size
	get_parent().add_child(label)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 2.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)


func _die() -> void:
	remove_from_group("enemies")
	collision.set_deferred("disabled", true)
	set_physics_process(false)
	body.hide()
	health_bar.hide()
	burst.emitting = true
	explosion_sound.play()
	died.emit(global_position)
	await burst.finished
	queue_free()


func _on_body_entered(other: Node3D) -> void:
	if other.has_method("take_damage") and body.visible and not bonus:
		other.take_damage(contact_damage)
		_die()
