shader_type canvas_item;

// Use a NoiseTexture2D
uniform sampler2D noise_texture;
// Use a GradientTexture1D
uniform sampler2D burn_texture;

// Change this value to dissolve the object
uniform float integrity: hint_range(0.0, 1.0) = 1.0;
// How large the burn is
uniform float burn_size: hint_range(1.0, 1.5) = 1.3;

// Inverse lerp function
// Converts the value v from the range [a, b] to the range [0, 1]
float inverse_lerp(float a, float b, float v) {
	return (v - a) / (b - a);
}

// Called for every pixel the material is visible on
void fragment() {
	vec4 sprite_color = texture(TEXTURE, UV);
	float sprite_alpha = sprite_color.a;
	// Bias the burn to the center of the sprite so it ignites there first.
	float center_weight = 1.0 - clamp(distance(UV, vec2(0.5, 0.5)) / 0.70710678, 0.0, 1.0);
	center_weight = pow(center_weight, 1.6);
	float noise_sample = texture(noise_texture, UV).r;
	float noise = clamp(noise_sample * 0.4 + center_weight * 0.65, 0.0, 0.9999);
	// Sample the base color of the texture
	// The step function returns 1 when integrity > noise or 0 when integrity < noise
	vec4 base_color = sprite_color * step(noise, integrity);
	// Compute the UVs for the burn texture
	// Covert the range [integrity, integrity * burn_size] to a [0.0, 1.0] range
	float burn_edge = max(integrity * burn_size, integrity + 0.0001);
	vec2 burn_uv = vec2(clamp(inverse_lerp(integrity, burn_edge, noise), 0.0, 1.0), 0.0);
	// Sample the burn texture using a higher edge in the step function
	vec4 burn_color = texture(burn_texture, burn_uv) * step(noise, burn_edge) * sprite_alpha;
	// Lerp between the end colors and keep alpha inside the source sprite.
	vec4 result = mix(burn_color, base_color, base_color.a);
	result.a = min(result.a, sprite_alpha);
	COLOR = result * step(0.0001, sprite_alpha);
}
