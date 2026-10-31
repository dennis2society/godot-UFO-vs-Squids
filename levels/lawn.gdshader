shader_type spatial;

uniform sampler2D noise_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 dark_grass : source_color = vec3(0.10, 0.27, 0.06);
uniform vec3 light_grass : source_color = vec3(0.30, 0.52, 0.13);
uniform vec3 rock : source_color = vec3(0.38, 0.35, 0.32);
uniform vec3 snow : source_color = vec3(0.92, 0.94, 0.97);
uniform float rock_slope = 0.75; // World-up normal below this turns to rock.
uniform float snow_height = 48.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float blades = texture(noise_texture, world_position.xz * 0.9).r;
	float tufts = texture(noise_texture, world_position.xz * 0.11).r;
	float patches = texture(noise_texture, world_position.xz * 0.013).r;
	vec3 grass = mix(dark_grass, light_grass, clamp(blades * 0.4 + tufts * 0.3 + patches * 0.5, 0.0, 1.0));
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	vec3 ground = mix(grass, rock * (0.6 + tufts), smoothstep(rock_slope + 0.08, rock_slope - 0.08, up));
	float snowline = snow_height + (tufts - 0.5) * 10.0;
	ALBEDO = mix(ground, snow, smoothstep(snowline - 2.0, snowline + 2.0, world_position.y));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
