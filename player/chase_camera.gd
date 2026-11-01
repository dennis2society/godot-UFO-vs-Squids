extends Camera3D
## Sits behind the target, looks along its view direction and keeps a clear line to it.

@export var target: PhysicsBody3D
@export var distance := 7.0
@export var height := 1.2
@export var ground_clearance := 0.5

@onready var outline: MeshInstance3D = $Outline


func _ready() -> void:
	Settings.outlines_changed.connect(outline.set_visible)
	outline.visible = Settings.outlines
	global_basis = target.look_basis()
	global_position = _desired_position()


func _physics_process(_delta: float) -> void:
	global_basis = target.look_basis()
	var desired := _desired_position()

	# Anything between the ship and the camera pulls it in, so it stays under roofs.
	var arm := PhysicsRayQueryParameters3D.create(target.global_position, desired)
	arm.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(arm)
	if hit:
		desired = hit.position + hit.normal * ground_clearance

	var ground_ray := PhysicsRayQueryParameters3D.create(
		desired + Vector3.UP * ground_clearance, desired + Vector3.DOWN * ground_clearance
	)
	ground_ray.exclude = [target.get_rid()]
	hit = get_world_3d().direct_space_state.intersect_ray(ground_ray)
	if hit:
		desired.y = hit.position.y + ground_clearance
	global_position = desired


func _desired_position() -> Vector3:
	return target.global_position + global_basis * Vector3(0.0, height, distance)
