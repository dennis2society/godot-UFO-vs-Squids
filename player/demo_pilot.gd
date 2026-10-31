extends Node
## Plays the game for the title screen's demo. Holds the real controls, with a limited
## turn speed, a reaction delay and a little aim wobble, so it plays by a person's rules
## and only outclasses one through good decisions.

@export var turn_speed := 5.0 ## Radians per second, like a quick wrist.
@export var aim_smoothing := 14.0
@export var reaction_time := 0.18 ## Seconds between choosing targets.
@export var aim_wobble := 0.006 ## Radians.
@export var fire_cone := 0.05 ## Radians off target it still pulls the trigger.
@export var cruise_height := 22.0 ## Above the ground.
@export var threat_radius := 26.0 ## Enemies closer than this push the ship away.
@export var hazard_radius := 55.0 ## Incoming missiles are avoided from here.
@export var fight_range := 55.0 ## Preferred distance from the target.
@export var edge_margin := 30.0
@export var cluster_radius := 16.0
@export var plasma_cluster := 4 ## Enemies in the blast worth a plasma shot.
@export var plasma_blast := 30.0 ## Metres around the target that count as in the blast.
@export var plasma_min_range := 30.0 ## The ball is slow, so it needs room to arrive.
@export var plasma_hold := 1.1 ## Seconds to charge.

var _player: Node3D
var _weapon: Node3D
var _terrain: Node3D
var _target: Node3D
var _target_at := Vector3.ZERO
var _target_motion := Vector3.ZERO
var _think := 0.0
var _wobble := Vector2.ZERO
var _charging := 0.0
var _swap := 0.0


func setup(player: Node3D, terrain: Node3D) -> void:
	_player = player
	_weapon = player.weapon
	_terrain = terrain
	_player.autopilot = true
	_weapon.autopilot = true


func _exit_tree() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "fly_up",
			"fly_down", "boost", "fire", "fire_rocket", "fire_plasma"]:
		Input.action_release(action)


func _physics_process(delta: float) -> void:
	_think -= delta
	if _think <= 0.0:
		_think = reaction_time
		_choose_target()
		_wobble = Vector2(randfn(0.0, aim_wobble), randfn(0.0, aim_wobble))
	if _target != null and not is_instance_valid(_target):
		_target = null
	_aim(delta)
	_fly()
	_shoot(delta)


## Incoming missiles first, then rare targets, then whatever is nearest.
func _choose_target() -> void:
	var best: Node3D = null
	var best_score := INF
	for shot: Node3D in get_tree().get_nodes_in_group("hazards"):
		var distance := _distance_to(shot)
		if distance < hazard_radius and distance < best_score:
			best = shot
			best_score = distance - 1000.0
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		var score := _distance_to(enemy) - (70.0 if enemy.bonus else 0.0)
		if score < best_score:
			best = enemy
			best_score = score
	if best != _target:
		_target_motion = Vector3.ZERO
	_target = best
	if best != null:
		_target_at = best.global_position


func _distance_to(node: Node3D) -> float:
	return _player.global_position.distance_to(node.global_position)


## Turns the view towards where the target will be, from the camera's point of view,
## because shots go to the crosshair.
func _aim(delta: float) -> void:
	if _target == null:
		return
	var now := _target.global_position
	_target_motion = _target_motion.lerp((now - _target_at) / delta, 0.15)
	_target_at = now
	var camera := _player.get_viewport().get_camera_3d()
	var to := now + _target_motion * _distance_to(_target) / 150.0 - camera.global_position
	var yaw := atan2(-to.x, -to.z) + _wobble.x
	var pitch := asin(clampf(to.normalized().y, -1.0, 1.0)) + _wobble.y
	var turn := wrapf(yaw - _player.rotation.y, -PI, PI)
	var most := turn_speed * delta
	var eased := 1.0 - exp(-aim_smoothing * delta)
	_player.rotation.y += clampf(turn * eased, -most, most)
	_player.pitch += clampf((clampf(pitch, -1.3, 1.3) - _player.pitch) * eased, -most, most)


func _aimed() -> bool:
	var look: Vector3 = _player.look_basis() * Vector3.FORWARD
	var camera := _player.get_viewport().get_camera_3d()
	return look.angle_to(_target.global_position - camera.global_position) < fire_cone


## Adds up everything pulling on the ship, then works the controls towards it.
func _fly() -> void:
	var at: Vector3 = _player.global_position
	var wish := Vector3.ZERO
	var crowded := 0
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		var away: Vector3 = at - enemy.global_position
		if away.length() < threat_radius:
			wish += away.normalized() * (1.0 - away.length() / threat_radius) * 2.0
			crowded += 1
	var escaping := false
	for shot: Node3D in get_tree().get_nodes_in_group("hazards"):
		var away: Vector3 = at - shot.global_position
		if away.length() < hazard_radius:
			wish += away.normalized() * 3.0
			escaping = true
	if _target != null:
		var to: Vector3 = _target.global_position - at
		wish += to.normalized() * clampf((to.length() - fight_range) / fight_range, -1.0, 1.0)
	var pickup := _wanted_pickup()
	if pickup != null:
		wish += at.direction_to(pickup.global_position) * 1.5

	var edge: float = _player.bounds - edge_margin
	wish.x -= clampf((at.x - signf(at.x) * edge) / edge_margin, 0.0, 2.0) * signf(at.x) if absf(at.x) > edge else 0.0
	wish.z -= clampf((at.z - signf(at.z) * edge) / edge_margin, 0.0, 2.0) * signf(at.z) if absf(at.z) > edge else 0.0

	var climb: float = _hold_height(at) - at.y
	var local: Vector3 = _player.look_basis().inverse() * Vector3(wish.x, 0.0, wish.z)
	_press("move_right", "move_left", local.x)
	_press("move_back", "move_forward", local.z)
	_press("fly_up", "fly_down", clampf(climb / 8.0, -1.0, 1.0))
	if escaping or crowded >= 3 or wish.length() > 1.5:
		Input.action_press("boost")
	else:
		Input.action_release("boost")


func _press(positive: String, negative: String, amount: float) -> void:
	var value := clampf(amount, -1.0, 1.0)
	if value > 0.05:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < -0.05:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


## Looks along its path, so it climbs before a ridge and not into it.
func _hold_height(at: Vector3) -> float:
	var ground: float = _terrain.height_at(at.x, at.z)
	var moving: Vector3 = _player.velocity
	for seconds: float in [0.5, 1.0, 1.5, 2.5]:
		var ahead := at + moving * seconds
		ground = maxf(ground, _terrain.height_at(ahead.x, ahead.z))
	return ground + cruise_height


func _wanted_pickup() -> Node3D:
	var best: Node3D = null
	var best_distance := 90.0
	for pickup: Node3D in get_tree().get_nodes_in_group("pickups"):
		if _can_use(pickup) and _distance_to(pickup) < best_distance:
			best = pickup
			best_distance = _distance_to(pickup)
	return best


func _can_use(pickup: Node3D) -> bool:
	return pickup._can_collect(_player) if pickup.has_method("_can_collect") else true


func _shoot(delta: float) -> void:
	var aimed := _target != null and _aimed()
	if aimed:
		Input.action_press("fire")
	else:
		Input.action_release("fire")
	if _target == null:
		Input.action_release("fire_rocket")
		return

	var near := _enemies_near(_target.global_position, cluster_radius)
	_swap -= delta
	if _swap <= 0.0:
		_swap = 1.5
		_pick_missile(near)
	if aimed and _weapon.rocket_ready() >= 1.0 and (near >= 3 or _is_rare(_target)):
		Input.action_press("fire_rocket")
	else:
		Input.action_release("fire_rocket")
	_use_plasma(delta, aimed)


## Swarm for crowds, homing for single targets, whichever the ship has unlocked.
func _pick_missile(near: int) -> void:
	var wanted := 2 if near >= 5 else 1
	var guard := 0
	while _weapon.missile_type != wanted and guard < 3:
		_weapon.switch_missile(1)
		guard += 1


## Rare targets are always worth it. Otherwise it waits for a crowd inside the blast,
## which is far wider than the cluster that justifies a missile.
func _use_plasma(delta: float, aimed: bool) -> void:
	if _charging > 0.0:
		_charging += delta
		if _charging >= plasma_hold:
			Input.action_release("fire_plasma")
			_charging = 0.0
	elif aimed and _weapon.plasma_ready() >= 1.0 and _distance_to(_target) > plasma_min_range \
			and (_is_rare(_target) or _enemies_near(_target.global_position, plasma_blast) >= plasma_cluster):
		Input.action_press("fire_plasma")
		_charging = delta


func _is_rare(node: Node3D) -> bool:
	return node.is_in_group("enemies") and node.bonus


func _enemies_near(point: Vector3, radius: float) -> int:
	var count := 0
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(point) < radius:
			count += 1
	return count
