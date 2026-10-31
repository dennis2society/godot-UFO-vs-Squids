extends Node3D
## A slow squid shot, easy to see coming. Passes through other squids.

@export var speed := 40.0
@export var lifetime := 3.0

var direction := Vector3.FORWARD
var damage := 6.0


func _physics_process(delta: float) -> void:
	lifetime -= delta
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(damage)
	if hit or lifetime <= 0.0:
		queue_free()
		return
	global_position = next
