// How the Modern finish's world takes each light (Improvement Ideas W3), shared by lit.gdshader and lit_world.gdshader.
//
// Diffuse: Lambert lifted towards the light (lit^0.75), the painted look: the outer part of a lamp's pool and a face
// turning away from the moon stay a little brighter than physics would have them, so pools of light read wide and
// warm, but nothing flattens into one band as Classic's cel ramp does, and relief shows wherever light falls.
// Specular: GGX with Schlick's Fresnel and height-correlated Smith visibility (as Godot's own), so a lamp leaves a
// highlight that is small and bright on polished stone and broad and faint on rough plaster, and glints off the worn
// tops of cobbles where the texture says the surface is smoother.
//
// Lamps light a third more than their energy says, as Classic's cel ramp lifted them: their pools of light read warm
// and wide against the shade. The sun and moon leave half the highlight a lamp would: a broad sky light glancing off a
// whole street reads as a grey haze over it, while a lamp's glints on the stones near it make a street look wet.
//
// The Toon finish (look_soft 2, Look.toon; plan E27, the 1980s anime cel look) takes the same lights in hard cel bands:
// lit, a mid tone and shade, a lamp's pool of light ending in a ring rather than fading, and a hard, bright highlight
// where the surface is glossy enough to hold one. Its fills are flatter and more vivid (toon_fill).
//
// Godot multiplies DIFFUSE_LIGHT by the albedo afterwards; LIGHT_COLOR already holds the light's energy times PI.
global uniform float look_soft;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// How wet the place is (W12; Atmosphere): under rain clouds the sun and moon leave almost no highlight, so wet stone
// glistens in the lamps' light rather than going grey with the sky's.
global uniform float world_wet;

const float LIT_LIFT = 0.75;
const float LAMP_GAIN = 1.35;
const float SKY_SPECULAR = 0.5;
// The Toon finish's settings (Look.toon_settings: the engine's defaults under data/campaign.json's "toon", set on every
// material Look makes). toon_light: where the bands break (light reaching the face, shadow and falloff included: lit,
// shade), the mid band's brightness and how soft a band's edge is. toon_band_count: 3 lit, mid and dark; 2 lit and mid;
// 0 keeps Modern's soft light (a painted background). toon_gloss: how glossy a surface must be to hold a highlight, and
// how bright it is. toon_fills: how far a texture flattens toward its own average colour, how much more saturated it
// gets, and how much of its relief (normal map) still shows. toon_flat_mip: the mip a texture flattens toward (12 its
// one average colour; lower keeps its larger shapes and loses only the fine noise, a painted look).
uniform vec4 toon_light = vec4(0.42, 0.07, 0.52, 0.025);
uniform int toon_band_count = 3;
uniform vec2 toon_gloss = vec2(0.62, 0.55);
uniform vec3 toon_fills = vec3(0.72, 1.3, 0.3);
uniform float toon_flat_mip = 12.0;

bool toon() {
	return look_soft > 1.5;
}

// A surface's colour in the Toon finish: its texture's detail pressed toward `mean` (the texture's average colour, a
// high mip) and its colour pushed, so a wall reads as one flat painted colour with a hint of its stones.
vec3 toon_fill(vec3 base, vec3 mean) {
	vec3 flat_col = mix(base, mean, toon_fills.x);
	float l = dot(flat_col, vec3(0.299, 0.587, 0.114));
	return max(mix(vec3(l), flat_col, toon_fills.y), vec3(0.0));
}

float toon_band(float lit) {
	float edge = toon_light.w;
	float shade = toon_band_count >= 3 ? smoothstep(toon_light.y - edge, toon_light.y + edge, lit) : 1.0;
	float full = smoothstep(toon_light.x - edge, toon_light.x + edge, lit);
	return mix(shade * toon_light.z, 1.0, full);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float gain = LIGHT_IS_DIRECTIONAL ? 1.0 : LAMP_GAIN;
	float sky = LIGHT_IS_DIRECTIONAL ? SKY_SPECULAR * (1.0 - world_wet * 0.85) : 1.0;
	if (toon() && toon_band_count > 0) {
		DIFFUSE_LIGHT += toon_band(lit) * LIGHT_COLOR / PI * gain;
		// One hard highlight on glossy surfaces, where the light's reflection points at the eye.
		vec3 th = normalize(VIEW + LIGHT);
		float gloss = 1.0 - smoothstep(toon_gloss.x - 0.15, toon_gloss.x, ROUGHNESS);
		float aim = smoothstep(0.955, 0.965, dot(NORMAL, th)) * step(toon_light.x, lit);
		SPECULAR_LIGHT += aim * gloss * toon_gloss.y * LIGHT_COLOR / PI * gain * SPECULAR_AMOUNT * sky;
	} else {
		DIFFUSE_LIGHT += pow(lit, LIT_LIFT) * LIGHT_COLOR / PI * gain;
		// Specular only on the lit side (a light can't glint off a face turned away from it).
		vec3 h = normalize(VIEW + LIGHT);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float ndv = clamp(dot(NORMAL, VIEW), 1e-4, 1.0);
		float ldh = clamp(dot(LIGHT, h), 0.0, 1.0);
		float a = max(ROUGHNESS * ROUGHNESS, 0.002);
		float a2 = a * a;
		float dd = ndh * ndh * (a2 - 1.0) + 1.0;
		float d = a2 / (PI * dd * dd);
		float vis = 0.5 / (ndl * sqrt(ndv * ndv * (1.0 - a2) + a2) + ndv * sqrt(ndl * ndl * (1.0 - a2) + a2));
		vec3 f0 = mix(vec3(0.16 * specular * specular), ALBEDO, METALLIC);
		vec3 f = f0 + (1.0 - f0) * pow(1.0 - ldh, 5.0);
		SPECULAR_LIGHT += ndl * d * vis * f * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT * sky * step(1e-4, ndl);
	}
}
