extends Area3D
## Base for hovering pickups. Hovers in place until a player it can help touches it.

@export var bob_height := 0.25
@export var bob_speed := 2.0

var _base_y: float
var _time := 0.0


func _ready() -> void:
	_base_y = position.y
	add_to_group("pickups")


func _physics_process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height

	# Polled rather than signal-driven: a player already inside can still collect
	# once it becomes eligible, such as after taking damage.
	for other in get_overlapping_bodies():
		if other.has_method("heal") and _can_collect(other):
			_collect(other)
			queue_free()
			return


func _can_collect(_player: Node3D) -> bool:
	return true


func _collect(_player: Node3D) -> void:
	pass
