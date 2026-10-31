// A soft ghost's first pass (ModelFigure, figure.gdshaderinc): its body's depth and nothing else, drawn before its
// blended surfaces and ink (lit_figure.gdshader and figure_ink.gdshader with soft_through), so they show only their
// nearest surface. Without it a see-through body shows its far arm and its back through its chest, in whatever order
// its triangles happen to draw.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_always, shadows_disabled, fog_disabled;
#include "res://addons/dnd_core/shaders/world/figure.gdshaderinc"

void fragment() {
	if (tint.a < 0.01) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
