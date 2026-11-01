shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// What a window pane shows of a moving place's outside (WindowView): three banks of smoke streaming past at their own
// speeds, the far one slowest, so the panes read as a view out of a moving carriage. Drawn over the window's own
// glass decal; `mask` is that decal's picture, and only its lighter pixels (the glass, not the dark frame and bars)
// show the view.

uniform sampler2D mask : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_mask = true;
uniform vec4 mask_region = vec4(0.0, 0.0, 1.0, 1.0);   // the decal's region of `mask`, as UV x, y, width, height
uniform vec2 extent = vec2(0.5, 0.8);                    // the pane's size in world units, so the smoke keeps its scale
uniform float scroll = -1.0;                             // world units a second along the pane's right; its sign is the way
uniform float rise = 0.05;                               // the smoke's slow drift upward
uniform float strength : hint_range(0.0, 1.0) = 0.9;
uniform vec3 deep : source_color = vec3(0.06, 0.12, 0.11);
uniform vec3 mid : source_color = vec3(0.3, 0.64, 0.6);
uniform vec3 light : source_color = vec3(0.62, 0.88, 0.72);
uniform float glass_from = 0.1;                          // the decal's luminance where glass begins (bars below it)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = vec2(UV.x * extent.x, (1.0 - UV.y) * extent.y);
	// Far, middle and near banks: the nearer, the faster and the larger its billows.
	float far = fbm(p * 2.2 - vec2(TIME * scroll * 0.25, TIME * rise * 0.5));
	float middle = fbm(p * 1.4 + vec2(31.0, 7.0) - vec2(TIME * scroll * 0.6, TIME * rise));
	float near = fbm(p * 0.9 + vec2(63.0, 19.0) - vec2(TIME * scroll * 1.4, TIME * rise * 1.5));
	vec3 col = deep;
	col = mix(col, mid * 0.75, smoothstep(0.42, 0.75, far) * 0.7);
	col = mix(col, mid, smoothstep(0.45, 0.8, middle) * 0.8);
	col = mix(col, light, smoothstep(0.55, 0.85, near) * 0.65);
	// A darker sill and lintel: the view sits behind the frame.
	col *= mix(0.7, 1.0, smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y));
	float glass = 1.0;
	if (use_mask) {
		vec4 m = texture(mask, mask_region.xy + UV * mask_region.zw);
		float lum = dot(m.rgb, vec3(0.299, 0.587, 0.114));
		glass = smoothstep(glass_from, glass_from + 0.18, lum) * step(0.5, m.a);
	}
	ALBEDO = col;
	ALPHA = strength * glass;
}
