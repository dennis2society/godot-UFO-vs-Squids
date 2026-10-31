extends StaticBody3D
## The boss arena's cover: walls and roofs of stacked stone blocks, drawn as one
## MultiMesh with a single solid box per segment. Every gap runs through, so no corner
## traps the ship.

const BLOCK := Vector3(4.0, 2.0, 3.0) ## Length, height, depth.
const STONE := Color(0.5, 0.48, 0.45)
const BRICK := Color(0.55, 0.28, 0.2)
const MORTAR := Color(0.1, 0.09, 0.09)

@export var block_inset := 0.08 ## How far the mortar core sits behind the blocks.
@export var tint_variation := 0.12
@export var wall_height := 24.0
@export var roof_height := 14.0

var cover_spots: Array[Vector3] = [ ## Safe places for supply drops.
	Vector3(0.0, 4.0, 0.0), Vector3(29.5, 4.0, 0.0), Vector3(-29.5, 4.0, 0.0),
]

var _transforms: Array[Transform3D] = []
var _colors := PackedColorArray()

@onready var blocks: MultiMeshInstance3D = $Blocks


func _ready() -> void:
	for sign_x: float in [-1.0, 1.0]:
		_add_hall(sign_x)
		_add_wall(Vector3(sign_x * 62.0, -2.0, -30.0), Vector3(sign_x * 65.0, wall_height, -6.0), BRICK)
		_add_wall(Vector3(sign_x * 62.0, -2.0, 6.0), Vector3(sign_x * 65.0, wall_height, 30.0), BRICK)
		for sign_z: float in [-1.0, 1.0]:
			_add_pillar(sign_x * 11.0, sign_z * 11.0)
			_add_wall(Vector3(sign_x * 6.0, -2.0, sign_z * 53.5 - 1.5),
					Vector3(sign_x * 40.0, wall_height, sign_z * 53.5 + 1.5), STONE)
	_add_wall(Vector3(-16.0, roof_height, -16.0), Vector3(16.0, roof_height + 2.0, 16.0), BRICK)
	_add_wall(Vector3(-14.0, -2.0, -33.0), Vector3(14.0, 12.0, -30.0), STONE)
	_add_wall(Vector3(-14.0, -2.0, 30.0), Vector3(14.0, 12.0, 33.0), STONE)
	_build_multimesh()


## A long corridor open at both ends, with a doorway through each side.
func _add_hall(sign_x: float) -> void:
	for sign_z: float in [-1.0, 1.0]:
		for wall_x: float in [23.5, 35.5]:
			_add_wall(Vector3(sign_x * wall_x - 1.5, -2.0, sign_z * 5.0),
					Vector3(sign_x * wall_x + 1.5, roof_height, sign_z * 36.0), STONE)
	_add_wall(Vector3(sign_x * 22.0, roof_height, -36.0),
			Vector3(sign_x * 37.0, roof_height + 2.0, 36.0), STONE)


func _add_pillar(x: float, z: float) -> void:
	_add_wall(Vector3(x - 3.0, -2.0, z - 3.0), Vector3(x + 3.0, roof_height, z + 3.0), BRICK)


## Fills a box with courses of blocks, each row offset half a block from the last.
func _add_wall(corner_a: Vector3, corner_b: Vector3, tint: Color) -> void:
	var from := corner_a.min(corner_b) # Mirrored walls pass their corners either way round.
	var to := corner_a.max(corner_b)
	var size := to - from
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var depth := size.z if along_x else size.x
	var courses := maxi(roundi(depth / BLOCK.z), 1)
	var rows := maxi(roundi(size.y / BLOCK.y), 1)

	for row in rows:
		var start := -BLOCK.x * 0.5 * (row % 2)
		var step := int(ceil((length - start) / BLOCK.x))
		for course in courses:
			for i in step:
				var a := maxf(start + BLOCK.x * i, 0.0)
				var b := minf(start + BLOCK.x * (i + 1), length)
				var d := depth / courses
				var local_center := Vector3((a + b) * 0.5, (row + 0.5) * size.y / rows, (course + 0.5) * d)
				var local_size := Vector3(b - a - block_inset, size.y / rows - block_inset, d - block_inset)
				_add_block(from, along_x, local_center, local_size, _varied(tint))
	_add_block(from, along_x, Vector3(length * 0.5, size.y * 0.5, depth * 0.5),
			Vector3(length, size.y, depth) - Vector3.ONE * block_inset * 2.0, MORTAR)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = (from + to) * 0.5
	add_child(collision)


func _add_block(origin: Vector3, along_x: bool, center: Vector3, size: Vector3, color: Color) -> void:
	var at := Vector3(center.x, center.y, center.z) if along_x else Vector3(center.z, center.y, center.x)
	var scale_by := size if along_x else Vector3(size.z, size.y, size.x)
	_transforms.append(Transform3D(Basis.from_scale(scale_by), origin + at))
	_colors.append(color)


func _varied(tint: Color) -> Color:
	return tint * randf_range(1.0 - tint_variation, 1.0 + tint_variation)


func _build_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = _transforms.size()
	for i in _transforms.size():
		multimesh.set_instance_transform(i, _transforms[i])
		multimesh.set_instance_color(i, Color(_colors[i], 1.0))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	multimesh.mesh.material = material
	blocks.multimesh = multimesh
