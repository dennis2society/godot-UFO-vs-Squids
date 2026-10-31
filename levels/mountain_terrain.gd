extends "res://levels/terrain.gd"
## A continuous mountain range with connected ridges and valleys, the same for every
## retry in a session. Slopes are limited, so there are no impossible spikes or walls.

static var _session_seed := 0

@export var peak_height := 120.0
@export var range_frequency := 0.0035 ## How broad the mountain ranges are.
@export var ridge_gain := 0.0075 ## Spacing of the ridgelines within a range.
@export var warp_strength := 45.0 ## Bends ridges so they don't run straight.
@export var max_slope := 1.8 ## Most height change allowed per metre.
@export var rock_detail := 7.0 ## Roughness added once slopes are limited.
@export var start_clear_radius := 45.0 ## The start valley stays open out to here.
@export var start_clear_falloff := 70.0


func _generate_heights() -> PackedFloat32Array:
	if _session_seed == 0:
		_session_seed = randi_range(1, 2147483647)
	var base_seed := terrain_seed if terrain_seed != 0 else _session_seed

	var warp := _noise(base_seed, 0.004, 2)
	var ranges := _noise(base_seed + 1, range_frequency, 3)
	var valleys := _noise(base_seed + 2, noise_frequency, 4)
	var detail := _noise(base_seed + 3, 0.04, 3)
	var ridges := _noise(base_seed + 4, ridge_gain, 6)
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED

	var side := cells + 1
	var half := cells * 0.5
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for z in side:
		for x in side:
			var bent_x := x + warp.get_noise_2d(x, z) * warp_strength
			var bent_z := z + warp.get_noise_2d(x + 311.0, z + 97.0) * warp_strength
			var ridge := pow(ridges.get_noise_2d(bent_x, bent_z) * 0.5 + 0.5, 1.7)
			var range_mask := smoothstep(-0.25, 0.35, ranges.get_noise_2d(x, z))
			var distance := Vector2(x - half, z - half).length()
			range_mask *= smoothstep(start_clear_radius, start_clear_radius + start_clear_falloff, distance)
			var mountain := (0.25 + 0.75 * ridge) * peak_height
			heights[x + z * side] = valleys.get_noise_2d(x, z) * height_scale + range_mask * mountain
	_limit_slopes(heights, side)

	# Added after the limit, whose straight slopes would otherwise look man-made.
	for z in side:
		for x in side:
			var i := x + z * side
			var altitude := clampf(heights[i] / peak_height, 0.0, 1.0)
			heights[i] += detail.get_noise_2d(x, z) * rock_detail * altitude
	return heights


func _noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise


## Lowers anything too steep above its neighbours, sweeping both ways across the map so
## a single pass settles the whole height field.
func _limit_slopes(heights: PackedFloat32Array, side: int) -> void:
	for i in side * side:
		if i % side > 0:
			heights[i] = minf(heights[i], heights[i - 1] + max_slope)
		if i >= side:
			heights[i] = minf(heights[i], heights[i - side] + max_slope)
	for i in range(side * side - 1, -1, -1):
		if i % side < side - 1:
			heights[i] = minf(heights[i], heights[i + 1] + max_slope)
		if i < side * side - side:
			heights[i] = minf(heights[i], heights[i + side] + max_slope)
