class_name CastleMaze
extends Node3D

const SIZE = 13
const CELL = 4.8
const DIRECTIONS = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var cells: Array[int] = []
var exit_cell = Vector2i.ZERO
var distances: Dictionary = {}
var rng = RandomNumberGenerator.new()
var batches: Dictionary = {}
var torches: Array[Node3D] = []
var portal: Node3D
var portal_disc: MeshInstance3D
var seed_value: int = 0
var web_profile = false
var block_light: BlockLighting
const WEB_CHUNK_SIZE = CELL * 3.0

func generate(value: int, build: bool = true) -> void:
	seed_value = value
	rng.seed = value
	cells.resize(SIZE * SIZE)
	cells.fill(15)
	var stack: Array[Vector2i] = [Vector2i(1, 0)]
	var visited = {Vector2i(1, 0): true}
	while not stack.is_empty():
		var current = stack.back()
		var options: Array[int] = []
		for d in range(4):
			var next = current + DIRECTIONS[d]
			if inside(next) and not visited.has(next):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
		else:
			var direction = options[rng.randi_range(0, options.size() - 1)]
			var next = current + DIRECTIONS[direction]
			open_wall(current, direction)
			visited[next] = true
			stack.append(next)
	# Loops give the player routes around hunting enemies.
	for i in range(30):
		var cell = Vector2i(rng.randi_range(1, SIZE - 2), rng.randi_range(1, SIZE - 2))
		open_wall(cell, rng.randi_range(0, 3))
	# A recognizable entrance courtyard and a safe first stretch.
	for y in range(3):
		for x in range(3):
			if x < 2:
				open_wall(Vector2i(x, y), 1)
			if y < 2:
				open_wall(Vector2i(x, y), 2)
	for y in range(5):
		open_wall(Vector2i(1, y), 2)
	distances = distance_field(Vector2i(1, 0))
	var longest = 0
	for cell in distances:
		if distances[cell] > longest:
			longest = distances[cell]
			exit_cell = cell
	if build:
		build_castle()

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

func index(cell: Vector2i) -> int:
	return cell.y * SIZE + cell.x

func open_wall(cell: Vector2i, direction: int) -> void:
	var next = cell + DIRECTIONS[direction]
	if not inside(next):
		return
	cells[index(cell)] &= ~(1 << direction)
	cells[index(next)] &= ~(1 << ((direction + 2) % 4))

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not inside(cell):
		return out
	for d in range(4):
		if cells[index(cell)] & (1 << d) == 0:
			out.append(cell + DIRECTIONS[d])
	return out

func cell_at(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(pos.x / CELL), 0, SIZE - 1), clampi(roundi(pos.z / CELL), 0, SIZE - 1))

func center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)

func distance_field(start: Vector2i) -> Dictionary:
	var out = {start: 0}
	var frontier: Array[Vector2i] = [start]
	var cursor = 0
	while cursor < frontier.size():
		var cell = frontier[cursor]
		cursor += 1
		for next in neighbors(cell):
			if not out.has(next):
				out[next] = out[cell] + 1
				frontier.append(next)
	return out

func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var previous = {from: from}
	var frontier: Array[Vector2i] = [from]
	var cursor = 0
	while cursor < frontier.size():
		var cell = frontier[cursor]
		cursor += 1
		if cell == to:
			break
		for next in neighbors(cell):
			if not previous.has(next):
				previous[next] = cell
				frontier.append(next)
	var result: Array[Vector2i] = []
	if not previous.has(to):
		return result
	var current = to
	while current != from:
		result.push_front(current)
		current = previous[current]
	return result

func brick(pos: Vector3, size: Vector3, color: String, yaw: float = 0) -> void:
	if not batches.has(color):
		batches[color] = []
	batches[color].append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos))

func wall(pos: Vector3, yaw: float) -> void:
	var basis = Basis(Vector3.UP, yaw)
	# Include the plinth and coping overhang, not only the recessed mortar.
	var collision = CastleArt.solid_box(self, pos + Vector3(0, 1.65, 0), Vector3(CELL + 0.13, 3.3, 0.82))
	collision.rotation.y = yaw
	# Recessed, opaque mortar closes the joints; collision shapes do not render.
	brick(pos + Vector3(0, 1.57, 0), Vector3(CELL + 0.12, 3.14, 0.54), "293133", yaw)
	var colors = ["56646a", "5d6b70", "617074", "4f6066", "6b7779"]
	brick(pos + Vector3(0, 0.17, 0), Vector3(CELL + 0.13, 0.34, 0.78), "46535a", yaw)
	for row in range(5):
		# Alternating joints and recessed mortar give the stone actual depth.
		var count = 4 if row % 2 == 0 else 5
		var width = CELL / count
		for col in range(count):
			var offset = Vector3(-CELL / 2 + width * (col + 0.5), 0.36 + row * 0.55 + 0.265, 0)
			brick(pos + basis * offset, Vector3(width - 0.035, 0.515, rng.randf_range(0.59, 0.65)), colors[rng.randi_range(0, 4)], yaw)
	brick(pos + Vector3(0, 3.16, 0), Vector3(CELL + 0.08, 0.21, 0.82), "788485", yaw)
	for i in range(4):
		brick(pos + basis * Vector3(-1.8 + i * 1.2, 3.58, 0), Vector3(0.66, 0.66, 0.72), "606e73", yaw)

func build_castle() -> void:
	var span = SIZE * CELL
	CastleArt.solid_box(self, Vector3(span / 2 - CELL / 2, -0.25, span / 2 - CELL / 2), Vector3(span + 10, 0.5, span + 10))
	# The slab sits below the tile tops, covering seams without coplanar faces.
	brick(Vector3(span / 2 - CELL / 2, -0.19, span / 2 - CELL / 2), Vector3(span + 10, 0.30, span + 10), "293133")
	for y in range(SIZE):
		for x in range(SIZE):
			var cell = Vector2i(x, y)
			var pos = center(cell)
			for tx in range(3):
				for tz in range(3):
					var shade = ["3f5058", "44565d", "4a5b61", "3b4c54"][rng.randi_range(0, 3)]
					brick(pos + Vector3((tx - 1) * 1.6, -0.06, (tz - 1) * 1.6), Vector3(1.57, 0.12, 1.57), shade)
			var flags = cells[index(cell)]
			if flags & 1:
				wall(pos + Vector3(0, 0, -CELL / 2), 0)
			if flags & 8:
				wall(pos + Vector3(-CELL / 2, 0, 0), PI / 2)
			if y == SIZE - 1:
				wall(pos + Vector3(0, 0, CELL / 2), 0)
			if x == SIZE - 1:
				wall(pos + Vector3(CELL / 2, 0, 0), PI / 2)
			if (x * 7 + y * 3) % 9 == 0 and flags & 1:
				torches.append(CastleArt.torch(self, pos + Vector3(-1.25, 0.4, -1.88)))
				CastleArt.banner(self, pos + Vector3(0.65, 0.8, -2.01), PI)
			if rng.randf() < 0.25 and not (x < 3 and y < 3):
				for i in range(3):
					brick(pos + Vector3(rng.randf_range(-1.7, -1.4), 0.12, rng.randf_range(-1.8, 1.8)), Vector3(0.30, 0.20, 0.24), "536758", rng.randf() * PI)
	# Entrance: lanterns, guardian statues and a gold-inlaid processional path.
	for side in [-1, 1]:
		var pos = Vector3(CELL + side * 3.0, 0, CELL * 1.55)
		var pedestal = CastleArt.box(self, pos + Vector3(0, 0.22, 0), Vector3(1.65, 0.44, 1.5), CastleArt.mat("66767b"))
		pedestal.set_meta("ground_shadow_radii", Vector2(1.35, 1.25))
		var statue = CastleArt.knight(self, pos + Vector3(0, 0.44, 0), true)
		statue.scale = Vector3.ONE * 1.35
		torches.append(CastleArt.torch(self, pos + Vector3(-side * 1.15, 0, -1.1)))
		CastleArt.banner(self, Vector3(CELL + side * 3.5, 0.8, -2.03), PI)
	for i in range(13):
		brick(Vector3(CELL - 1.28, 0.007, -1.5 + i * 1.1), Vector3(0.045, 0.016, 0.55), "aa9565")
		brick(Vector3(CELL + 1.28, 0.007, -1.5 + i * 1.1), Vector3(0.045, 0.016, 0.55), "aa9565")
	# The old gatehouse marks the threshold between sanctuary and labyrinth.
	var arch = Vector3(CELL, 0, CELL * 2.45)
	for side in [-1, 1]:
		brick(arch + Vector3(side * 1.86, 1.75, 0), Vector3(0.59, 3.5, 0.79), "293133")
		for row in range(7):
			brick(arch + Vector3(side * 1.86, 0.25 + row * 0.49, 0), Vector3(0.65, 0.46, 0.85), "697778")
		CastleArt.solid_box(self, arch + Vector3(side * 1.86, 1.75, 0), Vector3(0.65, 3.5, 0.85))
		brick(arch + Vector3(side * 1.86, 3.5, 0), Vector3(0.83, 0.22, 1.0), "9b9e91")
		CastleArt.banner(self, arch + Vector3(side * 2.8, 1.5, -0.3))
	for i in range(11):
		var angle = float(i) * PI / 10
		var segment = CastleArt.box(self, arch + Vector3(cos(angle) * 1.86, 3.5 + sin(angle) * 1.86, 0), Vector3(0.65, 0.53, 0.83), CastleArt.stone("7d8986"))
		segment.rotation.z = angle - PI / 2
		segment.set_meta("block_occluder", true)
	var keystone = CastleArt.box(self, arch + Vector3(0, 5.38, -0.08), Vector3(0.46, 0.7, 1.0), CastleArt.stone("aaa98d"))
	keystone.rotation.z = 0
	keystone.set_meta("block_occluder", true)
	# Tall perimeter towers establish the fortress silhouette above the maze.
	for x in [-5.0, span + 0.3]:
		for z in [-5.0, span * 0.45, span + 0.3]:
			var p = Vector3(x, 4.8, z)
			CastleArt.cylinder(self, p, 3.6, 3.3, 12.5, CastleArt.mat("414f5b"), 10)
			CastleArt.cylinder(self, p + Vector3(0, 6.2, 0), 3.65, 3.65, 0.65, CastleArt.mat("66737a"), 10)
			CastleArt.cylinder(self, p + Vector3(0, 8.6, 0), 3.8, 0.15, 4.4, CastleArt.mat("293644"), 10)
			for i in range(8):
				var angle = i * TAU / 8
				CastleArt.box(self, p + Vector3(sin(angle) * 3.2, 6.7, cos(angle) * 3.2), Vector3(1.1, 1.2, 1.1), CastleArt.mat("596973"))
	if web_profile:
		build_web_masonry()
	else:
		build_native_masonry()
	batches.clear()
	build_portal()

func bake_block_light() -> void:
	block_light = BlockLighting.new()
	# The floor seals the volume even at the narrow gaps between tile meshes.
	block_light.add_box(AABB(Vector3(-8.4, -0.4, -8.4), Vector3(78.4, 0.5, 78.4)))
	for node in get_children():
		if node is MultiMeshInstance3D:
			# CPU transforms are recorded during batch creation; headless Godot
			# cannot read the rendering server's MultiMesh buffers back.
			for transform: Transform3D in node.get_meta("lighting_boxes"):
				block_light.add_box(transform * AABB(Vector3.ONE * -0.5, Vector3.ONE))
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		# Only structural stone blocks light. Small props and decorations do
		# not become oversized, opaque voxels around statues or torch brackets.
		var tower = mesh.mesh is CylinderMesh and mesh.mesh.bottom_radius > 2.0
		if tower or mesh.has_meta("block_occluder"):
			block_light.add_mesh(global_transform.affine_inverse() * mesh.global_transform, mesh.mesh)
	var sources: Array[Vector3] = []
	for torch_node in torches:
		# Torches on north walls face into their own corridor.
		sources.append(torch_node.position + Vector3(0, 1.6, 0.35))
	block_light.bake(sources)
	block_light.make_texture()

func add_masonry_batch(transforms: Array, colors: Array, material: Material) -> MultiMeshInstance3D:
	var node = add_box_batch(transforms, colors, material)
	# The dummy renderer cannot read back GPU instance data.
	node.set_meta("masonry_bounds", node.multimesh.custom_aabb)
	return node

func add_box_batch(transforms: Array, colors: Array, material: Material) -> MultiMeshInstance3D:
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = BoxMesh.new()
	multi.instance_count = transforms.size()
	var bounds = AABB()
	for i in range(multi.instance_count):
		var transform: Transform3D = transforms[i]
		multi.set_instance_transform(i, transform)
		if multi.use_colors:
			multi.set_instance_color(i, colors[i])
		var instance_bounds: AABB = transform * multi.mesh.get_aabb()
		bounds = instance_bounds if i == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var node = MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("lighting_boxes", transforms)
	add_child(node)
	return node

func build_native_masonry() -> void:
	for color in batches:
		add_masonry_batch(batches[color], [], CastleArt.stone(color))

func build_web_masonry() -> void:
	# One material per spatial chunk, with per-instance colors. Large slabs keep
	# their own batch so their bounds cannot defeat culling of nearby masonry.
	var chunks: Dictionary = {}
	for color: String in batches:
		for transform: Transform3D in batches[color]:
			var key = Vector2i(floori(transform.origin.x / WEB_CHUNK_SIZE), floori(transform.origin.z / WEB_CHUNK_SIZE))
			if transform.basis.get_scale().length() > WEB_CHUNK_SIZE * 2.0:
				key = Vector2i(-100, -100)
			if not chunks.has(key):
				chunks[key] = {"transforms": [], "colors": []}
			chunks[key].transforms.append(transform)
			chunks[key].colors.append(Color(color))
	var material = CastleArt.web_masonry_material()
	for key: Vector2i in chunks:
		var data: Dictionary = chunks[key]
		var node = add_masonry_batch(data.transforms, data.colors, material)
		node.name = "Masonry_%d_%d" % [key.x, key.y]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_portal() -> void:
	portal = Node3D.new()
	portal.position = center(exit_cell)
	# Align the gate face to a traversable entrance.
	var approach = neighbors(exit_cell)[0] - exit_cell
	portal.rotation.y = atan2(-approach.x, -approach.y)
	add_child(portal)
	var stone = CastleArt.mat("738783")
	var rune = CastleArt.mat("64ffc0")
	CastleArt.cylinder(portal, Vector3(0, 0.12, 0), 1.8, 1.8, 0.24, stone, 16)
	for side in [-1, 1]:
		CastleArt.box(portal, Vector3(side * 1.34, 1.34, 0), Vector3(0.44, 2.65, 0.62), stone)
		for j in range(4):
			var rune_block = CastleArt.box(portal, Vector3(side * 1.34, 0.55 + j * 0.51, -0.325), Vector3(0.10, 0.15, 0.03), rune)
			rune_block.rotation.z = PI / 4
	for i in range(9):
		var angle = i * PI / 8
		var segment = CastleArt.box(portal, Vector3(cos(angle) * 1.34, 2.6 + sin(angle) * 1.34, 0), Vector3(0.55, 0.47, 0.62), stone)
		segment.rotation.z = angle - PI / 2
	var plane = QuadMesh.new()
	plane.size = Vector2(2.55, 3.6)
	var material = ShaderMaterial.new()
	material.shader = load("res://assets/shaders/portal.gdshader")
	portal_disc = CastleArt.mesh(portal, plane, Vector3(0, 1.97, 0), material)
	# A solid emerald pennant keeps the exit landmark above the battlements.
	CastleArt.cylinder(portal, Vector3(0, 5.7, 0.4), 0.055, 0.055, 5.2, stone, 6)
	CastleArt.box(portal, Vector3(0.6, 7.65, 0.4), Vector3(1.2, 0.7, 0.06), rune)
