// An impact frame (GameFeel, after the AI methods report's FX2 and AN1): for a frame or two on a critical hit or a
// killing blow the picture is only ink and paper, cut at `cut` brightness, the first half of it inverted (the light
// goes to ink, the night to paper), as an anime cel does on a blow that lands. Drawn over the world on its own layer (ImpactFrame), under
// the HUD; costs nothing between blows (the layer is hidden).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec4 ink : source_color = vec4(0.071, 0.055, 0.094, 1.0);
uniform vec4 paper : source_color = vec4(0.93, 0.88, 0.76, 1.0);
// The brightness (0 to 1 on the screen) that splits ink from paper: lit figures, flames and the blow's flash go one
// way, the night the other.
uniform float cut = 0.22;
uniform bool invert = true;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float t = step(cut, dot(c, vec3(0.299, 0.587, 0.114)));
	if (invert) {
		t = 1.0 - t;
	}
	COLOR = vec4(mix(ink.rgb, paper.rgb, t), 1.0);
}
