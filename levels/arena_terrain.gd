extends "res://levels/terrain.gd"
## Gentle hills around a dead flat centre, for the walls of the boss arena.

@export var flat_radius := 85.0
@export var flat_falloff := 50.0


func _generate_heights() -> PackedFloat32Array:
	var heights := super()
	var side := cells + 1
	var half := cells * 0.5
	for z in side:
		for x in side:
			var distance := Vector2(x - half, z - half).length()
			heights[x + z * side] *= smoothstep(flat_radius, flat_radius + flat_falloff, distance)
	return heights
