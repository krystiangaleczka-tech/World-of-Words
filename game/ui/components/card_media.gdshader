shader_type canvas_item;
uniform bool desaturated = false;
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float gray = (source.r + source.g + source.b) / 3.0;
	COLOR = vec4(desaturated ? vec3(gray) : source.rgb, source.a);
}
