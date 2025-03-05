extends Node3D
@onready var meshInstance: MeshInstance3D = $Fluid
@onready var multimeshInstance: MultiMeshInstance3D = $MultiMeshInstance3D
var numz: int = 10
var numx: int = 10
var grid_size: int = numz * numx
var x_: NDArray = nd.ones(grid_size)
var z_: NDArray = nd.ones(grid_size)

func alignFluids() -> void:
	var multimesh = multimeshInstance.multimesh	
	#x = i / numz
	var prog: NDArray = nd.arange(0, 99, 100)
	x_.assign_divide(prog, numz)
	# % operator
	#z = i % numz
	z_.assign_subtract(prog, nd.multiply(numz, nd.floor(nd.divide(prog, numz)))).as_type(nd.Int16)
	for i in range(grid_size):
		var transform_instance = multimesh.get_instance_transform(i)
		transform_instance.origin = Vector3(x_.get_int(i)-5, 0, z_.get_int(i)-5)
		multimesh.set_instance_transform(i, transform_instance)
	multimeshInstance.multimesh = multimesh

func _ready() -> void:
	alignFluids()
