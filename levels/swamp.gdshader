shader_type spatial;

// Rotting bogland: dark mud, sickly moss, standing pools in the hollows, ash on the rises.
uniform sampler2D noise_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 mud : source_color = vec3(0.13, 0.09, 0.07);
uniform vec3 moss : source_color = vec3(0.26, 0.30, 0.09);
uniform vec3 water : source_color = vec3(0.05, 0.11, 0.08);
uniform vec3 rock : source_color = vec3(0.24, 0.21, 0.24);
uniform vec3 ash : source_color = vec3(0.45, 0.43, 0.42);
uniform float rock_slope = 0.75; // World-up normal below this turns to rock.
uniform float water_height = -2.0;
uniform float snow_height = 40.0; // Set by the terrain. Ash starts here.

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = texture(noise_texture, world_position.xz * 0.7).r;
	float clumps = texture(noise_texture, world_position.xz * 0.09).r;
	float blotches = texture(noise_texture, world_position.xz * 0.018).r;
	vec3 ground = mix(mud, moss, smoothstep(0.42, 0.62, clumps * 0.6 + blotches * 0.5 + grain * 0.15));
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	ground = mix(ground, rock * (0.6 + clumps), smoothstep(rock_slope + 0.08, rock_slope - 0.08, up));
	float ashline = snow_height + (clumps - 0.5) * 12.0;
	ground = mix(ground, ash, smoothstep(ashline - 3.0, ashline + 3.0, world_position.y));
	float pool = smoothstep(water_height + 0.5, water_height - 0.5, world_position.y + (grain - 0.5));
	ALBEDO = mix(ground, water, pool);
	ROUGHNESS = mix(0.95, 0.15, pool);
	SPECULAR = mix(0.2, 0.6, pool);
}
