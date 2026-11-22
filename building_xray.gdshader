shader_type canvas_item;
// Cuts a soft see-through circle in building slices around the player, so
// they stay visible while walking behind a tall building. `active` is faded
// in/out by main.gd only while the player is actually in the occluded band.

global uniform vec2 player_pos;

uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform float hole_radius = 105.0;
uniform float feather = 55.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float dist = distance(world_pos, player_pos);
	float cut = (1.0 - smoothstep(hole_radius, hole_radius + feather, dist)) * active;
	COLOR.a *= 1.0 - cut;
}
