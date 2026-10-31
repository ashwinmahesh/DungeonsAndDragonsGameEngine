// What a 3D figure's two passes share (ModelFigure: lit_figure.gdshader and its ink, figure_ink.gdshader): the figure's
// own state, set per figure as instance uniforms (GeometryInstance3D.set_instance_shader_parameter) so every copy of a
// model shares its materials. `tint` is the figure's modulate as CombatToken sets it (rgb a tint, a how much of it
// shows: a foe stepping out of the dark, the dead fading, a hero who is Invisible), `flash` the white of a struck
// figure (GameFeel's flash), `glow` how much of its colours it shows whatever the lights (a figure that is its own
// light), `ghost` how far it is washed to a translucent grey (an Echo Knight's echo). A ghost's look (ModelFigure.
// set_ghost_look, a manifest entry's "ghost"): `ghost_colour` the wash and rim's colour in place of the material's grey
// (used when its alpha is above 0), `see_through` the share of the figure the world shows through, `ghost_rim` a glow
// along its edges, `pulse` how far its glow throbs.
instance uniform vec4 tint = vec4(1.0);
instance uniform float flash = 0.0;
instance uniform float glow = 0.0;
instance uniform float ghost = 0.0;
instance uniform vec4 ghost_colour = vec4(0.0);
instance uniform float see_through = 0.0;
instance uniform float ghost_rim = 0.0;
instance uniform float pulse = 0.0;

// A figure only part there is drawn through a screen-door pattern (a 4x4 ordered dither) rather than blended: it stays in
// the opaque pass, so it keeps its depth, its outline and its shadow, and nothing behind it sorts wrongly. A ghost seen
// through is the same: both passes leave out the same pixels, so the world shows through its body and its ink alike.
bool figure_hidden(vec2 frag) {
	float shown = tint.a * (1.0 - clamp(see_through, 0.0, 0.95));
	if (shown >= 0.999) {
		return false;
	}
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	const float M[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return shown <= (M[y * 4 + x] + 0.5) / 16.0;
}

// The ghost's colour: its own when it has one, else `fallback` (the material's grey).
vec3 figure_ghost_colour(vec3 fallback) {
	return ghost_colour.a > 0.0 ? ghost_colour.rgb : fallback;
}

// How much of its glow the figure shows at `world` this moment: a ghost's throbs (`pulse`), each out of step with the
// next by where it stands.
float figure_glow(vec3 world) {
	return glow * (1.0 + pulse * sin(TIME * 2.4 + world.x * 1.7 + world.z * 2.3));
}
