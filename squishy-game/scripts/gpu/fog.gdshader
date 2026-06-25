shader_type fog;

uniform sampler3D noise_tex;
uniform float base_density = 0.3;
uniform float noise_contrast = 2.0;

void fog() {
	vec3 uvw = fract(UVW + vec3(1,1,1) * TIME * 0.01);
    float n = texture(noise_tex, uvw).r;
    
	DENSITY = clamp((n - 0.5)/(1.0 - 0.5), 0, 1);
	ALBEDO = vec3(1.0);
}