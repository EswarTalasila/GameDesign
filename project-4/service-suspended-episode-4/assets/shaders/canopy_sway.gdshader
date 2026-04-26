shader_type canvas_item;

// Gentle wind sway that only affects the canopy.
// The lower trunk area is left untouched; top canopy sways the most.
// Works per-pixel so the bend is smooth across the whole tree.
// Attach to a tree Sprite2D's material. Remove the material to disable.

uniform float sway_strength : hint_range(0.0, 0.08, 0.001) = 0.02;
uniform float sway_speed : hint_range(0.0, 5.0, 0.1) = 1.5;
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;
uniform float canopy_bottom : hint_range(0.1, 1.0, 0.01) = 0.56;
uniform float canopy_feather : hint_range(0.0, 0.25, 0.01) = 0.05;

void fragment() {
	// UV.y: 0 = top of sprite, 1 = bottom.
	// Keep the trunk/base untouched. The feather prevents a hard seam where
	// the canopy motion fades out.
	float canopy_mask = 1.0 - smoothstep(canopy_bottom - canopy_feather, canopy_bottom, UV.y);
	float height_in_canopy = clamp(1.0 - (UV.y / canopy_bottom), 0.0, 1.0);
	float influence = height_in_canopy * height_in_canopy * canopy_mask;

	float offset_x = sin(TIME * sway_speed + phase_offset) * sway_strength * influence;

	vec2 shifted_uv = vec2(UV.x + offset_x, UV.y);
	shifted_uv.x = clamp(shifted_uv.x, 0.0, 1.0);

	COLOR = texture(TEXTURE, shifted_uv);
}
