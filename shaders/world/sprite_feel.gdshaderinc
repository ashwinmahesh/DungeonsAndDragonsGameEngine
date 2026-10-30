// Game feel on a figure (GameFeel, Visual Polish Plan E39 and E40; SpriteFeel sets these each frame): a flash when it
// is struck, and a sway in the place's wind that grows toward the top of the figure (cloaks, hair, a tall hat) while
// its feet stay planted. Both are off at their defaults, so a figure is drawn as it always was.
uniform float feel_flash = 0.0;
uniform vec4 feel_flash_colour : source_color = vec4(1.0);
// x: how far the top of the figure leans downwind across the screen (world units); y: the flutter on top of that.
uniform vec2 feel_sway = vec2(0.0);
// The figure's height (world units) and its own phase, so no two figures sway together.
uniform float feel_height = 1.5;
uniform float feel_phase = 0.0;

// `v`: a vertex of the flat figure, feet at y 0, after its squash and lean; `t`: the time.
vec3 feel_vertex(vec3 v, float t) {
	if (feel_sway.x == 0.0 && feel_sway.y == 0.0) {
		return v;
	}
	float k = clamp(v.y / max(feel_height, 0.1), 0.0, 1.2);
	float gust = 0.65 + 0.35 * sin(t * 1.3 + feel_phase);
	float flutter = sin(t * 3.7 + feel_phase * 2.0 + k * 2.2) * 0.6 + sin(t * 6.1 + feel_phase) * 0.4;
	v.x += k * k * (feel_sway.x * gust + feel_sway.y * flutter);
	return v;
}

// The figure's light of its own while it flashes: its colour gives way to the flash's.
vec3 feel_emission(vec3 emission) {
	return feel_flash > 0.0 ? mix(emission, feel_flash_colour.rgb, feel_flash) : emission;
}
