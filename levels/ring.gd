extends Node3D
## A ring the player must fly through. Either direction counts.

@export var radius := 6.0
@export var pending_color := Color(0.55, 0.6, 0.7)
@export var active_color := Color(1.0, 0.8, 0.1)

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	set_active(false)


func set_active(active: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = active_color if active else pending_color
	material.emission_enabled = active
	material.emission = active_color
	mesh.material_override = material


## True if moving between the two world positions crossed the ring's opening.
func crossed_by(from: Vector3, to: Vector3) -> bool:
	var a := to_local(from)
	var b := to_local(to)
	if a.z * b.z > 0.0:
		return false
	var at := a.lerp(b, a.z / (a.z - b.z)) if a.z != b.z else a
	return Vector2(at.x, at.y).length() < radius
