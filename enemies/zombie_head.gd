extends "res://enemies/squid.gd"
## A rotting severed head. Tougher than a squid and never shoots, but it drifts slowly
## and then lunges, snapping its jaw.

@export var toughness := 1.6 ## Health compared with a squid.
@export var lunge_speed := 3.0 ## Times the chase speed, mid lunge.
@export var lurk_speed := 0.4 ## Times the chase speed, between lunges.
@export var lunge_rate := 1.5

@onready var jaw: Node3D = $Body/Jaw


func _ready() -> void:
	max_health *= toughness
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	jaw.rotation.x = 0.35 + sin(_time * 14.0) * 0.3 if _lunging() else 0.1


func _chase_speed() -> float:
	return chase_speed * (lunge_speed if _lunging() else lurk_speed)


func _lunging() -> bool:
	return sin((_time + _phase) * lunge_rate) > 0.2


func _shoot(_delta: float) -> void:
	pass
