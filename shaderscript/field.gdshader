shader_type spatial;

void vertex() {
	float height = INSTANCE_CUSTOM.r;
	if (VERTEX.y > 0.0){
		VERTEX.y = height;
	}
}
