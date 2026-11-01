shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
// Fullscreen black outlines, found from jumps in depth and creases in the normals.
// Runs before transparent materials, so glows, beams and smoke stay clean.

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform float thickness = 1.5; // In pixels at 1080p.
uniform float depth_threshold = 0.03; // Relative jump in depth that starts a line.
uniform float crease_threshold = 0.7; // Difference between neighboring normals.
uniform float crease_fade_start = 30.0; // Far objects are thin enough that creases would cover them.
uniform float crease_fade_end = 80.0;
uniform float fade_start = 120.0; // All lines thin out with distance, or far terrain turns to noise.
uniform float fade_end = 400.0;


void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}


// 1/z runs linearly across a flat surface, so a slope seen at a low angle doesn't count as a jump.
float inverse_depth(vec2 uv, mat4 inverse_projection) {
	vec4 view = inverse_projection * vec4(0.0, 0.0, texture(depth_texture, uv).r, 1.0);
	return -view.w / view.z;
}


vec3 normal_at(vec2 uv) {
	return texture(normal_texture, uv).xyz * 2.0 - 1.0;
}


void fragment() {
	vec2 step_size = thickness * max(VIEWPORT_SIZE.y / 1080.0, 1.0) / VIEWPORT_SIZE;
	vec2 dx = vec2(step_size.x, 0.0);
	vec2 dy = vec2(0.0, step_size.y);

	float center = inverse_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float left = inverse_depth(SCREEN_UV - dx, INV_PROJECTION_MATRIX);
	float right = inverse_depth(SCREEN_UV + dx, INV_PROJECTION_MATRIX);
	float down = inverse_depth(SCREEN_UV - dy, INV_PROJECTION_MATRIX);
	float up = inverse_depth(SCREEN_UV + dy, INV_PROJECTION_MATRIX);
	// Signed, so a line only lands on the far side of an edge and thin objects keep their color.
	float jump = max(left + right - 2.0 * center, down + up - 2.0 * center);
	jump /= max(center, 0.00001);

	vec3 normal_dx = normal_at(SCREEN_UV + dx) - normal_at(SCREEN_UV - dx);
	vec3 normal_dy = normal_at(SCREEN_UV + dy) - normal_at(SCREEN_UV - dy);
	float crease = max(length(normal_dx), length(normal_dy));

	float distance_to_camera = 1.0 / max(max(center, max(left, right)), max(down, up));
	crease *= 1.0 - smoothstep(crease_fade_start, crease_fade_end, distance_to_camera);

	float edge = max(
			smoothstep(depth_threshold, depth_threshold * 2.0, jump),
			smoothstep(crease_threshold, crease_threshold * 1.5, crease));
	ALBEDO = vec3(0.0);
	ALPHA = edge * (1.0 - smoothstep(fade_start, fade_end, distance_to_camera));
}
