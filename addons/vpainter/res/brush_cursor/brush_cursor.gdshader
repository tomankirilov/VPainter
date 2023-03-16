shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_test_disabled;

uniform vec3 col :source_color = vec3(0.2, 1.0, 0.2);
uniform float min_opacity :hint_range(0.0, 1.0) = 0.05;
uniform float max_opacicty:hint_range(0.0, 1.0) = 0.5;

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow(1.0 - (clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

void fragment() {
	float alpha_freshnel = fresnel(3.0, NORMAL, VIEW);
	ALBEDO = col;
	ALPHA = clamp(alpha_freshnel, min_opacity, max_opacicty);
}
