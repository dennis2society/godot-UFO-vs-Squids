extends StaticBody3D
## Generates random rolling lawn with mountains: a render mesh plus matching collision.

@export var cells := 256 ## Terrain edge length in metres (1 cell = 1 m).
@export var height_scale := 7.0
@export var noise_frequency := 0.012
@export var mountain_height := 70.0 ## 0 leaves only the rolling lawn.
@export var mountain_frequency := 0.011 ## How many separate massifs fit on the map.
@export var ridge_frequency := 0.02 ## How busy the peaks on each massif are.
@export var clear_radius := 40.0 ## No mountains within this distance of the start.
@export var clear_falloff := 45.0 ## Distance over which mountains rise past that.
@export var terrain_seed := 0 ## 0 picks a new random terrain on every run.
@export var snow_height := 48.0

var _heights: PackedFloat32Array

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $Collision


func _ready() -> void:
	_heights = _generate_heights()
	mesh_instance.material_override.set_shader_parameter("snow_height", snow_height)
	mesh_instance.mesh = _build_mesh(_heights)

	var shape := HeightMapShape3D.new()
	shape.map_width = cells + 1
	shape.map_depth = cells + 1
	shape.map_data = _heights
	collision_shape.shape = shape


## Ground height at a world position, to the nearest cell.
func height_at(x: float, z: float) -> float:
	var half := cells / 2
	var cell_x := clampi(roundi(x) + half, 0, cells)
	var cell_z := clampi(roundi(z) + half, 0, cells)
	return _heights[cell_x + cell_z * (cells + 1)]


func _generate_heights() -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = terrain_seed if terrain_seed != 0 else randi()
	noise.frequency = noise_frequency
	noise.fractal_octaves = 4

	var massifs := FastNoiseLite.new()
	massifs.seed = noise.seed + 1
	massifs.frequency = mountain_frequency
	massifs.fractal_octaves = 2
	var ridges := FastNoiseLite.new()
	ridges.seed = noise.seed + 2
	ridges.frequency = ridge_frequency
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 4

	var side := cells + 1
	var half := cells * 0.5
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for z in side:
		for x in side:
			var massif := smoothstep(0.08, 0.5, massifs.get_noise_2d(x, z))
			var ridge := clampf(ridges.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			var distance := Vector2(x - half, z - half).length()
			var mask := smoothstep(clear_radius, clear_radius + clear_falloff, distance)
			heights[x + z * side] = noise.get_noise_2d(x, z) * height_scale \
					+ massif * mask * (0.3 + 0.7 * ridge * ridge) * mountain_height
	return heights


func _build_mesh(heights: PackedFloat32Array) -> ArrayMesh:
	var side := cells + 1
	var half := cells * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(side * side)
	normals.resize(side * side)
	indices.resize(cells * cells * 6)

	var i := 0
	for z in side:
		for x in side:
			var left := heights[maxi(x - 1, 0) + z * side]
			var right := heights[mini(x + 1, cells) + z * side]
			var back := heights[x + maxi(z - 1, 0) * side]
			var front := heights[x + mini(z + 1, cells) * side]
			vertices[x + z * side] = Vector3(x - half, heights[x + z * side], z - half)
			normals[x + z * side] = Vector3(left - right, 2.0, back - front).normalized()

			if x < cells and z < cells:
				var a := x + z * side
				var b := a + 1
				var c := a + side
				var d := c + 1
				indices[i] = a
				indices[i + 1] = b
				indices[i + 2] = c
				indices[i + 3] = b
				indices[i + 4] = d
				indices[i + 5] = c
				i += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
