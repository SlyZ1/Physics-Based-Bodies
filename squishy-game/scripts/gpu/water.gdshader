shader_type spatial;
render_mode blend_mix;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D wave_tex;
uniform sampler2D foam_tex;
uniform float transparency: hint_range(0.0, 1.0);
uniform vec3 nearColor: source_color;
uniform vec3 farColor: source_color;
uniform float fadeFactor : hint_range(0.0, 1.0);
uniform float maxDepth = 10.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float get_linear_depth(mat4 mat, vec2 s_uv){
	float depth = texture(DEPTH_TEXTURE, s_uv).x;

	vec2 screen_uv = s_uv * 2.0 - vec2(1.0);
    vec3 ndc = vec3(screen_uv, depth);

    vec4 world = mat * vec4(ndc, 1.0);
    vec3 world_ndc = world.xyz / world.w;

    float thickness = length(world_pos - world_ndc);
    thickness = max(0.0, thickness);

    return clamp(thickness / maxDepth, 0.0, 1.0);
}

vec2 get_distorted_uv(vec2 s_uv, vec2 uv){
	vec2 rolling_uv1 = uv / 2.0 + vec2(1.0) * TIME * 0.1;
	float wave_noise1 = texture(wave_tex, rolling_uv1).r;
	vec2 rolling_uv2 = uv + vec2(-1.0, 0.0) * TIME * 0.08;
	float wave_noise2 = texture(wave_tex, rolling_uv2).r;
	return s_uv + vec2((wave_noise1 + wave_noise2 * 0.5) / 1.5 - 0.5) * 0.01;
}

void fragment() {
	vec3 scale = vec3(
        length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz),
        length(MODEL_MATRIX[2].xyz)
    );
	vec2 uv = UV * scale.xz / 20.0;
	vec2 distorted_screen_uv = get_distorted_uv(SCREEN_UV, UV);
	float realDepth = get_linear_depth(INV_VIEW_MATRIX * INV_PROJECTION_MATRIX, distorted_screen_uv);
    
	vec3 screenColor = texture(SCREEN_TEXTURE, distorted_screen_uv).xyz;
	vec3 near = mix(nearColor, screenColor, fadeFactor);
	vec3 depthColor = mix(near, farColor, realDepth);
	depthColor = mix(depthColor, screenColor, transparency);
	
	bool depth_test = realDepth < 0.1;
	bool foam_test = texture(foam_tex, uv * 2.0 + vec2(TIME * 0.01)).r > 0.88;
	if (depth_test || foam_test){
		depthColor = vec3(1.0);
	}
	
	ALBEDO = depthColor;
	METALLIC = 0.5;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
