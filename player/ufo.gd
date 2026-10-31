extends CharacterBody3D
## Mouse looks around, WASD thrusts relative to the view, Space/Ctrl ascend/descend,
## Shift boosts. The ship carries its momentum: thrust pushes it and drag slows it,
## with speed set so thrust and drag balance at the top speed. The Weapon node handles firing, the skill tree tunes the rest.

signal health_changed(health: float)
signal shield_changed(shield: float)
signal destroyed

@export var speed := 20.0
@export var boost_multiplier := 2.5
@export var max_health := 100.0
@export var drag_linear := 0.25 ## Per second. Sets how long a slow ship coasts.
@export var drag_quadratic := 0.0625 ## Per second, per m/s. Bites hard at high speed.
@export var tilt_rate := 5.0
@export var mouse_sensitivity := 0.0025
@export var max_pitch := 1.4 ## Radians up or down from level.
@export var tilt := 0.25 ## Visual lean in radians while moving.
@export var bounds := 124.0 ## Keeps the UFO over the terrain.
@export var max_altitude := 160.0
@export var engine_pitch_range := Vector2(0.7, 1.7) ## From hovering to full boost.
@export var engine_volume_range := Vector2(-24.0, -9.0) ## In dB, same order.

@export_group("Shield")
@export var shield_flash_fade := 4.0
@export var slipstream_cost := 0.5 ## Shield spent per damage while boosting.
@export var repair_rate := 1.5 ## Self Repair health per second.

var pitch := 0.0
var autopilot := false ## The demo flies, so the mouse doesn't steer.
var max_shield := 0.0
var shield := 0.0

var _boosting := false
var _flash := 0.0

@onready var health := max_health
@onready var base_speed := speed
@onready var base_boost := boost_multiplier
@onready var base_health := max_health

@onready var hull: Node3D = $Hull
@onready var engine_sound: AudioStreamPlayer = $EngineSound
@onready var fire_sound: AudioStreamPlayer = $FireSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var rocket_sound: AudioStreamPlayer = $RocketSound
@onready var pickup_sound: AudioStreamPlayer = $PickupSound
@onready var charged_sound: AudioStreamPlayer = $ChargedSound
@onready var weapon: Node3D = $Hull/Weapon
@onready var bubble: MeshInstance3D = $Shield


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")
	Progress.skills_changed.connect(_apply_skills)
	_apply_skills()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not autopilot:
		rotate_y(-event.screen_relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.screen_relative.y * mouse_sensitivity, -max_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var climb := Input.get_axis("fly_down", "fly_up")
	_boosting = Input.is_action_pressed("boost")
	var move_speed := speed * (boost_multiplier if _boosting else 1.0)

	var direction := look_basis() * Vector3(input.x, 0.0, input.y) + Vector3.UP * climb
	_apply_thrust_and_drag(direction.limit_length(), move_speed, delta)
	move_and_slide()
	_stop_at_map_edge()
	var blend := 1.0 - exp(-tilt_rate * delta)

	hull.rotation = hull.rotation.lerp(Vector3(input.y * tilt, 0.0, -input.x * tilt), blend)

	var throttle := velocity.length() / (speed * boost_multiplier)
	engine_sound.pitch_scale = lerpf(engine_pitch_range.x, engine_pitch_range.y, throttle)
	engine_sound.volume_db = lerpf(engine_volume_range.x, engine_volume_range.y, throttle)

	_update_shield(delta)


## Thrust is sized to balance drag exactly at top_speed, so skills keep setting top speed.
func _apply_thrust_and_drag(direction: Vector3, top_speed: float, delta: float) -> void:
	var thrust := top_speed * _drag_at(top_speed)
	velocity += direction * thrust * delta
	velocity -= velocity * minf(_drag_at(velocity.length()) * delta, 1.0)


func _drag_at(at_speed: float) -> float:
	return drag_linear + drag_quadratic * at_speed


## Hitting the edge of the map kills speed that way, so it doesn't build up unseen.
func _stop_at_map_edge() -> void:
	if absf(position.x) > bounds:
		velocity.x = 0.0
	if absf(position.z) > bounds:
		velocity.z = 0.0
	if position.y > max_altitude:
		velocity.y = 0.0
	position.x = clampf(position.x, -bounds, bounds)
	position.z = clampf(position.z, -bounds, bounds)
	position.y = minf(position.y, max_altitude)


## The shield soaks up what it can before the hull takes the rest.
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	hit_sound.play()
	var cost := slipstream_cost if _boosting and Progress.has_synergy("slipstream") else 1.0
	var absorbed := minf(amount, shield / cost)
	if absorbed > 0.0:
		shield = maxf(shield - absorbed * cost, 0.0)
		_flash = 1.0
		shield_changed.emit(shield)
		if shield <= 0.0 and Progress.has_synergy("shock_nova"):
			weapon.shock_nova()
	if amount <= absorbed:
		return
	health = maxf(health - (amount - absorbed), 0.0)
	health_changed.emit(health)
	if health <= 0.0:
		destroyed.emit()


## Shield gems are the only refill, up to what the Shield skill allows.
func restore_shield() -> void:
	shield = max_shield
	pickup_sound.play()
	shield_changed.emit(shield)


func can_heal() -> bool:
	return health > 0.0 and health < max_health


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	pickup_sound.play()
	health_changed.emit(health)


## New armor ranks top up by what they add, so a purchase pays off in the middle of a
## fight. Shield ranks only raise the capacity for the next gem.
func _apply_skills() -> void:
	speed = base_speed * (1.0 + Progress.value("thrusters"))
	boost_multiplier = base_boost + Progress.value("afterburner")
	var new_health := base_health + Progress.value("hull")
	health += new_health - max_health
	max_health = new_health
	max_shield = Progress.value("shield")
	health_changed.emit(health)
	shield_changed.emit(shield)


func _update_shield(delta: float) -> void:
	if shield > 0.0 and can_heal() and Progress.has_synergy("self_repair"):
		health = minf(health + repair_rate * delta, max_health)
		health_changed.emit(health)

	_flash = move_toward(_flash, 0.0, shield_flash_fade * delta)
	bubble.visible = shield > 0.0 or _flash > 0.0
	if bubble.visible:
		var material: ShaderMaterial = bubble.material_override
		material.set_shader_parameter("charge", shield / max_shield)
		material.set_shader_parameter("flash", _flash)


## The view orientation: the body's yaw plus the mouse pitch.
func look_basis() -> Basis:
	return global_basis * Basis(Vector3.RIGHT, pitch)

