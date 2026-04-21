shader_type canvas_item;

uniform vec4 darkness_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform float cone_range = 0.35;
uniform float cone_half_angle = 0.42;
uniform vec2 cone_direction = vec2(0.0, 1.0);
uniform float edge_softness = 0.03;
uniform float aspect_ratio = 1.778;
uniform float cutout_radius = 0.07;

// Static world lights (up to 8)
uniform int light_count = 0;
uniform vec2 light_positions[8];
uniform vec2 light_directions[8];
uniform float light_ranges[8];
uniform float light_angles[8];
uniform float light_pools[8];
uniform float light_widths[8];
uniform float light_glows[8];
uniform float light_energies[8];

// Light tint — applied to lit areas (0,0,0 = no tint, 1,0,0 = red, etc.)
uniform vec3 light_tint = vec3(0.0, 0.0, 0.0);
uniform float light_tint_strength = 0.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	uv.x *= aspect_ratio;

	float dist = length(uv);

	// Player view cone
	vec2 adj_dir = normalize(cone_direction * vec2(aspect_ratio, 1.0));
	vec2 uv_dir = normalize(uv);
	float angle = acos(clamp(dot(uv_dir, adj_dir), -1.0, 1.0));
	float in_angle = smoothstep(cone_half_angle + edge_softness * 2.0, cone_half_angle - edge_softness * 2.0, angle);
	float in_range = smoothstep(cone_range + edge_softness, cone_range - edge_softness, dist);
	float cutout = smoothstep(cutout_radius, cutout_radius + edge_softness * 3.0, dist);
	float cone = in_angle * in_range * cutout;

	// World lights — frustum shape
	float lights = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= light_count) break;

		vec2 light_uv = UV - light_positions[i];
		light_uv.x *= aspect_ratio;

		vec2 l_dir = normalize(light_directions[i] * vec2(aspect_ratio, 1.0));
		vec2 l_perp = vec2(-l_dir.y, l_dir.x);

		float along = dot(light_uv, l_dir);
		float across = abs(dot(light_uv, l_perp));

		float t = clamp(along / light_ranges[i], 0.0, 1.0);
		float allowed_width = mix(light_widths[i], light_pools[i], t);

		float in_width = smoothstep(allowed_width + edge_softness, allowed_width - edge_softness, across);
		float in_front = smoothstep(-edge_softness, edge_softness, along);
		float in_rng = smoothstep(light_ranges[i] + edge_softness, light_ranges[i] - edge_softness, along);
		float frustum = in_width * in_front * in_rng;

		float light_dist = length(light_uv);
		float glow = smoothstep(light_glows[i] + edge_softness * 2.0, light_glows[i] - edge_softness * 2.0, light_dist);

		float energy = light_energies[i];
		lights = max(lights, max(frustum, glow) * energy);
	}

	float visibility = max(cone, lights);

	// Base: darkness where not visible
	vec3 base_color = darkness_color.rgb;
	float base_alpha = darkness_color.a * (1.0 - visibility);

	// Tint lit areas (world lights only, not player cone)
	vec3 tint_overlay = light_tint * lights * light_tint_strength;

	COLOR = vec4(base_color + tint_overlay, base_alpha + lights * light_tint_strength * 0.5);
}
