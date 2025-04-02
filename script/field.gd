extends Node3D
@onready var waterBody: MeshInstance3D = $Water
@onready var mainCamera: Camera3D = $"../Camera3D"
@onready var ball1: MeshInstance3D = $Sphere1

@export var numz: int = 64
@export var numx: int = 64
@export var grid_size: int = numz * numx
var x_: NDArray = nd.ones(grid_size)
var z_: NDArray = nd.ones(grid_size)
var mesh: Mesh
var material: Material
var refractionTexture: Texture
var heightTexture: Texture
var image: Image
var sub_viewport: SubViewport
var count: int = 0
var time: float = 0.0
var ball1_radius: float = 0.0
var oscillate: float = 0.0
var ball_control: bool = true
@export var oscAmpl: float = 4.0
@export var oscFreq: float = 2.0

#fluid related
var fixed_dt: float = 0.09
var height: NDArray = nd.zeros(grid_size)
var velocity: NDArray = nd.zeros(grid_size)
var acceleration: NDArray = nd.zeros(grid_size)
var bcurr: NDArray = nd.zeros(grid_size)
var bprev: NDArray
var inner_elements: NDArray
@export var c: float = 0.0
@export var s: float = 0.0
@export var alpha: float = 0.15
@export var drag: float = 0.1

#gpu related
var rd: RenderingDevice
var shader: RID
var inner_elements_buffer: RID
var height_buffer: RID
var acceleration_buffer: RID
var constant_buffer: RID
var uniform_set: RID
var pipeline: RID
var compute_list
var height_byte_size: int

func getInnerElements() -> void:
	var full_matrix: NDArray = nd.linspace(0, grid_size - 1, grid_size)
	full_matrix = nd.reshape(full_matrix, [numx, numz])
	inner_elements = full_matrix.get(nd.range(1, -1), nd.range(1, -1))
	inner_elements = nd.hstack(inner_elements)

func adjustHeight(dt: float) -> void:
	#var j: int = -1
	#var icenter = 0.0
	#var iup = 0.0
	#var idown = 0.0
	#var iright = 0.0
	#var ileft = 0.0
	#for i in inner_elements:
		#j = i.get_int()
		#icenter = height.get_float(j)
		#iup = height.get_float(j+1)
		#idown = height.get_float(j-1)
		#iright = height.get_float(j+numz) # Or it can be numx
		#ileft = height.get_float(j-numz) # As long as they're equal
		#acceleration.set(((c*c)/(s*s)) * (iup + idown + iright + ileft - 4.0 * icenter), j)
	velocity.assign_add(velocity, nd.multiply(acceleration, dt))
	velocity.assign_multiply(velocity, 1.0 - drag * dt)
	height.assign_add(height, nd.multiply(velocity, dt))
	height.assign_add(height, nd.multiply(nd.subtract(bcurr, bprev), alpha))
	# Make the border elements have the same height value
	# as the inner elements' border
	#height = nd.reshape(height, [numx, numz])
	## top border
	#height.set(height.get(1, nd.range(1, -1)), 0, nd.range(1, -1))
	## bottom border
	#height.set(height.get(-2, nd.range(1, -1)), -1, nd.range(1, -1))
	## left border
	#height.set(height.get(nd.range(1, -1), 1), nd.range(1, -1), 0)
	## right border
	#height.set(height.get(nd.range(1, -1), -2), nd.range(1, -1), -1)
	#
	##back to 1d
	#height = nd.hstack(height)

func adjustMeshHeight() -> void:
	var value: Color
	for i in range(grid_size):
		value = Color(height.get_float(i), 0, 0, 1)
		image.set_pixel(i, 0, value)
	heightTexture = ImageTexture.create_from_image(image)
	material.set_shader_parameter("heightTexture", heightTexture)

func ballOccupation() -> void:
	bprev = bcurr.copy()
	bcurr.assign_multiply(bcurr, 0.0)
	# getting index of ball 1's position
	var x1: int = int((ball1.position.x + 5.0) / 10.0 * float(numx - 1))
	var z1: int = int((ball1.position.z + 5.0) / 10.0 * float(numz - 1))
	x1 = clamp(x1, 0, numx - 3)
	z1 = clamp(z1, 0, numz - 3)
	var index1: int = z1 * numz + x1
	
	# How much of ball 1 is inside the water
	bcurr.set(min(0.0, ball1.position.y + ball1_radius) - max(-2.0, ball1.position.y - ball1_radius), index1)
	bcurr.set(min(0.0, ball1.position.y + ball1_radius) - max(-2.0, ball1.position.y - ball1_radius), index1+1)
	bcurr.set(min(0.0, ball1.position.y + ball1_radius) - max(-2.0, ball1.position.y - ball1_radius), index1-1)
	bcurr.set(min(0.0, ball1.position.y + ball1_radius) - max(-2.0, ball1.position.y - ball1_radius), index1+numz)
	bcurr.set(min(0.0, ball1.position.y + ball1_radius) - max(-2.0, ball1.position.y - ball1_radius), index1-numz)

func moveBalls(delta: float) -> void:
	# Convert to radians at point of use
	var angle = deg_to_rad(oscillate)
	
	# Increase multipliers for visible movement
	ball1.position.x += cos(angle * oscFreq) * oscAmpl * delta
	ball1.position.z += sin(angle * oscFreq) * oscAmpl * delta

func setupComputeShader() -> void:
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://shaderscript/field.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	inner_elements_buffer = rd.storage_buffer_create(inner_elements.to_packed_int32_array().to_byte_array().size(), inner_elements.to_packed_int32_array().to_byte_array())
	height_buffer = rd.storage_buffer_create(height.to_packed_float32_array().to_byte_array().size(), height.to_packed_float32_array().to_byte_array())
	acceleration_buffer = rd.storage_buffer_create(acceleration.to_packed_float32_array().to_byte_array().size(), acceleration.to_packed_float32_array().to_byte_array())
	var constant_data := PackedByteArray()
	constant_data.resize(16)
	constant_data.encode_float(0, c)
	constant_data.encode_float(4, s)
	constant_buffer = rd.uniform_buffer_create(constant_data.size(), constant_data)
	var inner_elements_uniform := RDUniform.new()
	inner_elements_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	inner_elements_uniform.binding = 0
	inner_elements_uniform.add_id(inner_elements_buffer)
	var height_uniform := RDUniform.new()
	height_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	height_uniform.binding = 1
	height_uniform.add_id(height_buffer)
	var acceleration_uniform := RDUniform.new()
	acceleration_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	acceleration_uniform.binding = 2
	acceleration_uniform.add_id(acceleration_buffer)
	var constant_uniform := RDUniform.new()
	constant_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	constant_uniform.binding = 3
	constant_uniform.add_id(constant_buffer)
	
	uniform_set = rd.uniform_set_create([inner_elements_uniform, height_uniform, acceleration_uniform, constant_uniform], shader, 0)
	pipeline = rd.compute_pipeline_create(shader)

func _ready() -> void:
	mesh = waterBody.mesh
	material = mesh.surface_get_material(0)
	material.set_shader_parameter("numxz", numz);
	getInnerElements()
	image = Image.create(grid_size, 1, false, Image.FORMAT_RGBAF)
	s = waterBody.mesh.get_aabb().size[0] / numz # Make sure that width and depth are equal, and also numx and numz are equal as well
	c = 0.35
	ball1_radius = ball1.mesh.radius
	
	height_byte_size = height.to_packed_float32_array().to_byte_array().size()
	setupComputeShader()

func _process(delta: float) -> void:
	rd.buffer_update(height_buffer, 0, height_byte_size, height.to_packed_float32_array().to_byte_array())
	compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceil(inner_elements.size() / 64), 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	acceleration = nd.array(rd.buffer_get_data(acceleration_buffer).to_float32_array())
	
	ballOccupation()
	adjustHeight(fixed_dt)
	adjustMeshHeight()
	
	if Input.is_action_just_pressed("BallControl"):
		ball_control = !ball_control
	if ball_control:
		moveBalls(delta)
		oscillate += 90.0 * delta  # 90 degrees per second
		if oscillate >= 360.0:
			oscillate -= 360.0
