extends Node3D


func _ready() -> void:
	_build_environment()

	var terrain := Terrain.new()
	add_child(terrain)

	var ufo := Ufo.new()
	ufo.terrain = terrain
	ufo.position = Vector3(0.0, terrain.height_at(0.0, 0.0) + 15.0, 0.0)
	add_child(ufo)


func _build_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
