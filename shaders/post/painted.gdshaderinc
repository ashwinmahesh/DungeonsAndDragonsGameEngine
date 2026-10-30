// The painted finish and other polish for the screen pass (Crooked Moon's Visual Polish Plan, E32-E36; a prototype,
// every effect off by default so a game that sets none of these uniforms looks as it did). Included by
// screen_pass.gdshader after its helpers (vnoise, ground_at, normal_at, to_srgb, the mist mask), which it uses.

// --- The painted finish (Visual Polish Plan V1-V3, a prototype; all off by default) ---
// The world as a painted background under inked cel characters (the characters draw after this pass, so they stay
// crisp): a sector filter (generalised Kuwahara, 8 sectors) presses detail into flat strokes of paint `paint_radius`
// pixels long at 1080 lines; `paint_sharpness` is how strongly the calmest sector wins, so edges stay crisp.
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float paint_radius = 4.0;
uniform float paint_sharpness = 600.0;
// The picture's values painted in `paint_steps` flat steps (0 = smooth), each step's edge `paint_step_edge` soft,
// then coloured through the place's paint ramp (darkest left, lightest right; sRGB, read raw) by `paint_ramp_amount`,
// keeping `paint_keep_hue` of each surface's own hue. Warm or strongly coloured light keeps its colour
// (`paint_keep_light`), so lantern pools stay lanterns. Below `paint_black` the shade goes to ink (`paint_ink`).
uniform sampler2D paint_ramp : filter_linear, repeat_disable;
uniform float paint_ramp_amount : hint_range(0.0, 1.0) = 0.0;
uniform float paint_steps = 5.0;
uniform float paint_step_edge : hint_range(0.0, 0.5) = 0.18;
uniform float paint_keep_hue : hint_range(0.0, 1.0) = 0.3;
uniform float paint_keep_light : hint_range(0.0, 1.0) = 1.0;
uniform float paint_black : hint_range(0.0, 0.5) = 0.0;
uniform vec3 paint_ink : source_color = vec3(0.04, 0.035, 0.06);
// Dry brush: stroke-shaped noise fixed to the world (never the screen, so it doesn't swim as the camera moves) that
// breaks the steps' edges and streaks the flat fills (strength, strokes per world unit).
uniform float paint_brush : hint_range(0.0, 1.0) = 0.0;
uniform float paint_brush_scale = 1.4;
// Pigment pooling: paint darkens along the edges where one value meets another (gouache and watercolour).
uniform float paint_edges : hint_range(0.0, 1.0) = 0.0;
// Ink drawn from the picture itself (a difference of blurs): broken, brushy dark lines along value edges, fading
// with distance, for a world inked by hand rather than by its geometry.
uniform float paint_lines : hint_range(0.0, 1.0) = 0.0;

// --- Branch shadows (V5): the shadows of boughs overhead thrown across the ground by the moon, swaying ---
// A silhouette texture of branches laid on a canopy `branch_height` above the ground and projected down along the
// light (`branch_light`, the way the light travels), repeating every 1 / branch_scale units, swaying in the wind.
// Where it falls follows mist_mask (by the trees) when use_branch_mask is on.
uniform float branch_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D branch_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 branch_light = vec3(-0.35, -0.85, -0.4);
uniform float branch_height = 7.0;
uniform float branch_scale = 0.05;
uniform float branch_sway = 0.12;
uniform bool use_branch_mask = false;

// --- The moon on the water (V8): the moon mirrored in any water on screen, though the sky itself rarely shows ---
// `moon_water_dir` is the direction to the moon the water reflects (a game aims it so the reflection lands on the
// water in view); its angular radius, a crescent's bite (0 a full moon), the ripples' share of the surface normal.
uniform float moon_water : hint_range(0.0, 3.0) = 0.0;
uniform vec3 moon_water_dir = vec3(0.0, 0.5, -0.86);
uniform float moon_water_size = 0.09;
uniform float moon_water_bite = 0.6;
uniform float moon_water_ripple = 0.35;
uniform vec3 moon_water_colour : source_color = vec3(0.78, 0.95, 0.62);

// --- Lightning's silhouette flash (V12): for an instant the world is a cut-out, pale lit faces and ink shade ---
uniform float flash_silhouette : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_colour : source_color = vec3(0.86, 0.9, 1.0);
uniform float flash_pivot = 0.3;

// The painted finish's sector filter (generalised Kuwahara, Papari et al.; 8 sectors of 6 taps round the centre): each
// sector's mean, weighted by how calm (low variance) it is, so flat fills take over textures while edges stay sharp.
// Worked in a square-root space (close to the eye's) and capped, so a flame's HDR doesn't flood its neighbours.
vec3 paint_filter(vec2 uv, vec2 vp) {
	float r = paint_radius * max(vp.y / 1080.0, 1.0);
	vec2 px = 1.0 / vp;
	vec3 c0 = sqrt(clamp(texture(screen_tex, uv).rgb, 0.0, 4.0));
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int k = 0; k < 8; k++) {
		vec3 m = c0;
		vec3 m2 = c0 * c0;
		for (int j = 0; j < 6; j++) {
			float a = (float(k) + float(j % 2) * 0.5 + 0.25) * 0.785398;
			float rr = r * (float(j / 2) + 1.0) / 3.0;
			vec3 c = sqrt(clamp(texture(screen_tex, uv + vec2(cos(a), sin(a)) * rr * px).rgb, 0.0, 4.0));
			m += c;
			m2 += c * c;
		}
		m /= 7.0;
		vec3 v = abs(m2 / 7.0 - m * m);
		float s = (v.r + v.g + v.b) * paint_sharpness;
		float w = 1.0 / (1.0 + s * s * s * s);
		acc += m * w;
		wsum += w;
	}
	vec3 o = acc / max(wsum, 1e-20);
	return o * o;
}

// Dry-brush strokes fixed to the world: the ground takes them on its plane, walls on theirs. About -0.6..0.6.
float brush_noise(vec3 p, vec3 wn) {
	vec2 q = abs(wn.y) > 0.6 ? p.xz : (abs(wn.x) > abs(wn.z) ? p.zy : p.xy);
	q *= paint_brush_scale;
	vec2 d = vec2(0.8, 0.6);
	vec2 s = vec2(dot(q, d) * 0.7, dot(q, vec2(-d.y, d.x)) * 5.0);
	float n = vnoise(s) * 0.6 + vnoise(s * 2.13 + 3.7) * 0.4;
	float big = vnoise(q * 0.45 + 11.0);
	return (n - 0.5) * 0.8 + (big - 0.5) * 0.7;
}

// Flat steps of value with soft edges.
float paint_step(float x, float n, float edge) {
	if (n < 1.0) {
		return x;
	}
	float y = x * n;
	return (floor(y) + smoothstep(0.5 - edge, 0.5 + edge, fract(y))) / n;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// The hooks screen_pass.gdshader calls; each returns its input untouched while its effect is off.

// The strokes (V1), on the world's linear colour before the grade: characters draw after this pass, so they stay crisp.
vec3 painted_strokes(vec3 lin_in, vec2 uv, vec2 vp) {
	if (paint_amount <= 0.0 || texture(depth_tex, uv).r <= 0.0) {
		return lin_in;
	}
	return mix(lin_in, paint_filter(uv, vp), paint_amount);
}

// Boughs overhead (V5): the point on the canopy the light passed through on its way here, swaying in the wind; the
// further the canopy is above the ground, the softer its shadow.
vec3 bough_shadows(vec3 col, vec3 wpos) {
	if (branch_strength <= 0.0) {
		return col;
	}
	vec3 L = normalize(branch_light);
	float t = max(branch_height + ground_at(wpos.xz) - wpos.y, 0.0) / max(-L.y, 0.05);
	vec2 cp2 = wpos.xz - L.xz * t;
	vec2 sway = vec2(vnoise(cp2 * 0.15 + vec2(atmo_time * 0.35, 0.0)), vnoise(cp2 * 0.15 + vec2(3.1, atmo_time * 0.3))) - 0.5;
	float lod = clamp(t * 0.22 - 0.4, 0.0, 4.0);
	float sh = 1.0 - textureLod(branch_tex, cp2 * branch_scale + sway * branch_sway, lod).r;
	float k = smoothstep(0.03, 0.25, luma(col));
	if (use_branch_mask && use_mist_mask && land_rect.z > land_rect.x) {
		k *= smoothstep(0.1, 0.55, texture(mist_mask, (wpos.xz - land_rect.xy) / (land_rect.zw - land_rect.xy)).r);
	}
	return col * (1.0 - branch_strength * sh * k);
}

// The painted values (V2): brightness in a few flat steps whose edges the dry brush breaks, coloured through the
// place's ramp; warm and strongly coloured light keeps its own colour; the deepest shade is ink. `wn` is the world
// normal behind the pixel.
vec3 painted_values(vec3 col, vec3 wpos, vec3 wn) {
	if (paint_ramp_amount <= 0.0) {
		return col;
	}
	float b = brush_noise(wpos, wn) * paint_brush;
	float l0 = luma(col);
	float chroma = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	float warm = smoothstep(0.03, 0.12, col.r - col.b) * smoothstep(0.12, 0.3, l0);
	float keep = max(smoothstep(0.18, 0.4, chroma), warm) * paint_keep_light;
	float v = paint_step(clamp(l0 + b * 0.12, 0.0, 1.0), paint_steps, paint_step_edge);
	vec3 ramp = texture(paint_ramp, vec2(clamp(v, 0.01, 0.99), 0.5)).rgb;
	vec3 own = col * (luma(ramp) / max(l0, 0.02));
	vec3 pc = mix(ramp, own, paint_keep_hue) * (1.0 + b * 0.25);
	col = mix(col, pc, paint_ramp_amount * (1.0 - keep));
	if (paint_black > 0.0) {
		float inked = 1.0 - smoothstep(paint_black * 0.7, paint_black * 1.15, l0 + b * 0.05);
		col = mix(col, to_srgb(paint_ink), inked * (1.0 - keep));
	}
	return col;
}

// Pigment pooling where values meet (V3), and ink lines drawn from the picture's own edges (a difference of blurs),
// broken by the dry brush and fading into the distance. `depth` is the linear depth behind the pixel.
vec3 painted_edges(vec3 col, vec2 uv, vec3 wpos, vec3 wn, float depth) {
	if (paint_edges <= 0.0 && paint_lines <= 0.0) {
		return col;
	}
	float near_k = 1.0 - smoothstep(25.0, 60.0, depth);
	float lA = sqrt(luma(textureLod(blur_tex, uv, 0.0).rgb));
	float lB = sqrt(luma(textureLod(blur_tex, uv, 1.5).rgb));
	float lC = sqrt(luma(textureLod(blur_tex, uv, 3.0).rgb));
	col *= 1.0 - paint_edges * smoothstep(0.02, 0.14, abs(lC - lA)) * 0.5 * near_k;
	if (paint_lines > 0.0) {
		float line_ = smoothstep(0.012, 0.05, 0.98 * lC - lB);
		line_ *= smoothstep(-0.25, 0.15, brush_noise(wpos * 1.9, wn) + 0.1);
		col = mix(col, to_srgb(paint_ink), line_ * paint_lines * near_k);
	}
	return col;
}

// The moon in the water (V8): the view mirrored off the rippled surface; near the moon's direction a crescent and its
// halo, broken up by the ripples into a shimmering column. Only on water (own-colour pixels).
vec3 moon_on_water(vec3 col, vec3 wpos, vec3 cam, vec3 wn) {
	if (moon_water <= 0.0) {
		return col;
	}
	vec3 n3 = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(wn), moon_water_ripple));
	vec3 r = reflect(normalize(wpos - cam), n3);
	vec3 m = normalize(moon_water_dir);
	vec3 right = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
	vec3 up2 = cross(right, m);
	vec2 q = vec2(dot(r, right), dot(r, up2)) / moon_water_size;
	float lq = length(q);
	float disc = 1.0 - smoothstep(0.92, 1.0, lq);
	float bite = moon_water_bite > 0.01 ? 1.0 - smoothstep(0.9, 1.0, length(q - vec2(moon_water_bite * 0.85, 0.3))) : 0.0;
	float halo = exp(-lq * lq * 0.35) * 0.35;
	return col + to_srgb(moon_water_colour) * (disc * (1.0 - bite) + halo) * moon_water * step(0.0, dot(r, m));
}

// Lightning's cut-out (V12): lit faces go pale, everything else ink, the sky white.
vec3 flash_cutout(vec3 col, bool empty) {
	if (flash_silhouette <= 0.0) {
		return col;
	}
	float lit = empty ? 1.0 : smoothstep(flash_pivot * 0.85, flash_pivot * 1.15, luma(col));
	return mix(col, mix(to_srgb(paint_ink), to_srgb(flash_colour) * mix(0.8, 1.0, luma(col)), lit), flash_silhouette);
}
