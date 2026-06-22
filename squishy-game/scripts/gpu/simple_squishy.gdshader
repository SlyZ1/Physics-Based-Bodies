shader_type spatial;

uniform sampler2D faceTex: source_color;
uniform vec3 color: source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 texVal = texture(faceTex, UV);
	float alpha = texVal.a;
	ALBEDO = texVal.rgb * alpha + (1.0 - alpha) * color;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
