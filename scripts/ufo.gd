class_name Ufo
extends Node3D

const MAX_SPEED := 25.0
const VERTICAL_SPEED := 12.0
const ACCEL := 4.0
const TURN_SPEED := 5.0
const CLEARANCE := 3.0
const CAM_OFFSET := Vector3(0.0, 6.0, 14.0)

var terrain: Terrain

var _velocity := Vector3.ZERO
var _camera: Camera3D


func _ready() -> void:
	_build_model()

	_camera = Camera3D.new()
	_camera.top_level = true
	add_child(_camera)
	_camera.global_position = global_position + CAM_OFFSET
	_camera.current = true


func _process(delta: float) -> void:
	_update_movement(delta)
	_update_camera(delta)


func _update_movement(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_E):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		dir.y -= 1.0
	dir = dir.normalized()

	var target := Vector3(dir.x * MAX_SPEED, dir.y * VERTICAL_SPEED, dir.z * MAX_SPEED)
	_velocity = _velocity.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
	position += _velocity * delta

	var ground := terrain.height_at(position.x, position.z) + CLEARANCE
	if position.y < ground:
		position.y = ground
		_velocity.y = maxf(_velocity.y, 0.0)

	var horizontal := Vector2(_velocity.x, _velocity.z)
	if horizontal.length() > 0.5:
		var target_yaw := atan2(-horizontal.x, -horizontal.y)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _update_camera(delta: float) -> void:
	var desired := global_position + CAM_OFFSET
	_camera.global_position = _camera.global_position.lerp(desired, clampf(5.0 * delta, 0.0, 1.0))
	_camera.look_at(global_position)


func _build_model() -> void:
	var red := _make_material(Color(0.8, 0.05, 0.05))
	var white := _make_material(Color.WHITE)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.85, 1.0, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.3
	glass.roughness = 0.05

	# Bottom saucer (red), top dome (white), transparent canopy (glass).
	_add_part(Vector3(0.0, 0.0, 0.0), Vector3(2.2, 0.35, 2.2), red)
	_add_part(Vector3(0.0, 0.3, 0.0), Vector3(1.2, 0.5, 1.2), white)
	_add_part(Vector3(0.0, 0.45, 0.0), Vector3(0.75, 0.55, 0.75), glass)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	return mat


func _add_part(pos: Vector3, scl: Vector3, mat: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = pos
	mi.scale = scl
	add_child(mi)
