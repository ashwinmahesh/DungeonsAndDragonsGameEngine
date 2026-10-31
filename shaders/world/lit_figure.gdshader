// A 3D figure's surfaces (ModelFigure, FigureModels): a rigged model's own painted texture, lit the way the 2D figures
// are lit (sprite_crisp.gdshader) so the two read as one cast: every light reaches it a little more evenly than physics
// would have it (light wrapping round the body), no light more than `light_cap` (a lantern beside it lights it warmly
// rather than washing it white), `light_floor` keeps it readable in the dark, and a light behind it draws a rim along
// its edge. Unlike a sprite it turns in the light: the side away from a lamp is in shade.
// The Toon finish (Look.toon_settings figure_*): the light falls in hard cel bands (`bands` 2: lit and shade; 3: and a
// dark core; 0: soft), and the texture's fine noise flattens toward its broad colours (`flatten` toward mip `flatten_mip`)
// and its colours are pushed (`vivid`), as a painted cel figure's are. Its ink is the second pass (figure_ink).
// Drawn as the 2D figures are, after the screen pass (ModelFigure sets DirectionalSprite.RENDER_PRIORITY): the place's
// mist, grade, palette and depth blur are the world's, and the figure stays clear over them. It is fully opaque (ALPHA
// 1) and writes depth, so it hides itself and other figures as a solid thing does; a fade is a screen-door dither.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
#include "res://addons/dnd_core/shaders/world/figure.gdshaderinc"

global uniform float look_soft;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 albedo : source_color = vec3(1.0);
uniform bool use_texture = true;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float light_floor = 0.25;
uniform float light_cap = 0.85;
uniform float rim_strength = 1.2;
uniform int bands = 0;
uniform vec4 band_light = vec4(0.5, 0.22, 0.55, 0.04);   // lit from, dark below, the shade's brightness, a band's edge
uniform float flatten = 0.0;
uniform float flatten_mip = 4.0;
uniform float vivid = 1.0;
uniform vec3 ghost_tint : source_color = vec3(0.741, 0.741, 0.776);

const float LAMP_GAIN = 1.35;

bool toon() {
	return look_soft > 1.5;
}

void fragment() {
	if (figure_hidden(FRAGCOORD.xy)) {
		discard;
	}
	vec3 base = albedo;
	if (use_texture) {
		base *= texture(albedo_tex, UV).rgb;
		if (toon() && flatten > 0.0) {
			base = mix(base, albedo * textureLod(albedo_tex, UV, flatten_mip).rgb, flatten);
		}
	}
	if (toon() && vivid != 1.0) {
		float l = dot(base, vec3(0.299, 0.587, 0.114));
		base = max(mix(vec3(l), base, vivid), vec3(0.0));
	}
	base *= tint.rgb;
	if (ghost > 0.0) {
		float lum = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, clamp(vec3(lum) * ghost_tint * 1.35, 0.0, 1.0), ghost);
	}
	ALBEDO = base * (1.0 - flash);
	EMISSION = base * max(light_floor, glow) * (1.0 - flash) + vec3(flash);
	ROUGHNESS = roughness;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	ALPHA = 1.0;
}

void light() {
	float gain = LIGHT_IS_DIRECTIONAL ? 1.0 : LAMP_GAIN;
	vec3 c = LIGHT_COLOR / PI * gain;
	float peak = max(c.r, max(c.g, c.b));
	c *= min(1.0, light_cap / max(peak, 0.0001));
	// Wrapped: a face turned side-on to the light is half lit, one turned away still takes a little.
	float wrap = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0) * ATTENUATION;
	float shade;
	if (toon() && bands >= 2) {
		float e = band_light.w;
		float lit = smoothstep(band_light.x - e, band_light.x + e, wrap);
		float dark = bands >= 3 ? smoothstep(band_light.y - e, band_light.y + e, wrap) : 1.0;
		shade = mix(band_light.z * mix(0.55, 1.0, dark), 1.0, lit);
	} else {
		shade = mix(0.35, 1.0, wrap);
	}
	DIFFUSE_LIGHT += c * shade;
	// The rim: along the edges facing away from the eye, strongest when the light is behind the figure.
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float behind = clamp(0.35 - dot(LIGHT, VIEW), 0.0, 1.0);
	float rim = toon() && bands >= 2 ? step(0.45, edge * behind) : edge * behind;
	SPECULAR_LIGHT += c * rim * rim_strength * ATTENUATION;
}
