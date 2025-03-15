shader_type spatial;
uniform sampler2D refractionTexture : hint_screen_texture, filter_nearest;
uniform sampler2D heightTexture;
uniform sampler2D normalmap;
uniform int numxz;

varying vec2 tex_coords;

const vec3 water_color = vec3(0.0, 0.5, 0.7);

void vertex() {
	tex_coords = (VERTEX.xz + 10.0) + 20.0;
	vec4 vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
	int z = int((vertex.z + 5.0) / 10.0 * float(numxz - 1));// Scale based on plane size
    int x = int((vertex.x + 5.0) / 10.0 * float(numxz - 1));

    // Ensure indices are within bounds
    x = clamp(x, 0, numxz - 1);
    z = clamp(z, 0, numxz - 1);
    // Convert 2D grid index into 1D texture index
    int index = z * numxz + x;

    // Sample height from the texture
    vec4 data = texelFetch(heightTexture, ivec2(index, 0), 0);
    float height = data.r;

	VERTEX.y = height;
}
void fragment(){
	ALBEDO = texture(refractionTexture, SCREEN_UV).rgb * water_color;
	//NORMAL = texture(normalmap, tex_coords).xyz;
}