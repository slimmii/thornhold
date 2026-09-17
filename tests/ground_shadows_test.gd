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
	for web in [false, true]:
		var game = load("res://scenes/main.tscn").instantiate()
		game.web_profile = web
		root.add_child(game)
		game.save_records = false
		game.set_process(false)
		var shadows: GroundShadows = game.ground_shadows
		var hound: MazeEnemy = game.enemies[1]
		check(hound.kind == 1, "exercise the elongated hound shadow")
		var sky_before = game.maze.block_light.sky.duplicate()
		var torch_before = game.maze.block_light.torch.duplicate()
		for yaw in [0.0, PI / 2, PI]:
			hound.position = game.maze.center(Vector2i(1, 1)) + Vector3(0.3, 0.05, 0.5)
			hound.model.rotation.y = yaw
			shadows.refresh()
			var transform: Transform3D = shadows.casters[1].transform
			check(is_equal_approx(transform.origin.y, GroundShadows.FLOOR_Y), "shadow stays on the floor")
			check(Vector2(transform.origin.x, transform.origin.z).is_equal_approx(Vector2(hound.position.x, hound.position.z)), "shadow follows the caster")
			check(transform.basis.z.normalized().is_equal_approx(Basis(Vector3.UP, yaw).z), "hound ellipse follows its visible model's facing")
			check(shadows.multimesh.custom_aabb.encloses(transform * shadows.multimesh.mesh.get_aabb()), "fixed batch bounds enclose moving shadows")
		var fixed_transform: Transform3D = shadows.casters[1].transform
		for camera_pos in [Vector3(0, 1.62, 0), Vector3(20, 1.62, 20), Vector3(50, 4, 50)]:
			game.player.position = camera_pos
			shadows.refresh()
			check(shadows.casters[1].transform == fixed_transform, "camera movement never shifts contact shadows")
		check(game.maze.block_light.sky == sky_before and game.maze.block_light.torch == torch_before, "shadows do not rebake lighting")
		# Probe each real wall orientation at its inside face.
		for direction in range(4):
			var found = false
			for cell in game.maze.distances:
				if not game.maze.cells[game.maze.index(cell)] & (1 << direction):
					continue
				var center: Vector3 = game.maze.center(cell)
				var axis: Vector2i = CastleMaze.DIRECTIONS[direction]
				var pos = center + Vector3(axis.x, 0, axis.y) * 1.6
				var bounds = shadows.floor_bounds(pos)
				var edge = [bounds.g, bounds.b, bounds.a, bounds.r][direction]
				var expected = [center.z - 2.0, center.x + 2.0, center.z + 2.0, center.x - 2.0][direction]
				check(is_equal_approx(edge, expected), "closed wall clips the shadow on side %d" % direction)
				found = true
				break
			check(found, "generated maze supplies each wall orientation")
		hound.model.scale = Vector3.ONE * 0.5
		shadows.refresh()
		check(is_equal_approx(shadows.casters[1].strength, GroundShadows.OPACITY * 0.5), "corpse shadow fades with the disappearing body")
		hound.queue_free()
		shadows.refresh()
		check(shadows.casters[1].strength == 0.0, "queued corpse leaves no orphan shadow")
		await process_frame
		shadows.refresh()
		check(shadows.casters[1].strength == 0.0, "freed corpse is safe to revisit")
		game.new_run(1)
		check(game.ground_shadows != shadows and game.ground_shadows.casters.size() == 15, "new levels replace the batch instead of accumulating shadows")
		game.free()
	if failures.is_empty():
		print("PASS: %d ground-shadow checks" % checks)
		quit(0)
	else:
		quit(1)
