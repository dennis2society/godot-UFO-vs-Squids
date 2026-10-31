extends Node3D
## A slower projectile that explodes on impact, when near an enemy, or at the end of its
## flight. Homing ones steer for whichever enemy lies closest to their line of flight.

@export var speed := 70.0
@export var lifetime := 3.0
@export var fuse_range := 3.0 ## Detonates when an enemy comes within this distance.
@export var explosion_scene: PackedScene
@export var turn_rate := 3.5 ## Radians per second, when homing.
@export var seek_range := 120.0
@export var seek_cone := 0.4 ## Dot product with the flight direction.

var direction := Vector3.FORWARD
var shooter: PhysicsBody3D
var damage := 4.0
var radius := 5.0
var homing := false

var _target: Node3D


func _ready() -> void:
	basis = Basis.looking_at(direction)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if homing:
		_steer(delta)
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next)
	query.collide_with_areas = true
	query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_explode(hit.position)
	elif _enemy_in_fuse():
		_explode(global_position)
	elif lifetime <= 0.0:
		_explode(next)
	else:
		global_position = next


func _steer(delta: float) -> void:
	if _target == null or not _target.is_in_group("enemies"):
		_target = _find_target()
	if _target == null:
		return
	var wanted := global_position.direction_to(_target.global_position)
	var angle := direction.angle_to(wanted)
	if angle > 0.001:
		direction = direction.slerp(wanted, minf(turn_rate * delta / angle, 1.0)).normalized()
		basis = Basis.looking_at(direction)


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_dot := seek_cone
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		var to_enemy := enemy.global_position - global_position
		var dot := direction.dot(to_enemy.normalized())
		if dot > best_dot and to_enemy.length() < seek_range:
			best = enemy
			best_dot = dot
	return best


func _enemy_in_fuse() -> bool:
	var shape := SphereShape3D.new()
	shape.radius = fuse_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [shooter.get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		if result.collider.has_method("apply_damage"):
			return true
	return false


func _explode(at: Vector3) -> void:
	var explosion := explosion_scene.instantiate()
	explosion.position = at
	explosion.radius = radius
	explosion.damage = damage
	get_parent().add_child(explosion)
	queue_free()
