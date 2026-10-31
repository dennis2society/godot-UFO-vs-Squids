extends Area3D
## The blinker's homing missile. Slower than a boosting ship, so running works, but it
## turns well and has a tiny hitbox. A plasma blast or a few clean laser hits stop it.

@export var turn_radius := 9.0 ## Tight enough to catch a ship that stops dead.
@export var lifetime := 14.0
@export var health := 2.0
@export var blast_radius := 3.0
@export var explosion_scene: PackedScene

var player: Node3D
var direction := Vector3.UP
var speed := 45.0
var damage := 30.0

var _exploded := false


func _ready() -> void:
	basis = Basis.looking_at(direction)
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
		return
	var wanted := global_position.direction_to(player.global_position)
	var angle := direction.angle_to(wanted)
	if angle > 0.001:
		direction = direction.slerp(wanted, minf(speed / turn_radius * delta / angle, 1.0)).normalized()
		basis = Basis.looking_at(direction)
	global_position += direction * speed * delta


func take_hit(amount: float, _crit: float, _from: Vector3, _direction: Vector3) -> void:
	apply_damage(amount)


func apply_damage(amount: float, _crit := false) -> void:
	health -= amount
	if health <= 0.0:
		_explode()


func _on_body_entered(other: Node3D) -> void:
	if other.has_method("take_damage"):
		other.take_damage(damage)
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var explosion := explosion_scene.instantiate()
	explosion.position = global_position
	explosion.radius = blast_radius
	explosion.damage = 0.0
	# Deferred because it can go off during a physics callback.
	get_parent().add_child.call_deferred(explosion)
	queue_free()
