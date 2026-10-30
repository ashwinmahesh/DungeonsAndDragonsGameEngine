// A new place resolving out of a soft blur as the black lifts (Visual Polish Plan 10; PlaceDissolve): the finished
// picture read back from the screen's mipmaps, softest at `amount` 1 and sharp at 0, a touch brighter while it's soft
// so the change reads as a haze clearing rather than a smear. Drawn on a canvas layer over the world and under the HUD,
// only while a place comes in.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// The softest blur, as a mip level at 1080 lines (one more for each doubling of the screen's height).
uniform float softest = 5.0;
uniform float lines = 1080.0;
// A game's ink wipe (Look.PAINTED ink_wipe, Visual Polish Plan E51): blots of ink cover the picture and shrink away
// from the middle out as it comes in, their edges ragged and darker at the rim, in `ink_colour`.
uniform bool ink = false;
uniform vec3 ink_colour : source_color = vec3(0.04, 0.035, 0.06);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float lod = amount * (softest + log2(max(lines, 1.0) / 1080.0));
	vec3 col = textureLod(screen, SCREEN_UV, lod).rgb;
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), 0.25 * amount) + vec3(0.04) * amount;
	if (ink) {
		// Ink where the blots still lie: they hold longest at the edges of the screen and in the noise's low places.
		vec2 q = (SCREEN_UV - 0.5) * vec2(1.6, 1.0);
		float blot = vnoise(SCREEN_UV * 6.0) * 0.6 + vnoise(SCREEN_UV * 17.0 + 3.1) * 0.25 + length(q) * 0.55;
		float edge = amount * 1.5 - 0.2;
		float covered = smoothstep(edge - 0.02, edge + 0.02, blot);
		float rim = smoothstep(edge - 0.08, edge - 0.01, blot) * (1.0 - covered);
		col = mix(col * (1.0 - rim * 0.6), ink_colour, covered);
	}
	COLOR = vec4(col, 1.0);
}
