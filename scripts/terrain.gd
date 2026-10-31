class_name Terrain
extends Node3D

const SIZE := 200
const HALF := SIZE * 0.5
const HEIGHT_SCALE := 12.0
const DARK_GRASS := Color(0.18, 0.42, 0.12)
const LIGHT_GRASS := Color(0.36, 0.62, 0.2)

var _heights := PackedFloat32Array()


func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.015
	noise.fractal_octaves = 4

	var n := SIZE + 1
	_heights.resize(n * n)
	for z in n:
		for x in n:
			_heights[z * n + x] = noise.get_noise_2d(x - HALF, z - HALF) * HEIGHT_SCALE

	add_child(_build_mesh())
	add_child(_build_collision(n))


## Bilinear ground height at a world-space XZ position.
func height_at(wx: float, wz: float) -> float:
	var n := SIZE + 1
	var gx := clampf(wx + HALF, 0.0, SIZE - 0.001)
	var gz := clampf(wz + HALF, 0.0, SIZE - 0.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var h00 := _heights[iz * n + ix]
	var h10 := _heights[iz * n + ix + 1]
	var h01 := _heights[(iz + 1) * n + ix]
	var h11 := _heights[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func _build_mesh() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for z in SIZE:
		for x in SIZE:
			_add_vertex(st, x, z)
			_add_vertex(st, x + 1, z)
			_add_vertex(st, x, z + 1)
			_add_vertex(st, x + 1, z)
			_add_vertex(st, x + 1, z + 1)
			_add_vertex(st, x, z + 1)
	st.index()
	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


func _add_vertex(st: SurfaceTool, x: int, z: int) -> void:
	var h := _heights[z * (SIZE + 1) + x]
	var t := clampf(h / HEIGHT_SCALE * 0.5 + 0.5, 0.0, 1.0)
	st.set_color(DARK_GRASS.lerp(LIGHT_GRASS, t))
	st.add_vertex(Vector3(x - HALF, h, z - HALF))


func _build_collision(n: int) -> StaticBody3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = _heights

	var col := CollisionShape3D.new()
	col.shape = shape

	var body := StaticBody3D.new()
	body.add_child(col)
	return body
