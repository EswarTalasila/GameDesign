shader_type canvas_item;

uniform bool glow_enabled = false;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float outline_width : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (glow_enabled && col.a < 0.1) {
		vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(ps.x, ps.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a);
		if (a > 0.1) {
			col = vec4(glow_color.rgb, glow_alpha * a);
		}
	}

	COLOR = col;
}
