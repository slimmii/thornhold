class_name BlockLighting
extends RefCounted
## A small, static light volume. R = skylight, G = torchlight, both 0..15.
const MAX_LEVEL = 15
const TORCH_LEVEL = 14
const STEP = 0.8
const NEIGHBORS = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]
var origin: Vector3
var size: Vector3i
var solid = PackedByteArray()
var sky = PackedByteArray()
var torch = PackedByteArray()
var texture: ImageTexture3D

func _init(grid_origin: Vector3 = Vector3(-8.4, -0.4, -8.4), grid_size: Vector3i = Vector3i(98, 24, 98)) -> void:
	origin = grid_origin
	size = grid_size
	var count = size.x * size.y * size.z
	solid.resize(count)
	sky.resize(count)
	torch.resize(count)

func inside(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < size.x and cell.y < size.y and cell.z < size.z

func index(cell: Vector3i) -> int:
	return cell.x + size.x * (cell.y + size.y * cell.z)

func cell_at(point: Vector3) -> Vector3i:
	return Vector3i(((point - origin) / STEP).floor())

func center(cell: Vector3i) -> Vector3:
	return origin + (Vector3(cell) + Vector3.ONE * 0.5) * STEP

func add_box(bounds: AABB) -> void:
	rasterize(bounds, Transform3D.IDENTITY, null)

func add_mesh(transform: Transform3D, mesh: Mesh) -> void:
	rasterize(transform * mesh.get_aabb(), transform.affine_inverse(), mesh)

func rasterize(bounds: AABB, inverse: Transform3D, mesh: Mesh) -> void:
	var lower = Vector3i(((bounds.position - origin) / STEP - Vector3.ONE * 0.5).ceil()).max(Vector3i.ZERO)
	var upper = Vector3i(((bounds.end - origin) / STEP - Vector3.ONE * 0.5).floor()).min(size - Vector3i.ONE)
	for z in range(lower.z, upper.z + 1):
		for y in range(lower.y, upper.y + 1):
			for x in range(lower.x, upper.x + 1):
				if mesh != null:
					var point = inverse * center(Vector3i(x, y, z))
					if not mesh.get_aabb().grow(0.001).has_point(point):
						continue
					if mesh is CylinderMesh:
						var radius = lerpf(mesh.bottom_radius, mesh.top_radius, (point.y + mesh.height * 0.5) / mesh.height)
						if Vector2(point.x, point.z).length_squared() > radius * radius:
							continue
				solid[index(Vector3i(x, y, z))] = 1

func bake(sources: Array[Vector3]) -> void:
	sky.fill(0)
	torch.fill(0)
	var sky_frontier = PackedInt32Array()
	# Direct sky travels vertically at full strength until a solid block.
	for z in range(size.z):
		for x in range(size.x):
			for y in range(size.y - 1, -1, -1):
				var slot = index(Vector3i(x, y, z))
				if solid[slot]:
					break
				sky[slot] = MAX_LEVEL
	# Only seed boundary voxels: most of the outdoor sky needs no flood work.
	for z in range(size.z):
		for y in range(size.y):
			for x in range(size.x):
				var slot = index(Vector3i(x, y, z))
				if sky[slot] == 0 and solid[slot] == 0:
					for direction in NEIGHBORS:
						var neighbor: Vector3i = Vector3i(x, y, z) + direction
						if inside(neighbor) and sky[index(neighbor)] == MAX_LEVEL:
							sky[slot] = MAX_LEVEL - 1
							sky_frontier.append(slot)
							break
	sky = spread(sky, sky_frontier)
	var torch_frontier = PackedInt32Array()
	for point in sources:
		var cell = cell_at(point)
		if inside(cell) and solid[index(cell)] == 0:
			torch[index(cell)] = TORCH_LEVEL
			torch_frontier.append(index(cell))
	torch = spread(torch, torch_frontier)

func spread(levels: PackedByteArray, frontier: PackedInt32Array) -> PackedByteArray:
	var cursor = 0
	var plane = size.x * size.y
	while cursor < frontier.size():
		var slot = frontier[cursor]
		cursor += 1
		var value = int(levels[slot]) - 1
		if value <= 0:
			continue
		var cell = Vector3i(slot % size.x, (slot / size.x) % size.y, slot / plane)
		for direction in NEIGHBORS:
			var next: Vector3i = cell + direction
			if not inside(next):
				continue
			var next_slot = index(next)
			if not solid[next_slot] and levels[next_slot] < value:
				levels[next_slot] = value
				frontier.append(next_slot)
	return levels

func make_texture() -> ImageTexture3D:
	var slices: Array[Image] = []
	var plane = size.x * size.y
	for z in range(size.z):
		var pixels = PackedByteArray()
		pixels.resize(plane * 2)
		for i in range(plane):
			pixels[i * 2] = sky[z * plane + i] * 17
			pixels[i * 2 + 1] = torch[z * plane + i] * 17
		slices.append(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, pixels))
	texture = ImageTexture3D.new()
	var result = texture.create(Image.FORMAT_RG8, size.x, size.y, size.z, false, slices)
	assert(result == OK, "Block light texture creation failed")
	return texture

func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("block_lighting", true)
	material.set_shader_parameter("light_volume", texture)
	material.set_shader_parameter("light_origin", origin)
	material.set_shader_parameter("light_extent", Vector3(size) * STEP)
	material.set_shader_parameter("light_step", STEP)
