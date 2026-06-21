shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

global uniform vec3 playerPos;
global uniform vec3 cameraDir;
uniform vec3 color: source_color;
uniform vec3 color2: source_color;
uniform sampler2D blade_tex;
uniform sampler2D noise;
uniform sampler2D windNoise;
uniform float noiseScale = 20.0;

varying vec3 worldPos;

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 playerOffset = worldPos - playerPos;
	
	// FAR FALLOFF
	vec3 cameraDirProjected = cameraDir - vec3(0,1,0) * cameraDir.y;
	float fallOffDist = length(playerOffset + normalize(cameraDirProjected) * 10.0);
	float falloff = exp(-pow(fallOffDist * 0.05,2));
	float fallOffTresh = 15.0;
	float factor = clamp(1.0 - (fallOffDist - fallOffTresh) / 15.0, 0.0, 1.0);
	if (fallOffDist > fallOffTresh){
		VERTEX = VERTEX * factor;
	}
	if (factor > 0.0){
		// WIND
		vec3 movingWorldPos1 = worldPos + vec3(1,0,1) * TIME * 0.5;
		vec3 movingWorldPos2 = worldPos + vec3(0.7,0,1.3) * TIME * 0.3;
		vec3 noise1 = texture(windNoise, movingWorldPos1.xz / noiseScale).rgb;
		vec3 noise2 = texture(windNoise, movingWorldPos2.xz / noiseScale).rgb * 0.5;
		vec3 noiseLevel = noise1 + noise2;
		VERTEX += vec3(1,0,1) * 0.5 * noiseLevel * (1.0 - UV.y);
		vec3 colorNoise = texture(noise, worldPos.xz / noiseScale).rgb;
		VERTEX = vec3(VERTEX.x, VERTEX.y * (0.5 + colorNoise.r * 2.0), VERTEX.z);
		
		// PLAYER OFFSETTING
		float reductionFactor = (1.0 - UV.y) / (1.0 + 8.0 * pow(length(playerOffset), 4));
		VERTEX = VERTEX * vec3(1,1.0-reductionFactor,1);
		vec3 localOffset = (inverse(MODEL_MATRIX) * vec4(vec3(playerOffset.x, 0.0, playerOffset.z), 0.0)).xyz;
		VERTEX = VERTEX + normalize(localOffset) * reductionFactor * 2.0;
		//VERTEX += normalize(vec3(dirToPlayer.x, 0.0, dirToPlayer.y)) * exp(-2.0 * distToPlayer * distToPlayer) * (1.0 - UV.y);
		
	}
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	
	if (!FRONT_FACING){
		NORMAL = -NORMAL;
	}
	ALBEDO = mix(color, color2, 1.0 - UV.y) * mix(color, vec3(1,1,0.1) * 0.8, noiseLevel.r);
	ALPHA = texture(blade_tex, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
