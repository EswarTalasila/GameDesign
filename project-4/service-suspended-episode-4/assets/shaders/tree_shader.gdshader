shader_type canvas_item;

uniform float sway_strength : hint_range(0.0, 0.08, 0.001) = 0.012;
uniform float sway_speed : hint_range(0.0, 5.0, 0.1) = 1.5;
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;
uniform float canopy_bottom : hint_range(0.1, 1.0, 0.01) = 0.56;
uniform float canopy_feather : hint_range(0.0, 0.25, 0.01) = 0.05;
uniform float mesh_top_y = -70.0;
uniform float mesh_bottom_y = 10.0;

void vertex() {
	float local_v = clamp((VERTEX.y - mesh_top_y) / (mesh_bottom_y - mesh_top_y), 0.0, 1.0);
	float canopy_mask = 1.0 - smoothstep(canopy_bottom - canopy_feather, canopy_bottom, local_v);
	float height_in_canopy = clamp(1.0 - (local_v / canopy_bottom), 0.0, 1.0);
	float influence = height_in_canopy * height_in_canopy * canopy_mask;

	float sway_px = sin(TIME * sway_speed + phase_offset) * sway_strength * 64.0;
	VERTEX.x += sway_px * influence;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
