// An impact frame (GameFeel, after the AI methods report's FX2 and AN1): for a frame or two on a critical hit or a
// killing blow the picture is only ink and paper, cut at `cut` brightness, the first half of it inverted (the light
// goes to ink), as an anime cel does on a blow that lands. Drawn over the world on its own layer (ImpactFrame), under
// the HUD; costs nothing between blows (the layer is hidden).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 ink : source_color = vec4(0.071, 0.055, 0.094, 1.0);
uniform vec4 paper : source_color = vec4(0.93, 0.88, 0.76, 1.0);
// The brightness that splits ink from paper, against the picture's own average (a dark night still splits).
uniform float cut = 0.5;
uniform bool invert = true;
// Where the blow landed (0..1 on the screen): speed lines run out from it.
uniform vec2 centre = vec2(0.5);
uniform float aspect = 1.78;
uniform float lines = 0.6;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 avg = textureLod(screen, vec2(0.5), 10.0).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float mean = max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.02);
	float t = step(mean * (0.6 + cut), l);
	// Speed lines: thin wedges out from the blow, more of them further out.
	vec2 d = (SCREEN_UV - centre) * vec2(aspect, 1.0);
	float ang = atan(d.y, d.x);
	float r = length(d);
	float wedge = step(0.92, fract(sin(floor(ang * 38.0) * 91.7) * 4375.85));
	t = max(t, wedge * lines * smoothstep(0.25, 0.7, r));
	if (invert) {
		t = 1.0 - t;
	}
	COLOR = vec4(mix(ink.rgb, paper.rgb, t), 1.0);
}
