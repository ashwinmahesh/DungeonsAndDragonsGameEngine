// What a 3D figure's two passes share (ModelFigure: lit_figure.gdshader and its ink, figure_ink.gdshader): the figure's
// own state, set per figure as instance uniforms (GeometryInstance3D.set_instance_shader_parameter) so every copy of a
// model shares its materials. `tint` is the figure's modulate as CombatToken sets it (rgb a tint, a how much of it
// shows: a foe stepping out of the dark, the dead fading, a hero who is Invisible), `flash` the white of a struck
// figure (GameFeel's flash), `glow` how much of its colours it shows whatever the lights (a figure that is its own
// light), `ghost` how far it is washed to a translucent grey (an Echo Knight's echo).
instance uniform vec4 tint = vec4(1.0);
instance uniform float flash = 0.0;
instance uniform float glow = 0.0;
instance uniform float ghost = 0.0;

// A figure only part there is drawn through a screen-door pattern (a 4x4 ordered dither) rather than blended: it stays in
// the opaque pass, so it keeps its depth, its outline and its shadow, and nothing behind it sorts wrongly.
bool figure_hidden(vec2 frag) {
	if (tint.a >= 0.999) {
		return false;
	}
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	const float M[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return tint.a <= (M[y * 4 + x] + 0.5) / 16.0;
}
