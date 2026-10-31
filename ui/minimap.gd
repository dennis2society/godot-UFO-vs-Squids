extends Control
## The whole map from above, north up: the player in blue with a heading tick, enemies
## in red, rare enemies in yellow and crystals in cyan.

@export var background := Color(0.0, 0.0, 0.0, 0.5)
@export var border := Color(1.0, 1.0, 1.0, 0.5)
@export var player_color := Color(0.3, 0.6, 1.0)
@export var enemy_color := Color(0.95, 0.2, 0.15)
@export var rare_color := Color(1.0, 0.85, 0.15)
@export var crystal_color := Color(0.3, 0.95, 0.9)
@export var dot_radius := 2.0
@export var rare_radius := 3.5
@export var player_radius := 3.5
@export var heading_length := 9.0

var player: Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, background)
	draw_rect(area, border, false, 1.0)
	if player == null:
		return

	for crystal: Node3D in get_tree().get_nodes_in_group("crystals"):
		draw_circle(_to_map(crystal.global_position), 1.5, crystal_color)
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if enemy.bonus:
			continue
		draw_circle(_to_map(enemy.global_position), dot_radius, enemy_color)
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if enemy.bonus: # Drawn last, so rare targets stay visible in a crowd.
			draw_circle(_to_map(enemy.global_position), rare_radius, rare_color)

	var at := _to_map(player.global_position)
	var ahead: Vector3 = -player.global_basis.z
	draw_line(at, at + Vector2(ahead.x, ahead.z).normalized() * heading_length, player_color, 2.0)
	draw_circle(at, player_radius, player_color)


## World x runs right and z runs down the map.
func _to_map(world: Vector3) -> Vector2:
	var reach: float = player.bounds
	var share := Vector2(world.x, world.z) / reach * 0.5 + Vector2(0.5, 0.5)
	return (share * size).clamp(Vector2.ZERO, size)
