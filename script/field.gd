extends Node3D
@onready var meshInstance: MeshInstance3D = $Fluid
@onready var multimeshInstance: MultiMeshInstance3D = $MultiMeshInstance3D
var numz: int = 10
var numx: int = 10
var grid_size: int = numz * numx
var x_: NDArray = nd.ones(grid_size)
var z_: NDArray = nd.ones(grid_size)
var multimesh: MultiMesh

#fluid related
var fixed_dt: float = 0.05
var height: NDArray = nd.ones(grid_size)
var velocity: NDArray = nd.zeros(grid_size)
var acceleration: NDArray = nd.zeros(grid_size)
var inner_elements: NDArray
@export var c: float = 0.9
var s: float = 1

func getInnerElements() -> void:
	var full_matrix: NDArray = nd.linspace(0, 99, 100)
	full_matrix = nd.reshape(full_matrix, [numx, numz])
	inner_elements = full_matrix.get(nd.range(1, -1), nd.range(1, -1))
	inner_elements = nd.hstack(inner_elements)

func instantiateMultiMesh() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var target_mesh: Mesh = meshInstance.mesh
	multimesh.mesh = target_mesh
	multimesh.instance_count = grid_size
	for i in range(grid_size):
		var transform_ = Transform3D()
		transform_.origin = Vector3(0 ,0, 0)
		multimesh.set_instance_transform(i, transform_)
	multimeshInstance.multimesh = multimesh

func alignFluids() -> void:
	#x = i / numz
	var prog: NDArray = nd.arange(0, 99, 100)
	x_.assign_divide(prog, numz)
	#z = i % numz
	z_.assign_subtract(prog, nd.multiply(numz, nd.floor(nd.divide(prog, numz)))).as_type(nd.Int16)
	for i in range(grid_size):
		var transform_instance = multimesh.get_instance_transform(i)
		transform_instance.origin = Vector3(x_.get_int(i)-5, 0, z_.get_int(i)-5)
		multimesh.set_instance_transform(i, transform_instance)
	multimeshInstance.multimesh = multimesh

func convertIntoIndex(i, j, numy) -> int:
	return i * numy + j
	
func adjustHeight(dt: float) -> void:
	var icenter = 0.0
	var iup = 0.0
	var idown = 0.0
	var iright = 0.0
	var ileft = 0.0
	for i in inner_elements:
		var j = i.get_int()
		icenter = height.get_float(j)
		iup = height.get_float(j+1)
		idown = height.get_float(j-1)
		iright = height.get_float(j+10)
		ileft = height.get_float(j-10)
		acceleration.set(((c*c)/(s*s)) * (iup + idown + iright + ileft - 4.0 * icenter), j)
	velocity.assign_add(velocity, nd.multiply(acceleration, dt))
	height.assign_add(height, nd.multiply(velocity, dt))

func adjustMeshHeight() -> void:
	var h: float = 0.0
	var data: Color = Color(0, 0, 0, 0)
	for i in range(grid_size):
		h = height.get_float(i)
		data = Color(h, h, h, 1.0)
		multimesh.set_instance_custom_data(i, data)

func _ready() -> void:
	instantiateMultiMesh()
	getInnerElements()
	alignFluids()
	height.set(0.4, 54)

func _process(delta: float) -> void:
	adjustHeight(fixed_dt)
	adjustMeshHeight()
