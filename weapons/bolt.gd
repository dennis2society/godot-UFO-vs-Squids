extends Node3D
## A laser bolt. Sweeps a ray each tick so it can't pass through thin targets.

@export var speed := 150.0

var direction := Vector3.FORWARD
var shooter: PhysicsBody3D
var damage := 1.0
var crit_multiplier := 2.0
var max_range := 80.0
var width := 1.0
var length := 1.0
var material: Material
var pierce := 0 ## Targets it can pass through.

var _travelled := 0.0
var _passed: Array[RID] = []

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	basis = Basis.looking_at(direction)
	mesh.scale = Vector3(width, length, width)
	mesh.material_override = material


func _physics_process(delta: float) -> void:
	_travelled += speed * delta
	if _travelled >= max_range:
		queue_free()
		return

	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next)
	query.collide_with_areas = true
	var ignored: Array[RID] = [shooter.get_rid()]
	ignored.append_array(_passed)
	query.exclude = ignored
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		var target: Object = hit.collider
		if target.has_method("take_hit"):
			target.take_hit(damage, crit_multiplier, global_position, direction)
		if pierce > 0 and target.has_method("take_hit"):
			pierce -= 1
			_passed.append(hit.rid)
		else:
			queue_free()
	global_position = next
