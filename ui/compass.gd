extends Control
## A horizontal compass strip. North is the way each level starts out facing.

const LABELS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

@export var background := Color(0.0, 0.0, 0.0, 0.5)
@export var color := Color(1.0, 1.0, 1.0, 0.9)
@export var north_color := Color(1.0, 0.35, 0.3)
@export var marker_color := Color(1.0, 0.85, 0.15)
@export var visible_degrees := 120.0 ## How much of the circle fits across the strip.
@export var tick_step := 15
@export var font_size := 14

var player: Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background)
	if player == null:
		return

	var ahead: Vector3 = -player.global_basis.z
	var heading := fposmod(rad_to_deg(atan2(ahead.x, -ahead.z)), 360.0)
	var font := ThemeDB.fallback_font
	for degrees in range(0, 360, tick_step):
		var offset := wrapf(degrees - heading, -180.0, 180.0)
		if absf(offset) > visible_degrees * 0.5:
			continue
		var x := size.x * (0.5 + offset / visible_degrees)
		if LABELS.has(degrees):
			var text: String = LABELS[degrees]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var tint := north_color if degrees == 0 else color
			draw_string(font, Vector2(x - width * 0.5, size.y - 6.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
		else:
			draw_line(Vector2(x, size.y - 14.0), Vector2(x, size.y - 7.0), color, 1.0)

	var middle := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(middle - 5.0, 0.0), Vector2(middle + 5.0, 0.0), Vector2(middle, 7.0),
	]), marker_color)
