extends Area3D
## A big slow ball of plasma. Explodes on touching an enemy or terrain, when shot by the
## player, when told to detonate, or at the end of its flight.

@export var speed := 32.0
@export var lifetime := 6.0
@export var spin_speed := 6.0
@export var explosion_scene: PackedScene

var direction := Vector3.FORWARD
var shooter: PhysicsBody3D
var damage := 150.0
var radius := 28.0
var size := 2.0

var _detonated := false

@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	scale = Vector3.ONE * size


func _physics_process(delta: float) -> void:
	lifetime -= delta
	global_position += direction * speed * delta
	ring.rotate_object_local(Vector3.BACK, spin_speed * delta)
	if lifetime <= 0.0 or _touching_something():
		detonate()


## Called by weapons, so any hit sets it off.
func take_hit(_damage: float, _crit: float, _from: Vector3, _direction: Vector3) -> void:
	detonate()


func apply_damage(_amount: float, _crit := false) -> void:
	detonate()


func detonate() -> void:
	if _detonated:
		return
	_detonated = true
	var explosion := explosion_scene.instantiate()
	explosion.position = global_position
	explosion.radius = radius
	explosion.damage = damage
	get_parent().add_child(explosion)
	queue_free()


func _touching_something() -> bool:
	var shape := SphereShape3D.new()
	shape.radius = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = true
	query.exclude = [get_rid(), shooter.get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 8):
		if result.collider is StaticBody3D or result.collider.has_method("take_hit"):
			return true
	return false
