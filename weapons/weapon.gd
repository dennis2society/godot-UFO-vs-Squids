extends Node3D
## The ship's three weapons. Left mouse auto-fires the laser, right mouse launches
## missiles, with the wheel choosing among the unlocked types, and middle mouse charges
## a plasma ball, fired on release.
## Pressing it again while the ball flies detonates it.
## Every upgrade comes from the skill tree, and shows as hardware on the hull.

signal missile_switched(type: Dictionary)
signal plasma_not_ready(seconds: float)

## Laser bolts per shot at each spread skill rank. Always odd, so one bolt flies dead centre.
const SPREAD_GRIDS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(3, 3), Vector2i(5, 3), Vector2i(5, 5),
]
const WEAPON_COLORS := {
	"laser": Color(1.0, 0.55, 0.1),
	"plasma": Color(1.0, 0.15, 0.15),
	"missile": Color(0.2, 0.55, 1.0),
}
## Scales are relative to a standard missile, and skill names the unlocking skill. All
## types share one reload, so switching can't dodge a swarm's long cooldown.
const MISSILE_TYPES: Array[Dictionary] = [
	{"name": "Standard", "count": 1, "cooldown": 1.0, "damage": 1.0, "radius": 1.0, "homing": false, "fan": 0.0},
	{"name": "Homing", "count": 1, "cooldown": 1.5, "damage": 0.8, "radius": 0.7, "homing": true, "fan": 0.0, "skill": "homing_missile"},
	{"name": "Swarm", "count": 6, "cooldown": 3.5, "damage": 0.4, "radius": 0.55, "homing": true, "fan": 0.4, "skill": "swarm_missile"},
]
@export var ship: CharacterBody3D
@export var bolt_scene: PackedScene
@export var rocket_scene: PackedScene

@export_group("Laser")
@export var base_fire_interval := 0.15
@export var fire_interval_scale := 0.84 ## Multiplied in per rank.
@export var base_range := 80.0
@export var base_damage := 1.0
@export var base_crit_multiplier := 2.0
@export var spread_angle := 0.03 ## Radians between neighbouring bolts.
@export var spread_damage_falloff := 0.5 ## Bolt damage is divided by count to this power.

@export_group("Plasma")
@export var plasma_scene: PackedScene
@export var plasma_interval := 12.0 ## Cooldown from launch to the next charge.
@export var min_charge := 0.2 ## Releasing below this cancels without cooldown.
@export var charge_delay := 0.15 ## Holding this long before charge starts to build.
@export var charge_time := 2.0 ## From press to full charge, before skills.
@export var charge_time_scale := 0.84 ## Multiplied in per rank.
@export var plasma_damage := 150.0
@export var weak_charge_share := 0.4 ## Damage and size of a barely charged ball.
@export var blast_radius := 28.0 ## At full charge. Above a maxed missile's blast.

@export_group("Missile")
@export var rocket_interval := 4.0
@export var rocket_damage := 70.0 ## Stays above the toughest squid's health.
@export var rocket_radius := 9.0
@export var rocket_radius_per_rank := 3.0 ## Stays under a full plasma blast.

@export_group("Synergies")
@export var bullet_storm_interval_scale := 0.8 ## Laser interval with Bullet Storm.
@export var marksman_crit := 1.0 ## Added to the crit multiplier.
@export var overload_cooldown_scale := 0.75
@export var cluster_extra_missiles := 2
@export var nova_scene: PackedScene
@export var nova_damage := 80.0
@export var nova_radius := 22.0

@export_group("Aiming")
@export var muzzle_offset := 1.5 ## Clears the hull when a shot spawns.
@export var aim_range := 500.0

var missile_type := 0 ## Index into MISSILE_TYPES.
var autopilot := false ## The demo fires whether or not the mouse is captured.

var _bolt_material: StandardMaterial3D
var _cooldown := 0.0
var _plasma_cooldown := 0.0
var _rocket_cooldown := 0.0
var _rocket_reload := 1.0 ## Full length of the running reload.
var _charging := false
var _held_time := 0.0
var _announced_full := false
var _ball: Node3D

@onready var charge_orb: MeshInstance3D = $"../ChargeOrb"


func _ready() -> void:
	_bolt_material = StandardMaterial3D.new()
	_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Progress.skills_changed.connect(_refresh_visuals)
	_refresh_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("next_missile"):
		switch_missile(1)
	elif event.is_action_pressed("previous_missile"):
		switch_missile(-1)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_plasma_cooldown -= delta
	_rocket_cooldown -= delta
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not autopilot:
		return
	if Input.is_action_pressed("fire") and _cooldown <= 0.0:
		_cooldown = fire_interval()
		_fire_laser()
	_update_charge(delta)
	if Input.is_action_pressed("fire_rocket") and _rocket_cooldown <= 0.0:
		_rocket_reload = rocket_cooldown()
		_rocket_cooldown = _rocket_reload
		_fire_rocket()


## How far the current plasma shot has charged, from 0 to 1.
func charge() -> float:
	var full := charge_time * pow(charge_time_scale, Progress.rank("plasma_charge"))
	return clampf((_held_time - charge_delay) / (full - charge_delay), 0.0, 1.0)


## How far the plasma cooldown has run, from 0 to 1.
func plasma_ready() -> float:
	return 1.0 - clampf(_plasma_cooldown / plasma_cooldown(), 0.0, 1.0)


func is_charging() -> bool:
	return _charging


## How far the next missile has reloaded, from 0 to 1.
func rocket_ready() -> float:
	return 1.0 - clampf(_rocket_cooldown / _rocket_reload, 0.0, 1.0)


func fire_interval() -> float:
	var interval := base_fire_interval * pow(fire_interval_scale, Progress.rank("fire_rate"))
	return interval * (bullet_storm_interval_scale if Progress.has_synergy("bullet_storm") else 1.0)


func plasma_cooldown() -> float:
	var cooldown := plasma_interval * (1.0 - Progress.value("reload"))
	return cooldown * (overload_cooldown_scale if Progress.has_synergy("overload") else 1.0)


func rocket_cooldown() -> float:
	return rocket_interval * MISSILE_TYPES[missile_type].cooldown * (1.0 - Progress.value("reload"))


func missile_unlocked(type: int) -> bool:
	var skill: String = MISSILE_TYPES[type].get("skill", "")
	return skill == "" or Progress.rank(skill) > 0


## Moves to the next unlocked type that way round. Stays put with only one unlocked.
func switch_missile(step: int) -> void:
	var next := missile_type
	for i in MISSILE_TYPES.size():
		next = posmod(next + step, MISSILE_TYPES.size())
		if missile_unlocked(next):
			break
	if next != missile_type:
		missile_type = next
		missile_switched.emit(MISSILE_TYPES[missile_type])


## The Shock Nova synergy: a blast around the ship.
func shock_nova() -> void:
	var nova := nova_scene.instantiate()
	nova.position = ship.global_position
	nova.radius = nova_radius
	nova.damage = nova_damage * _damage_scale()
	# Deferred because the ship can be hit during a physics callback.
	ship.get_parent().add_child.call_deferred(nova)


func _damage_scale() -> float:
	return 1.0 + Progress.value("power")


func _update_charge(delta: float) -> void:
	var held := Input.is_action_pressed("fire_plasma")
	if Input.is_action_just_pressed("fire_plasma") and is_instance_valid(_ball):
		_ball.detonate()
	elif held and _plasma_cooldown <= 0.0:
		_charging = true
	elif Input.is_action_just_pressed("fire_plasma"):
		plasma_not_ready.emit(_plasma_cooldown)
	if not _charging:
		return

	if held:
		_held_time += delta
		if charge() >= 1.0 and not _announced_full:
			_announced_full = true
			ship.charged_sound.play()
	else:
		if charge() >= min_charge:
			_plasma_cooldown = plasma_cooldown()
			_fire_plasma(charge())
		_charging = false
		_held_time = 0.0
		_announced_full = false

	charge_orb.visible = charge() > 0.0
	charge_orb.scale = Vector3.ONE * lerpf(0.5, 3.0, charge())


## A grid of bolts from the spread skill, centred on the crosshair. More bolts each
## do less damage, so spread covers an area instead of multiplying damage outright.
func _fire_laser() -> void:
	var grid: Vector2i = SPREAD_GRIDS[Progress.rank("spread")]
	var aim_point := _aim_point()
	var damage: float = (base_damage + Progress.value("laser_damage")) * _damage_scale()
	damage /= pow(grid.x * grid.y, spread_damage_falloff - Progress.value("focus"))
	var slimming := pow(grid.x * grid.y, 0.35) # Keeps a dense grid readable as separate bolts.
	var crit := base_crit_multiplier + Progress.value("crit")
	crit += marksman_crit if Progress.has_synergy("marksman") else 0.0
	for row in grid.y:
		for column in grid.x:
			var bolt := bolt_scene.instantiate()
			bolt.damage = damage
			bolt.crit_multiplier = crit
			bolt.max_range = base_range + Progress.value("laser_range")
			bolt.pierce = Progress.rank("pierce")
			bolt.width = (1.0 + 0.25 * Progress.rank("laser_damage")) / slimming
			bolt.length = (1.0 + 0.2 * Progress.rank("laser_range")) / slimming
			bolt.material = _bolt_material
			var fan := Vector2(column - (grid.x - 1) * 0.5, row - (grid.y - 1) * 0.5)
			_launch(bolt, aim_point, fan * spread_angle)
	ship.fire_sound.pitch_scale = randf_range(0.95, 1.05)
	ship.fire_sound.play()


func _fire_plasma(amount: float) -> void:
	var ball := plasma_scene.instantiate()
	var strength := lerpf(weak_charge_share, 1.0, amount)
	var damage: float = plasma_damage + Progress.value("plasma_damage")
	var radius: float = blast_radius + Progress.value("plasma_blast")
	ball.damage = damage * strength * _damage_scale()
	ball.radius = radius * strength
	ball.size = lerpf(1.2, 3.2, amount)
	_launch(ball, _aim_point())
	_ball = ball
	ship.rocket_sound.pitch_scale = 0.5
	ship.rocket_sound.play()


func _fire_rocket() -> void:
	var type: Dictionary = MISSILE_TYPES[missile_type]
	var damage: float = (rocket_damage + Progress.value("warheads")) * _damage_scale()
	var radius: float = rocket_radius + rocket_radius_per_rank * Progress.rank("warheads")
	var aim_point := _aim_point()
	var count: int = type.count
	if missile_type == MISSILE_TYPES.size() - 1 and Progress.has_synergy("cluster"):
		count += cluster_extra_missiles
	for i in count:
		var rocket := rocket_scene.instantiate()
		rocket.damage = damage * type.damage
		rocket.radius = radius * type.radius
		rocket.homing = type.homing
		var fan: float = type.fan
		_launch(rocket, aim_point, Vector2(randf_range(-fan, fan), randf_range(-fan, fan)))
	ship.rocket_sound.pitch_scale = 1.0
	ship.rocket_sound.play()


## What sits under the crosshair, at the screen centre.
func _aim_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var aim_point := camera.global_position - camera.global_basis.z * aim_range
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, aim_point)
	query.collide_with_areas = true
	query.exclude = [ship.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else aim_point


## Sends a shot at the aim point, swung sideways and up by a fan angle in radians.
func _launch(shot: Node3D, aim_point: Vector3, fan := Vector2.ZERO) -> void:
	var from := ship.global_position
	var muzzle := from + from.direction_to(aim_point) * muzzle_offset
	var view := get_viewport().get_camera_3d().global_basis
	shot.position = muzzle
	shot.direction = muzzle.direction_to(aim_point).rotated(view.y, fan.x).rotated(view.x, fan.y)
	shot.shooter = ship
	ship.get_parent().add_child(shot)


## Laser damage shifts the bolt from red towards orange. Fire rate adds glowing pods
## around the rim, missiles add launcher tubes under the hull.
func _refresh_visuals() -> void:
	var heat: float = Progress.rank("laser_damage") / float(Progress.SKILLS["laser_damage"].max)
	_bolt_material.albedo_color = Color(1.0, 0.1, 0.05).lerp(Color(1.0, 0.45, 0.1), heat)

	for child in get_children():
		child.queue_free()
	var pods := Progress.rank("fire_rate")
	for i in pods:
		var angle: float = TAU * i / Progress.SKILLS["fire_rate"].max
		_add_part(_pod_mesh(), Vector3(cos(angle), 0.02, sin(angle)) * 1.0)
	var tubes: int = Progress.rank("warheads") + 1
	for i in tubes:
		var offset: float = (i - (tubes - 1) * 0.5) * 0.18
		_add_part(_tube_mesh(), Vector3(offset, -0.42 + offset * offset * 0.3, 0.0), Vector3(-PI / 2.0, 0.0, 0.0))


func _add_part(mesh: Mesh, at: Vector3, angles := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.rotation = angles
	add_child(part)


func _pod_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = WEAPON_COLORS["laser"]
	mesh.material = material
	return mesh


func _tube_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.08
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.25, 0.3)
	material.metallic = 0.6
	material.roughness = 0.4
	mesh.material = material
	return mesh
