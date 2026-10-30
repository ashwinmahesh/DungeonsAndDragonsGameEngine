// A drawn effect shape (FxShapes, after the AI methods report's FX1): a slash crescent, burst star, ink splash, speed
// lines or a sigil, flat-coloured like a cel: the shape's solid middle in the flavour's hot colour, its body in the
// glow colour and an ink line round it, eaten away from its thin parts as it ends. `life` steps on twos (FxShapes sets
// it at its own frame rate), and each step the shape boils: its edge shifts a little, as hand-drawn frames do.
// Faces the camera, turned by `spin`. Drawn with the effects (render priority), over the figures.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D shape_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 fill : source_color = vec4(1.0);
uniform vec4 body : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4 ink : source_color = vec4(0.071, 0.055, 0.094, 1.0);
// 0 as it appears, 1 gone.
uniform float life = 0.0;
// The step it's on (changes each drawn frame), for the boil.
uniform float step_no = 0.0;
uniform float spin = 0.0;
uniform float ink_px = 0.035;
uniform float boil = 0.012;
// Brightness of the coloured parts (the ink stays ink), so they bloom like the other effects.
uniform float energy = 1.0;

void vertex() {
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mat4 turn = mat4(vec4(cos(spin), -sin(spin), 0.0, 0.0), vec4(sin(spin), cos(spin), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * turn * mat4(vec4(sx, 0.0, 0.0, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

float shape_at(vec2 uv) {
	return texture(shape_tex, clamp(uv, vec2(0.0), vec2(1.0))).a;
}

void fragment() {
	vec2 j = vec2(fract(sin(step_no * 12.9898) * 43758.5453), fract(sin(step_no * 78.233) * 12543.123)) - 0.5;
	vec2 uv = UV + j * boil;
	float a = shape_at(uv);
	// The ink: anything the shape covers within ink_px of here that this point doesn't.
	float near = 0.0;
	for (int k = 0; k < 8; k++) {
		float ang = float(k) * 0.785398;
		near = max(near, shape_at(uv + vec2(cos(ang), sin(ang)) * ink_px));
	}
	// Ending: the thin parts go first (a raised cut on the shape's own soft alpha).
	float cut = mix(0.08, 0.95, smoothstep(0.45, 1.0, life));
	float solid = step(cut, a);
	float edge = step(cut, near) * (1.0 - solid);
	float hot = step(mix(0.75, 1.0, life), a);
	vec3 col = mix(body.rgb, fill.rgb, hot) * energy;
	ALBEDO = mix(col, ink.rgb, edge);
	ALPHA = max(solid, edge);
}
