extends "res://pickups/pickup.gd"
## Restores part of the player's health. Ignored at full health.

@export var heal_fraction := 0.2 ## Share of the player's maximum health restored.


func _can_collect(player: Node3D) -> bool:
	return player.can_heal()


func _collect(player: Node3D) -> void:
	player.heal(player.max_health * heal_fraction)
