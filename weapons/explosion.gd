extends Node3D
## Damages every squid in its radius, then plays a flash, a shockwave that shows that
## radius, a billowing fireball, sparks and lingering smoke.

@export var flash_time := 0.15
@export var shockwave_time := 0.45
@export var lifetime := 2.4

var radius := 9.0
var damage := 50.0

@onready var flash: MeshInstance3D = $Flash
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var light: OmniLight3D = $Light
@onready var fire: CPUParticles3D = $Fire
@onready var smoke: CPUParticles3D = $Smoke
@onready var sparks: CPUParticles3D = $Sparks
@onready var sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	_deal_damage()

	_scale_burst(fire, 0.25, Vector2(0.3, 1.5), Vector2(0.5, 0.9))
	_scale_burst(smoke, 0.4, Vector2(0.2, 0.8), Vector2(0.6, 1.0))
	_scale_burst(sparks, 0.1, Vector2(1.5, 3.5), Vector2(0.015, 0.035))

	var flash_material: StandardMaterial3D = flash.get_active_material(0).duplicate()
	var wave_material: StandardMaterial3D = shockwave.get_active_material(0).duplicate()
	flash.material_override = flash_material
	shockwave.material_override = wave_material
	flash.scale = Vector3.ONE * radius * 1.3
	shockwave.scale = Vector3.ONE * radius * 0.1
	light.omni_range = radius * 3.0
	sound.unit_size = minf(radius * 6.0, 80.0) # Small blasts sound smaller.

	var tween := create_tween().set_parallel()
	tween.tween_property(flash_material, "albedo_color:a", 0.0, flash_time)
	tween.tween_property(shockwave, "scale", Vector3.ONE * radius, shockwave_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave_material, "albedo_color:a", 0.0, shockwave_time)
	tween.tween_property(light, "light_energy", 0.0, 0.5)
	await get_tree().create_timer(lifetime).timeout
	queue_free()


## Sizes a particle burst to the blast. Spread is relative to the radius, as are the
## speed range and particle size range.
func _scale_burst(burst: CPUParticles3D, spread: float, speed: Vector2, size: Vector2) -> void:
	burst.emission_sphere_radius = radius * spread
	burst.initial_velocity_min = radius * speed.x
	burst.initial_velocity_max = radius * speed.y
	burst.scale_amount_min = radius * size.x
	burst.scale_amount_max = radius * size.y
	burst.emitting = true


## Damage is the same across the blast, so a rocket kills anything it reaches.
func _deal_damage() -> void:
	if damage <= 0.0:
		return
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 128):
		if result.collider.has_method("apply_damage"):
			result.collider.apply_damage(damage)
