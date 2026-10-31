extends "res://pickups/pickup.gd"
## A blue gem that fills the shield to its capacity. The only way to refill it.

@export var spin_speed := 1.5

@onready var gem: MeshInstance3D = $Gem


func _physics_process(delta: float) -> void:
	super(delta)
	gem.rotate_y(spin_speed * delta)


## Lets the spawner see a shield gem is already waiting on the map.
func is_shield_pickup() -> bool:
	return true


func _can_collect(player: Node3D) -> bool:
	return player.shield < player.max_shield


func _collect(player: Node3D) -> void:
	player.restore_shield()
