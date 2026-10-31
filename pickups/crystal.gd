extends Area3D
## A crystal thrown out of a dead enemy. It flies in an arc, can be caught in the air,
## and otherwise lies on the ground for a while. Close by, it drifts to the ship.

@export var gravity_pull := 16.0
@export var launch_speed := Vector2(7.0, 13.0) ## Upwards, m/s.
@export var scatter_speed := 7.0 ## Sideways, m/s.
@export var rest_height := 0.9 ## Above the ground, once landed.
@export var lifetime := 45.0 ## Seconds on the ground.
@export var fade_time := 6.0 ## Blinks for this long before it goes.
@export var spin_speed := 2.5
@export var attract_range := 7.0
@export var attract_speed := 26.0

var terrain: Node3D

var _velocity := Vector3.ZERO
var _landed := false
var _left := 0.0

@onready var gem: MeshInstance3D = $Gem


func _ready() -> void:
	add_to_group("crystals")
	_left = lifetime
	var side := Vector2.from_angle(randf() * TAU) * randf_range(0.2, 1.0) * scatter_speed
	_velocity = Vector3(side.x, randf_range(launch_speed.x, launch_speed.y), side.y)


func _physics_process(delta: float) -> void:
	gem.rotate_y(spin_speed * delta)
	gem.rotate_x(spin_speed * 0.6 * delta)
	if _landed:
		_left -= delta
		if _left <= 0.0:
			queue_free()
			return
		gem.visible = _left > fade_time or fmod(_left, 0.4) > 0.15
	else:
		_fall(delta)
	for other in get_overlapping_bodies():
		if other.has_method("heal"):
			Progress.add_crystals(1)
			other.pickup_sound.play()
			queue_free()
			return
	_drift_to_ship(delta)


func _fall(delta: float) -> void:
	_velocity.y -= gravity_pull * delta
	position += _velocity * delta
	var ground: float = terrain.height_at(position.x, position.z) + rest_height
	if position.y <= ground and _velocity.y < 0.0:
		position.y = ground
		_landed = true


func _drift_to_ship(delta: float) -> void:
	var ship := get_tree().get_first_node_in_group("player") as Node3D
	if ship != null and global_position.distance_to(ship.global_position) < attract_range:
		global_position = global_position.move_toward(ship.global_position, attract_speed * delta)
		_landed = false
		_velocity = Vector3.ZERO
