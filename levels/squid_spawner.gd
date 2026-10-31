extends Node3D
## Runs the squid level: keeps squids coming, hands out drops, raises the threat as the
## ship grows and time passes, and awards medals for surviving. Gold ends the mission.

@export var squid_scene: PackedScene
@export var zombie_scene: PackedScene ## Leave empty for squids only.
@export_range(0.0, 1.0) var zombie_share := 0.5
@export var blinker_scene: PackedScene ## Leave empty for no teleporting rares.
@export var health_pack_scene: PackedScene
@export var skill_point_scene: PackedScene
@export var crystal_scene: PackedScene
@export var shield_scene: PackedScene
@export var terrain: Node3D
@export var player: Node3D
@export var hud: CanvasLayer
@export var menu: CanvasLayer
@export var mission_name := "Mission 2"
@export_file("*.tscn") var next_level := "" ## Offered once a medal is earned.
@export var final_mission := false ## Gold here wins the game.
@export var spawn_range := 110.0
@export var min_hover := 6.0
@export var max_hover := 50.0
@export var player_clearance := 40.0 ## Never spawn this close to the player.
@export var respawn_reach := 95.0 ## Replacements arrive within this of the player.

@export_group("Medals")
@export var bronze_time := 300.0 ## Seconds survived.
@export var silver_time := 480.0
@export var gold_time := 600.0

@export_group("Rare targets")
@export var rare_interval_min := 25.0 ## Seconds from the last rare's death to the next.
@export var rare_interval_max := 40.0 ## Only one rare target exists at a time.

@export_group("Bonus target")
@export var bonus_health := 600.0
@export var bonus_health_per_threat := 15.0
@export var bonus_size_extra := 0.8
@export var bonus_speed_factor := 1.5 ## Compared with a normal squid at this threat.
@export var bonus_contact_damage := 5.0

@export_group("Blinker")
@export var blinker_health := 450.0
@export var blinker_health_per_threat := 15.0
@export var blinker_size := 2.4

@export_group("Drops")
@export_range(0.0, 1.0) var drop_chance := 0.1 ## Health pack chance per kill.
@export_range(0.0, 1.0) var shield_drop_chance := 0.06 ## Per kill, once a rank is bought.

@export_range(0.0, 1.0) var crystal_chance := 0.2 ## Per kill.
@export var rare_crystals := 6 ## Burst from a rare target.
@export var max_crystals := 50 ## On the map at once, so a long run stays smooth.

@export_group("Squid fire")
@export var squids_shoot := false ## Off for early levels, where contact is the only danger.
@export var shoot_threat := 15 ## Squids spawned from this threat on shoot back.
@export var shot_interval := 14.0
@export var shot_interval_per_threat := -0.12
@export var min_shot_interval := 6.0
@export var shot_damage := 6.0
@export var shot_damage_per_threat := 0.1

@export_group("Threat scaling")
@export var base_threat := 0 ## Later levels start out harder.
@export var wave_length := 80.0 ## Seconds. Each wave is a calm stretch, then a surge.
@export_range(0.0, 1.0) var wave_calm := 0.6 ## Share of a wave where threat holds still.
@export var wave_threat := 2 ## Threat added by each wave's surge.
@export var calm_respawn_scale := 2.5 ## Replacements come this much slower when calm.
@export var count := 55
@export var count_per_threat := 1
@export var max_count := 120
@export var respawn_delay := 0.7
@export var respawn_delay_per_threat := -0.02
@export var min_respawn_delay := 0.35
@export var health := 6.0
@export var health_per_threat := 0.75 ## Keeps a basic missile a one-shot kill.
@export var size := 1.6
@export var size_per_threat := 0.02
@export var aggro_range := 90.0 ## Squids further away than this drift instead of hunting.
@export var chase_speed := 6.5
@export var chase_speed_per_threat := 0.14
@export var contact_damage := 22.0
@export var contact_damage_per_threat := 0.3

var kills := 0
var survived := 0.0

var _alive := 0
var _spawn_timer := 0.0
var _bonus: Node3D
var _rare_timer := 0.0
var _blinker: Node3D
var _queued_drops: Array[Node3D] = []
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	player.destroyed.connect(_on_player_destroyed)
	_reset_rare_timer()
	for i in _target_count():
		_alive += 1
		_add_squid().died.connect(_on_squid_died)
	_update_objective()
	hud.set_hint("Left: laser  ·  Right: missile  ·  Middle (hold): plasma ball, press again to detonate  ·  Wheel: missile type  ·  T: skill tree")


func _process(delta: float) -> void:
	var medal_before := _medal()
	survived += delta
	if _medal() > medal_before:
		_on_medal_reached(_medal())
	_update_objective()

	_spawn_timer -= delta
	if _alive < _target_count() and _spawn_timer <= 0.0:
		_spawn_timer = maxf(respawn_delay + respawn_delay_per_threat * threat(), min_respawn_delay)
		_spawn_timer *= calm_respawn_scale if _wave_progress() < wave_calm else 1.0
		_alive += 1
		_add_squid(false, true).died.connect(_on_squid_died)

	if _bonus == null and _blinker == null:
		_rare_timer -= delta
		if _rare_timer <= 0.0:
			if blinker_scene != null and randf() < 0.5:
				_spawn_blinker()
			else:
				_spawn_bonus()
	_mark_nearest_rare()


## The level's own threat, plus the ship's skill ranks and time survived.
func threat() -> int:
	return base_threat + Progress.threat() + _wave_threat()


## Holds through the calm part of each wave, then climbs through the surge.
func _wave_threat() -> int:
	var waves := floorf(survived / wave_length)
	var surge := maxf((_wave_progress() - wave_calm) / (1.0 - wave_calm), 0.0)
	return floori((waves + surge) * wave_threat)


## How far through the current wave the mission is, from 0 to 1.
func _wave_progress() -> float:
	return fmod(survived, wave_length) / wave_length


func _target_count() -> int:
	return mini(count + count_per_threat * threat(), max_count)


## Near_player closes the ring around the ship, so running away doesn't escape the swarm.
func _add_squid(bonus := false, near_player := false) -> Node3D:
	var x := randf_range(-spawn_range, spawn_range)
	var z := randf_range(-spawn_range, spawn_range)
	while Vector2(x - player.position.x, z - player.position.z).length() < player_clearance:
		x = randf_range(-spawn_range, spawn_range)
		z = randf_range(-spawn_range, spawn_range)
	if near_player:
		var angle := randf() * TAU
		var reach := randf_range(player_clearance, respawn_reach)
		x = clampf(player.position.x + cos(angle) * reach, -spawn_range, spawn_range)
		z = clampf(player.position.z + sin(angle) * reach, -spawn_range, spawn_range)

	var speed := chase_speed + chase_speed_per_threat * threat()
	var scene := squid_scene
	if zombie_scene != null and not bonus and randf() < zombie_share:
		scene = zombie_scene
	var squid := scene.instantiate()
	squid.position = Vector3(x, terrain.height_at(x, z) + randf_range(min_hover, max_hover), z)
	squid.player = player
	squid.terrain = terrain
	squid.bonus = bonus
	squid.aggro_range = aggro_range
	squid.size = size + size_per_threat * threat() + (bonus_size_extra if bonus else 0.0)
	if bonus:
		squid.max_health = bonus_health + bonus_health_per_threat * threat()
		squid.chase_speed = speed * bonus_speed_factor
		squid.contact_damage = bonus_contact_damage
	else:
		squid.max_health = health + health_per_threat * threat()
		squid.chase_speed = speed
		squid.contact_damage = contact_damage + contact_damage_per_threat * threat()
		if squids_shoot and threat() >= shoot_threat:
			squid.shot_interval = maxf(shot_interval + shot_interval_per_threat * threat(), min_shot_interval)
			squid.shot_damage = shot_damage + shot_damage_per_threat * threat()
	add_child(squid)
	return squid


func _reset_rare_timer() -> void:
	_rare_timer = randf_range(rare_interval_min, rare_interval_max)


func _spawn_bonus() -> void:
	_bonus = _add_squid(true)
	_bonus.died.connect(_on_bonus_died)
	hud.show_toast("Bonus target spotted!", Color(1.0, 0.8, 0.2))


func _spawn_blinker() -> void:
	_blinker = blinker_scene.instantiate()
	_blinker.player = player
	_blinker.terrain = terrain
	_blinker.spawn_range = spawn_range
	_blinker.bonus = true
	_blinker.size = blinker_size
	_blinker.max_health = blinker_health + blinker_health_per_threat * threat()
	_blinker.contact_damage = bonus_contact_damage
	_blinker.position = _blinker.spot_near_player()
	_blinker.died.connect(_on_blinker_died)
	_blinker.missile_fired.connect(_on_blinker_missile)
	add_child(_blinker)
	hud.show_toast("Blinker spotted!", Color(0.3, 1.0, 0.9))


## The marker follows whichever rare target is closest.
func _mark_nearest_rare() -> void:
	var nearest: Node3D = null
	for rare: Node3D in [_bonus, _blinker]:
		if rare == null:
			continue
		if nearest == null or player.global_position.distance_to(rare.global_position) \
				< player.global_position.distance_to(nearest.global_position):
			nearest = rare
	if nearest == null:
		hud.set_waypoint(null)
	else:
		hud.set_waypoint(nearest.global_position, nearest.rare_label)


func _on_bonus_died(at: Vector3) -> void:
	_bonus = null
	_reset_rare_timer()
	hud.show_toast("Bonus target destroyed!", Color(1.0, 0.8, 0.2))
	_drop(health_pack_scene.instantiate(), at + Vector3.BACK * 5.0)
	_reward_rare_kill(at)


func _on_blinker_died(at: Vector3) -> void:
	_blinker = null
	_reset_rare_timer()
	hud.show_toast("Blinker destroyed!", Color(0.3, 1.0, 0.9))
	_reward_rare_kill(at)


func _on_blinker_missile() -> void:
	hud.show_toast("Homing missile! Boost or shoot it down", Color(1.0, 0.3, 0.2))


func _reward_rare_kill(at: Vector3) -> void:
	kills += 1
	_update_objective()
	_drop(skill_point_scene.instantiate(), at)
	_drop_crystals(at, rare_crystals)


func _on_squid_died(at: Vector3) -> void:
	_alive -= 1
	kills += 1
	_update_objective()

	if randf() < crystal_chance:
		_drop_crystals(at, 1)
	if _shield_gem_due():
		_drop(shield_scene.instantiate(), at)
	elif randf() < drop_chance:
		_drop(health_pack_scene.instantiate(), at)


## Shield gems need a rank in the skill, room to fill, and none already waiting.
func _shield_gem_due() -> bool:
	if Progress.rank("shield") == 0 or player.shield >= player.max_shield:
		return false
	for child in get_children() + _queued_drops:
		if child.has_method("is_shield_pickup"):
			return false
	return randf() < shield_drop_chance + Progress.value("beacon")


func _drop_crystals(at: Vector3, amount: int) -> void:
	for i in amount:
		if get_tree().get_node_count_in_group("crystals") + _queued_drops.size() >= max_crystals:
			return
		var crystal := crystal_scene.instantiate()
		crystal.terrain = terrain
		_drop(crystal, at)


func _drop(pickup: Node3D, at: Vector3) -> void:
	pickup.position = at
	# Deferred because squids can die during a physics callback.
	_queued_drops.append(pickup)
	_add_queued_drop.call_deferred(pickup)


func _add_queued_drop(pickup: Node3D) -> void:
	_queued_drops.erase(pickup)
	add_child(pickup)


## Medals come in order during a run, so each pays as it is reached.
## Index into Rewards.MEDALS, or -1 for none yet.
func _medal() -> int:
	if survived >= gold_time:
		return 2
	if survived >= silver_time:
		return 1
	return 0 if survived >= bronze_time else -1


func _on_medal_reached(medal: int) -> void:
	var earned: Dictionary = Rewards.MEDALS[medal]
	var points := Rewards.points_text(Progress.reward_medal(mission_name, medal))
	if medal == 2:
		_finish(points)
	else:
		hud.show_toast(("%s medal earned  %s" % [earned.name, points]).strip_edges(), Color(earned.color))


func _on_player_destroyed() -> void:
	_finish()


## Records the run and ends the mission, by dying or by reaching gold.
func _finish(points := "") -> void:
	set_process(false)
	var clock := Rewards.format_clock(survived)
	var medal := _medal()
	if medal < 0:
		menu.show_result("Game Over\nSurvived %s" % clock)
		return
	var earned: Dictionary = Rewards.MEDALS[medal]
	Rewards.award(mission_name, medal, survived, true)
	if medal == 2 and final_mission:
		menu.show_win(("The squids are beaten after %s\n%s" % [clock, points]).strip_edges())
		return
	var heading := "%s Medal\nSurvived %s\n%s" % [earned.name, clock, points]
	menu.show_result(heading.strip_edges(), next_level, Color(earned.color))


func _update_objective() -> void:
	var next_medal := _medal() + 1
	var target := [bronze_time, silver_time, gold_time][mini(next_medal, 2)] as float
	hud.set_objective("Kills %d     Threat %d     Time %s     %s %s" % [
		kills, threat(), Rewards.format_clock(survived),
		Rewards.MEDALS[mini(next_medal, 2)].name, Rewards.format_clock(target),
	])
