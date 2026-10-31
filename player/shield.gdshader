shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;

// A thin blue bubble, clearest in the middle and brightest around the rim.
uniform vec3 color = vec3(0.25, 0.6, 1.0);
uniform float charge = 1.0; // Thins out as the shield drains.
uniform float flash = 0.0; // Set to 1 on a hit, then fades.

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	ALBEDO = color + vec3(flash * 0.5);
	ALPHA = (0.08 + 0.6 * rim) * (0.4 + 0.6 * charge) + flash * 0.3;
}
