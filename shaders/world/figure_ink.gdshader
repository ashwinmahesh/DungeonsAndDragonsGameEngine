// A 3D figure's ink line (ModelFigure; the next pass of lit_figure.gdshader): its back faces pushed out along their
// normals by `width` screen pixels at 1080 lines (as many more on a bigger screen), drawn in the ink colour behind the
// figure, so a line runs round its silhouette at any zoom, as the 2D figures' own ink does (sprite_crisp.gdshader).
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_always, shadows_disabled, fog_disabled;
#include "res://addons/dnd_core/shaders/world/figure.gdshaderinc"

uniform vec3 ink : source_color = vec3(0.051, 0.039, 0.071);
uniform float width = 1.6;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float l = length(dir);
	if (l > 1e-5) {
		dir /= l;
		dir.x *= VIEWPORT_SIZE.y / VIEWPORT_SIZE.x;
		clip.xy += dir * (2.0 * width / 1080.0) * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	if (figure_hidden(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = ink * (1.0 - ghost * 0.6);
	ALPHA = 1.0;
}
