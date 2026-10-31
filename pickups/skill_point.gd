extends "res://pickups/pickup.gd"
## A gold gem dropped by rare enemies. Worth one point to spend in the skill tree.

@export var spin_speed := 1.5

@onready var gem: MeshInstance3D = $Gem


func _physics_process(delta: float) -> void:
	super(delta)
	gem.rotate_y(spin_speed * delta)


func _collect(player: Node3D) -> void:
	player.pickup_sound.play()
	Progress.add_point()
