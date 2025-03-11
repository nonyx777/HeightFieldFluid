extends Node3D
@onready var waterBody: MeshInstance3D = $Water
#@onready var subViewport: SubViewport = $"../SubViewport"

var numz: int = 10
var numx: int = 10
var grid_size: int = numz * numx
var x_: NDArray = nd.ones(grid_size)
var z_: NDArray = nd.ones(grid_size)
var mesh: Mesh
var material: Material
var refractionTexture: Texture
var vertices: PackedVector3Array
var waterArray
var heightTexture: Texture
var image: Image

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
	for i in range(grid_size):
		var value = Color(height.get_float(i), 0, 0, 1)
		image.set_pixel(i, 0, value)
	heightTexture = ImageTexture.create_from_image(image)
	material.set_shader_parameter("heightTexture", heightTexture)

func _ready() -> void:
	#height.assign_multiply(height, 2)
	getInnerElements()
	height.set(0.4, 54)
	height.set(0.4, 22)
	height.set(0.4, 83)
	
	mesh = waterBody.mesh
	material = mesh.surface_get_material(0)
	#refractionTexture = subViewport.get_texture()
	#material.set_shader_parameter("refractionTexture", refractionTexture)
	
	waterArray = waterBody.mesh.surface_get_arrays(0)
	vertices = waterArray[ArrayMesh.ARRAY_VERTEX]
	image = Image.create(grid_size, 1, false, Image.FORMAT_RGBAF)

func _process(delta: float) -> void:
	adjustHeight(fixed_dt)
	adjustMeshHeight()
