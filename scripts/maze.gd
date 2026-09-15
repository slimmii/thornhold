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
	var collision = CastleArt.solid_box(self, pos + Vector3(0, 1.65, 0), Vector3(CELL + 0.12, 3.3, 0.6))
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
		CastleArt.box(self, pos + Vector3(0, 0.22, 0), Vector3(1.65, 0.44, 1.5), CastleArt.mat("66767b"))
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
	var keystone = CastleArt.box(self, arch + Vector3(0, 5.38, -0.08), Vector3(0.46, 0.7, 1.0), CastleArt.stone("aaa98d"))
	keystone.rotation.z = 0
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
	for color in batches:
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = BoxMesh.new()
		multi.instance_count = batches[color].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, batches[color][i])
		var node = MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = CastleArt.stone(color)
		add_child(node)
	batches.clear()
	build_portal()

func build_portal() -> void:
	portal = Node3D.new()
	portal.position = center(exit_cell)
	# Align the gate face to a traversable entrance.
	var approach = neighbors(exit_cell)[0] - exit_cell
	portal.rotation.y = atan2(-approach.x, -approach.y)
	add_child(portal)
	var stone = CastleArt.mat("738783")
	var rune = CastleArt.mat("64ffc0", 0, 2.0)
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
	CastleArt.light(portal, Vector3(0, 2, 0), Color("46ffa3"), 4.4, 12)
	# A high beacon is visible above the battlements as an orientation landmark.
	var beam_mat = CastleArt.mat("32cfa0", 0, 0.6).duplicate()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color.a = 0.13
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	CastleArt.cylinder(portal, Vector3(0, 13, 0), 0.4, 0.13, 20, beam_mat, 12)
	for i in range(18):
		var mote = CastleArt.sphere(portal, Vector3(sin(i * 2.4) * 1.1, 0.3 + i * 0.2, cos(i * 2.4) * 0.3), 0.035, rune)
		mote.set_meta("phase", i * 0.8)

func animate(time: float, player_pos: Vector3) -> void:
	for torch_node in torches:
		var lamp = torch_node.get_child(torch_node.get_child_count() - 1)
		lamp.visible = torch_node.global_position.distance_squared_to(player_pos) < 400
		if lamp.visible:
			lamp.light_energy = 1.95 + sin(time * 9 + torch_node.position.x) * 0.18 + sin(time * 17) * 0.09
	for child in portal.get_children():
		if child.has_meta("phase"):
			child.position.y = fposmod(time * 0.32 + float(child.get_meta("phase")), 3.5) + 0.2
