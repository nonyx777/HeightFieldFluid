#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict readonly buffer InnerElements {
	int data[];
}
inner_elements;
layout(set = 0, binding = 1, std430) restrict readonly buffer Height {
	float data[];
}
height;
layout(set = 0, binding = 2, std430) restrict writeonly buffer Acceleration {
	float data[];
}
acceleration;

/*layout(set = 0, binding = 3, std140) uniform Constants {
	float c;
	float s;
};*/

void main(){
	int gidx = int(gl_GlobalInvocationID.x);
	if (gidx >= inner_elements.data.length())
		return;

	int index = inner_elements.data[gidx];
	float v_center = height.data[index];
	float v_up = height.data[index+1];
	float v_down = height.data[index-1];
	float v_right = height.data[index+64];
	float v_left = height.data[index-64];

	acceleration.data[index] = (0.5 * 0.5)/(0.15625 * 0.15625) * (v_up + v_down + v_right + v_left - 4.0 * v_center);
}
