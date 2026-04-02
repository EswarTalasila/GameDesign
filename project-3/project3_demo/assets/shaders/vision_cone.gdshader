shader_type canvas_item;

uniform vec4 darkness_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform float cone_range = 0.35;
uniform float cone_half_angle = 0.42;
uniform vec2 cone_direction = vec2(0.0, 1.0);
uniform float edge_softness = 0.03;
uniform float aspect_ratio = 1.778;
// Circle carved out around the player - blunts the cone tip into a concave arc
uniform float cutout_radius = 0.07;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	uv.x *= aspect_ratio;

	float dist = length(uv);

	// Directional view cone
	vec2 adj_dir = normalize(cone_direction * vec2(aspect_ratio, 1.0));
	vec2 uv_dir = normalize(uv);
	float angle = acos(clamp(dot(uv_dir, adj_dir), -1.0, 1.0));
	float in_angle = smoothstep(cone_half_angle + edge_softness * 2.0, cone_half_angle - edge_softness * 2.0, angle);
	float in_range = smoothstep(cone_range + edge_softness, cone_range - edge_softness, dist);

	// Carve a circle out around the player center.
	// This removes the sharp tip and creates a concave arc at the base.
	float cutout = smoothstep(cutout_radius, cutout_radius + edge_softness * 3.0, dist);

	float cone = in_angle * in_range * cutout;

	COLOR = vec4(darkness_color.rgb, darkness_color.a * (1.0 - cone));
}
