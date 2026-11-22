shader_type canvas_item;
// 80's mode: synthwave palette swap + CRT scanlines, chromatic aberration,
// vignette and faint VHS noise / tracking wobble.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float palette_mix : hint_range(0.0, 1.0) = 0.88;
uniform float aberration : hint_range(0.0, 0.01) = 0.0025;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.75;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.04;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 synth_ramp(float l) {
	vec3 c0 = vec3(0.04, 0.01, 0.14);  // deep indigo
	vec3 c1 = vec3(0.32, 0.06, 0.52);  // purple
	vec3 c2 = vec3(0.96, 0.10, 0.60);  // hot magenta
	vec3 c3 = vec3(1.00, 0.55, 0.14);  // orange
	vec3 c4 = vec3(0.35, 1.00, 1.00);  // cyan highlight
	if (l < 0.25) return mix(c0, c1, l / 0.25);
	if (l < 0.5) return mix(c1, c2, (l - 0.25) / 0.25);
	if (l < 0.75) return mix(c2, c3, (l - 0.5) / 0.25);
	return mix(c3, c4, clamp((l - 0.75) / 0.25, 0.0, 1.0));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// VHS tracking wobble: gentle waves plus an occasional torn band.
	float band = step(0.992, sin(uv.y * 2.5 + TIME * 0.6));
	uv.x += sin(uv.y * 60.0 + TIME * 3.0) * 0.0005 + band * sin(TIME * 30.0) * 0.004;
	vec2 off = (uv - 0.5) * aberration * 2.0;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	lum = clamp(pow(lum, 0.85) * 1.15, 0.0, 1.0);
	vec3 mapped = synth_ramp(lum);
	col = mix(col, mapped, palette_mix);
	// Scanlines (per screen pixel).
	col *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	// Noise.
	col += (hash(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5) * noise_strength;
	// Vignette.
	float v = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - smoothstep(0.35, 0.85, v) * vignette_strength;
	COLOR = vec4(col, 1.0);
}
