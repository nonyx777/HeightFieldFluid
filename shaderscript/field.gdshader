shader_type spatial;
uniform sampler2D refractionTexture : hint_screen_texture, filter_nearest;
uniform sampler2D heightTexture;
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
    float h_center = texelFetch(heightTexture, ivec2(z * numxz + x, 0), 0).r;
	// Get height values for normal calculation
    float h_right = texelFetch(heightTexture, ivec2(z * numxz + clamp(x+1, 0, numxz-1), 0), 0).r;
    float h_up = texelFetch(heightTexture, ivec2(clamp(z+1, 0, numxz-1) * numxz + x, 0), 0).r;

    // Calculate surface vectors
    vec3 right = vec3(1.0, (h_right - h_center) * 5.0, 0.0);
    vec3 forward = vec3(0.0, (h_up - h_center) * 5.0, 1.0);
	
	NORMAL = normalize(cross(forward, right));

	VERTEX.y = h_center;
}
void fragment(){
	ALBEDO = texture(refractionTexture, SCREEN_UV).rgb * water_color;
}