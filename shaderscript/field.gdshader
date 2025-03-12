shader_type spatial;
//uniform sampler2D refractionTexture : source_color;
uniform sampler2D heightTexture;
uniform sampler2D normalmap;
uniform int numxz;
//
//varying vec3 ndc;
varying vec2 tex_coords;

void vertex() {
	//vec4 clip_space = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	//ndc = clip_space.xyz / clip_space.w;
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

    // Apply height to vertex
	VERTEX.y = height;
}
void fragment(){
	//vec2 screen_space = vec2(ndc.x / 2.0 + 0.5, ndc.y / 2.0 + 0.5);
	//ALBEDO = texture(refractionTexture, screen_space).rgb;
	NORMAL = texture(normalmap, tex_coords).xyz;
}