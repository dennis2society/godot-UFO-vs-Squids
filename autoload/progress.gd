extends Node
## The campaign across levels: which level comes up, and the skill tree, the only source
## of upgrades. Saved whenever it changes, so dying or leaving a level keeps every skill
## point earned, and replaying an early level is a fair way to grind for more.

signal skills_changed
signal point_gained

const SAVE_PATH := "user://save.cfg"
const FIRST_LEVEL := "res://levels/tutorial.tscn"
const TITLE_SCREEN := "res://ui/title.tscn"
const LEVEL_NAMES := {
	"res://levels/tutorial.tscn": "Mission 1",
	"res://levels/main.tscn": "Mission 2",
	"res://levels/mountains.tscn": "Mission 3",
	"res://levels/arena.tscn": "Mission 4",
	"res://levels/swamp.tscn": "Mission 5",
}
const COST_STEP := 3 ## Every this many ranks, the next rank costs one point more.
const MEDAL_POINTS: Array[int] = [1, 2, 3] ## By index into Rewards.MEDALS.
const THREAT_TIER_RANKS := 8 ## Skill ranks in one step of the threat curve.
const THREAT_TIER_CALM := 5 ## Ranks at the start of each step that add no threat.
const THREAT_TIER_RISE := 2 ## Threat added over the rest of the step.

## A rank costs "cost" points (default 1), plus one for every COST_STEP ranks already held.
## Requires maps other skills to the rank they must reach. Per_rank is what value() adds
## up, for the scripts that apply the skill. Columns of the tree follow the listed order.
const SKILLS := {
	"laser_damage": {
		"branch": "Laser", "name": "Focus Lens", "max": 6, "per_rank": 0.5,
		"about": "+0.5 laser damage per bolt",
	},
	"fire_rate": {
		"branch": "Laser", "name": "Rapid Fire", "max": 6, "per_rank": 1.0,
		"about": "Laser fires 16% faster", "requires": {"laser_damage": 1},
	},
	"laser_range": {
		"branch": "Laser", "name": "Long Barrel", "max": 6, "per_rank": 25.0,
		"about": "+25 m laser range", "requires": {"laser_damage": 2},
	},
	"crit": {
		"branch": "Laser", "name": "Eye Tracker", "max": 6, "per_rank": 0.8,
		"about": "Eye hits deal +0.8x damage", "requires": {"laser_range": 2},
	},
	"pierce": {
		"branch": "Laser", "name": "Piercing Core", "max": 6, "per_rank": 1.0,
		"about": "Bolts pass through one more enemy", "requires": {"laser_damage": 3},
	},
	"power": {
		"branch": "Laser", "name": "Overcharge", "max": 5, "per_rank": 0.1,
		"about": "+10% damage, all weapons", "cost": 2, "requires": {"laser_damage": 4},
	},
	"spread": {
		"branch": "Spread", "name": "Laser Spread", "max": 5, "per_rank": 1.0,
		"about": "Wider bolt fan, shared damage", "requires": {"fire_rate": 1},
	},
	"focus": {
		"branch": "Spread", "name": "Focused Fan", "max": 2, "per_rank": 0.05,
		"about": "Each bolt in a fan hits harder", "cost": 2, "requires": {"spread": 3},
	},
	"plasma_damage": {
		"branch": "Plasma", "name": "Plasma Core", "max": 6, "per_rank": 40.0,
		"about": "+40 plasma blast damage",
	},
	"plasma_charge": {
		"branch": "Plasma", "name": "Quick Charge", "max": 6, "per_rank": 1.0,
		"about": "Plasma charges 16% faster", "requires": {"plasma_damage": 1},
	},
	"plasma_blast": {
		"branch": "Plasma", "name": "Wide Blast", "max": 6, "per_rank": 2.5,
		"about": "+2.5 m plasma blast radius", "requires": {"plasma_damage": 2},
	},
	"warheads": {
		"branch": "Missiles", "name": "Warheads", "max": 6, "per_rank": 8.0,
		"about": "+8 missile damage and +3 m blast",
	},
	"reload": {
		"branch": "Missiles", "name": "Autoloader", "max": 3, "per_rank": 0.1,
		"about": "-10% missile and plasma cooldown", "cost": 2, "requires": {"warheads": 2},
	},
	"homing_missile": {
		"branch": "Missiles", "name": "Homing Missiles", "max": 1, "per_rank": 1.0,
		"about": "Unlocks homing missiles", "cost": 3, "requires": {"warheads": 3},
	},
	"swarm_missile": {
		"branch": "Missiles", "name": "Missile Swarm", "max": 1, "per_rank": 1.0,
		"about": "Unlocks the six-missile swarm", "cost": 5,
		"requires": {"homing_missile": 1, "warheads": 5},
	},
	"shield": {
		"branch": "Shield", "name": "Shield Bubble", "max": 4, "per_rank": 25.0,
		"about": "+25 capacity, shield gems start dropping",
	},
	"beacon": {
		"branch": "Shield", "name": "Shield Beacon", "max": 3, "per_rank": 0.03,
		"about": "Shield gems drop more often", "requires": {"shield": 1},
	},
	"hull": {
		"branch": "Shield", "name": "Armor Plating", "max": 3, "per_rank": 20.0,
		"about": "+20 max health", "cost": 2, "requires": {"shield": 2},
	},
	"thrusters": {
		"branch": "Engines", "name": "Thrusters", "max": 5, "per_rank": 0.08,
		"about": "+8% movement speed",
	},
	"afterburner": {
		"branch": "Engines", "name": "Afterburner", "max": 3, "per_rank": 0.2,
		"about": "Stronger Shift boost", "cost": 2, "requires": {"thrusters": 2},
	},
}

## Bonuses that switch on by themselves once every listed rank is reached.
const SYNERGIES := {
	"bullet_storm": {
		"name": "Bullet Storm", "about": "laser fires 25% faster",
		"requires": {"power": 2, "spread": 3},
	},
	"marksman": {
		"name": "Marksman", "about": "eye hits deal another +1x",
		"requires": {"laser_range": 3, "crit": 3},
	},
	"overload": {
		"name": "Overload", "about": "plasma cooldown 25% shorter",
		"requires": {"plasma_blast": 3, "plasma_charge": 3},
	},
	"cluster": {
		"name": "Cluster Swarm", "about": "swarm fires two extra missiles",
		"requires": {"swarm_missile": 1, "warheads": 6},
	},
	"shock_nova": {
		"name": "Shock Nova", "about": "a breaking shield blasts everything nearby",
		"requires": {"power": 1, "shield": 3},
	},
	"slipstream": {
		"name": "Slipstream", "about": "hits cost half the shield while boosting",
		"requires": {"thrusters": 3, "shield": 2},
	},
	"self_repair": {
		"name": "Self Repair", "about": "hull mends itself while the shield is up",
		"requires": {"beacon": 2, "hull": 2},
	},
}

var run := _new_run() ## The level last played, or the next one once a level is won.
var furthest := "" ## The latest level reached, which replaying earlier ones keeps.
var points := 0
var rewarded_medals := {} ## Mission name to the best medal that has paid out.
var ranks := {}

const DEMO_LEVEL := "res://levels/mountains.tscn"
const DEMO_RANKS := {
	"laser_damage": 5, "fire_rate": 5, "laser_range": 3, "crit": 3, "pierce": 2, "power": 3,
	"spread": 3, "plasma_damage": 4, "plasma_charge": 3, "plasma_blast": 3, "warheads": 6,
	"reload": 2, "homing_missile": 1, "swarm_missile": 1, "shield": 3, "beacon": 2, "hull": 3,
	"thrusters": 4, "afterburner": 2,
}

var debug_session := false ## Temporary: a debug level select run, never saved.
var demo := false ## The title screen's autopilot demo, also never saved.

var _banked := {} ## The next level's run, once this one has been won.


func _ready() -> void:
	_load()


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	run = file.get_value("save", "run", run)
	furthest = file.get_value("save", "furthest", run.level)
	points = file.get_value("save", "points", 0)
	rewarded_medals = file.get_value("save", "rewarded_medals", {})
	ranks = file.get_value("save", "ranks", {})


func has_save() -> bool:
	return run.level != "" and ResourceLoader.exists(run.level)


func level_name() -> String:
	return LEVEL_NAMES.get(run.level, "last level")


## Every level up to the furthest reached, in mission order.
func reached_levels() -> Array:
	var levels: Array = LEVEL_NAMES.keys()
	return levels.slice(0, levels.find(furthest) + 1)


func new_game() -> void:
	run = _new_run()
	furthest = ""
	points = 0
	rewarded_medals = {}
	ranks = {}
	_banked = {}
	debug_session = false
	DirAccess.remove_absolute(SAVE_PATH)


## Back to the title screen. A won level counts as moved on from, and a debug run
## gives way to the real save.
func leave_level() -> void:
	if debug_session:
		debug_session = false
		demo = false
		run = _new_run()
		furthest = ""
		points = 0
		rewarded_medals = {}
		ranks = {}
		_banked = {}
		_load()
	elif _banked:
		advance()


## Sets up the autopilot's ship in memory, leaving the save file as it is.
func demo_start() -> void:
	debug_session = true
	demo = true
	run = _new_run()
	run.level = DEMO_LEVEL
	points = 0
	ranks = DEMO_RANKS.duplicate()


## Temporary: jumps to a level for testing, leaving the save file as it is.
func debug_start(level: String, use_powerups: bool) -> void:
	debug_session = true
	if not use_powerups:
		run = _new_run()
		points = 0
		ranks = {}
	run.level = level


## Every level announces itself here. Restarting a won level drops what it banked.
func enter_level(scene: String) -> void:
	run.level = scene
	_banked = {}
	_reach(scene)
	_save()


## Banks a won level straight away, so quitting from the result screen keeps it.
func complete_level(next_level: String) -> void:
	_banked = {"level": next_level}
	_reach(next_level)
	_save()


## Moves on to the banked level.
func advance() -> void:
	run = _banked
	_banked = {}


## What a stronger ship adds to a level's threat. Rises in steps, not a line, so each
## batch of new ranks gets a stretch of being ahead before the enemies answer it.
func threat() -> int:
	var tier := spent_ranks() / THREAT_TIER_RANKS
	var into := spent_ranks() % THREAT_TIER_RANKS - THREAT_TIER_CALM
	var rise := maxf(float(into) / (THREAT_TIER_RANKS - THREAT_TIER_CALM), 0.0)
	return floori((tier + rise) * THREAT_TIER_RISE)


func add_point() -> void:
	points += 1
	_save()
	point_gained.emit()
	skills_changed.emit()


## Pays for a medal better than any this mission has paid for, so nothing can be farmed.
## A medal skipped on the way up is forfeited. Returns the points gained.
func reward_medal(mission: String, medal: int) -> int:
	if medal <= rewarded_medals.get(mission, -1):
		return 0
	rewarded_medals[mission] = medal
	var amount: int = MEDAL_POINTS[medal]
	for i in amount:
		add_point()
	return amount


func rank(skill: String) -> int:
	return ranks.get(skill, 0)


func value(skill: String) -> float:
	return rank(skill) * float(SKILLS[skill].per_rank)


func requirements_met(requires: Dictionary) -> bool:
	for skill: String in requires:
		if rank(skill) < requires[skill]:
			return false
	return true


func unlocked(skill: String) -> bool:
	return requirements_met(SKILLS[skill].get("requires", {}))


## What the next rank costs.
func cost(skill: String) -> int:
	return SKILLS[skill].get("cost", 1) + rank(skill) / COST_STEP


func can_buy(skill: String) -> bool:
	return points >= cost(skill) and rank(skill) < SKILLS[skill].max and unlocked(skill)


func buy(skill: String) -> void:
	if not can_buy(skill):
		return
	points -= cost(skill)
	ranks[skill] = rank(skill) + 1
	_save()
	skills_changed.emit()


func has_synergy(synergy: String) -> bool:
	return requirements_met(SYNERGIES[synergy].requires)


func spent_ranks() -> int:
	var total := 0
	for skill: String in ranks:
		total += ranks[skill]
	return total


## Ranks held in one column of the tree.
func branch_ranks(branch: String) -> int:
	var total := 0
	for skill: String in ranks:
		if SKILLS[skill].branch == branch:
			total += ranks[skill]
	return total


func _reach(level: String) -> void:
	var levels: Array = LEVEL_NAMES.keys()
	if debug_session:
		return
	if levels.find(level) > levels.find(furthest):
		furthest = level


func _new_run() -> Dictionary:
	return {"level": ""}


func _save() -> void:
	if debug_session:
		return
	var file := ConfigFile.new()
	file.set_value("save", "run", _banked if _banked else run)
	file.set_value("save", "furthest", furthest)
	file.set_value("save", "points", points)
	file.set_value("save", "rewarded_medals", rewarded_medals)
	file.set_value("save", "ranks", ranks)
	file.save(SAVE_PATH)
