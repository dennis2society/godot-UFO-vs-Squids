extends Control
## A ring with four inward ticks and a centre dot, outlined to read on sky and grass.
## The left arc shows plasma cooldown, then charge while held. The right arc shows
## missile reload.

const ARC_SWEEP := PI * 0.5

@export var color := Color(1, 1, 1, 0.9)
@export var outline_color := Color(0, 0, 0, 0.45)
@export var radius := 16.0
@export var tick_length := 7.0
@export var arc_radius := 25.0
@export var arc_width := 3.0
@export var track_color := Color(0, 0, 0, 0.5)
@export var charge_color := Color(0.75, 0.1, 0.1)
@export var charge_full_color := Color(1.0, 0.15, 0.15)
@export var rocket_color := Color(0.15, 0.3, 0.6)
@export var rocket_ready_color := Color(0.2, 0.55, 1.0)

var weapon: Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_shape(outline_color, 2.0)
	_draw_shape(color, 0.0)
	if weapon == null:
		return

	var plasma: float = weapon.charge() if weapon.is_charging() else weapon.plasma_ready()
	_draw_gauge(PI * 1.25, -1.0, plasma, charge_full_color if plasma >= 1.0 else charge_color)
	var reload: float = weapon.rocket_ready()
	_draw_gauge(-PI * 0.25, 1.0, reload, rocket_ready_color if reload >= 1.0 else rocket_color)


## Draws an arc filling upwards from the bottom. Side is -1 for left, 1 for right.
func _draw_gauge(top: float, side: float, fill: float, fill_color: Color) -> void:
	var bottom := top + side * ARC_SWEEP
	draw_arc(Vector2.ZERO, arc_radius, bottom, top, 24, track_color, arc_width + 2.0, true)
	if fill > 0.0:
		draw_arc(Vector2.ZERO, arc_radius, bottom, lerpf(bottom, top, fill), 24, fill_color, arc_width, true)


func _draw_shape(shape_color: Color, grow: float) -> void:
	var width := 1.5 + grow
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, shape_color, width, true)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var from := direction * (radius + grow * 0.5)
		var to := direction * (radius - tick_length - grow * 0.5)
		draw_line(from, to, shape_color, width, true)
	draw_circle(Vector2.ZERO, 1.5 + grow * 0.5, shape_color, true, -1.0, true)
