extends SceneTree
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func run() -> void:
	var field = BlockLighting.new(Vector3.ONE * -0.4, Vector3i(20, 10, 20))
	field.bake([])
	check(field.sky[field.index(Vector3i(3, 1, 3))] == 15, "open sky reaches the ground at full level")
	field.add_box(AABB(Vector3(-0.4, 3.0, -0.4), Vector3(16, 0.4, 16)))
	field.bake([])
	check(field.sky[field.index(Vector3i(3, 2, 3))] == 0, "solid roof blocks direct skylight")
	field.solid[field.index(Vector3i(3, 4, 3))] = 0
	field.bake([])
	check(field.sky[field.index(Vector3i(3, 1, 3))] == 15, "skylight travels down an opening without losing levels")
	check(field.sky[field.index(Vector3i(4, 1, 3))] == 14, "skylight loses a level spreading under cover")
	var source = field.center(Vector3i(3, 2, 3))
	field.add_box(AABB(Vector3(6.2, -0.4, -0.4), Vector3(0.4, 8, 16)))
	field.bake([source])
	check(field.torch[field.index(Vector3i(3, 2, 3))] == 14, "torch starts at level 14")
	check(field.torch[field.index(Vector3i(5, 2, 6))] == 9, "torchlight loses one level per grid step")
	check(field.torch[field.index(Vector3i(9, 2, 3))] == 0, "sealed wall blocks torchlight")
	field.solid[field.index(Vector3i(8, 2, 3))] = 0
	field.bake([source])
	check(field.torch[field.index(Vector3i(9, 2, 3))] == 8, "opening in wall lets light propagate")
	check(field.torch[field.index(Vector3i(19, 2, 3))] == 0, "light runs out after its finite propagation range")
	var first_map = field.torch.duplicate()
	field.bake([source, source])
	check(field.torch == first_map, "overlapping sources do not accumulate brightness")
	field.make_texture()
	check(field.texture.get_width() == 20 and field.texture.get_depth() == 20, "GPU volume matches the grid")
	for seed_value in [734291, 1, 79]:
		var maze = CastleMaze.new()
		maze.web_profile = true
		root.add_child(maze)
		maze.generate(seed_value)
		maze.bake_block_light()
		check(maze.block_light.sky.size() < 250000, "whole castle fits in a small fixed light volume")
		for node in maze.torches:
			var cell = maze.block_light.cell_at(node.position + Vector3(0, 1.6, 0.35))
			check(maze.block_light.torch[maze.block_light.index(cell)] == 14, "every generated torch contributes light, seed %d" % seed_value)
		maze.free()
	if failures.is_empty():
		print("PASS: %d block-light propagation checks" % checks)
		quit(0)
	else:
		quit(1)
