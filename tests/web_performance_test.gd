extends SceneTree
## Geometry/cadence regressions and a conservative frustum workload estimate.
## This is not a GPU/browser FPS benchmark.
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func masonry(maze: CastleMaze) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for child in maze.get_children():
		if child is MultiMeshInstance3D and child.has_meta("masonry_bounds"):
			result.append(child)
	return result

class RecordedMaze extends CastleMaze:
	var geometry: Array[String] = []
	var captured_bounds: Array[AABB] = []

	func add_masonry_batch(transforms: Array, colors: Array, material: Material) -> MultiMeshInstance3D:
		var shape = BoxMesh.new()
		var bounds = AABB()
		for i in range(transforms.size()):
			var transform: Transform3D = transforms[i]
			var color: Color = colors[i] if not colors.is_empty() else material.get_shader_parameter("base_color")
			var key = color.to_html()
			for vector: Vector3 in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
				key += ":%.3f,%.3f,%.3f" % [vector.x, vector.y, vector.z]
			geometry.append(key)
			var instance_bounds: AABB = transform * shape.get_aabb()
			bounds = instance_bounds if i == 0 else bounds.merge(instance_bounds)
		captured_bounds.append(bounds)
		return super.add_masonry_batch(transforms, colors, material)

func visible(bounds: AABB, position: Vector3, yaw: float) -> bool:
	var inverse = Basis(Vector3.UP, yaw).inverse()
	var tan_y = tan(deg_to_rad(78.0) / 2.0)
	var tan_x = tan_y * 1440.0 / 900.0
	# Reject only when all eight corners lie outside the same frustum plane.
	var outside = [true, true, true, true, true, true]
	for corner in range(8):
		var p: Vector3 = inverse * (bounds.get_endpoint(corner) - position)
		var depth = -p.z
		outside[0] = outside[0] and p.x < -depth * tan_x
		outside[1] = outside[1] and p.x > depth * tan_x
		outside[2] = outside[2] and p.y < -depth * tan_y
		outside[3] = outside[3] and p.y > depth * tan_y
		outside[4] = outside[4] and depth < 0.045
		outside[5] = outside[5] and depth > 160.0
	return not true in outside

func run() -> void:
	var original = RecordedMaze.new()
	root.add_child(original)
	original.generate(734291)
	var optimized = RecordedMaze.new()
	optimized.web_profile = true
	root.add_child(optimized)
	optimized.generate(734291)
	check(original.cells == optimized.cells and original.exit_cell == optimized.exit_cell, "web optimization preserves the maze layout")
	var native_nodes = masonry(original)
	var web_nodes = masonry(optimized)
	original.geometry.sort()
	optimized.geometry.sort()
	check(original.geometry == optimized.geometry, "every masonry transform and color is preserved")
	var native_bounds: Array[AABB] = []
	var web_bounds: Array[AABB] = []
	for node in native_nodes:
		native_bounds.append(node.get_meta("masonry_bounds"))
	for node in web_nodes:
		var measured: AABB = optimized.captured_bounds[web_nodes.find(node)]
		web_bounds.append(measured)
		check((node.get_meta("masonry_bounds") as AABB).grow(0.001).encloses(measured), "web bounds enclose every brick")
		check(node.material_override.shader == CastleArt.COMIC_SHADER, "masonry uses the shared comic shader")
		check(node.material_override.get_shader_parameter("use_instance_color"), "masonry preserves instance colors")
	var native_candidates = 0
	var web_candidates = 0
	var sample_count = 0
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(3, 4), Vector2i(6, 6), Vector2i(10, 10)]:
		for direction in range(4):
			var position = original.center(cell) + Vector3(0, 1.62, 0)
			var yaw = direction * PI / 2.0
			for i in range(native_nodes.size()):
				if visible(native_bounds[i], position, yaw):
					native_candidates += native_nodes[i].multimesh.instance_count
			for i in range(web_nodes.size()):
				if visible(web_bounds[i], position, yaw):
					web_candidates += web_nodes[i].multimesh.instance_count
			sample_count += 1
	check(web_candidates < native_candidates * 0.75, "spatial batching meaningfully reduces offscreen instance submission")
	print("FRUSTUM ESTIMATE: %d -> %d masonry instances/view over %d views (%.1f%% fewer); not measured FPS" % [native_candidates / sample_count, web_candidates / sample_count, sample_count, 100.0 * (1.0 - float(web_candidates) / native_candidates)])
	check(optimized.find_children("*", "Light3D", true, false).is_empty(), "castle contains no dynamic lights")
	check(optimized.find_children("WallShadows_*", "MultiMeshInstance3D", true, false).is_empty(), "castle has no duplicate shadow geometry")
	original.free()
	optimized.free()
	var visual = EnemyVisual.new()
	root.add_child(visual)
	visual.configure(0)
	visual.update_interval = 1.0 / 15.0
	visual.play_action(&"attack")
	var updates = 0
	for i in range(24):
		var previous = visual.animator.current_animation_position
		visual.tick(1.0 / 60.0, 0.0, false)
		if not is_equal_approx(previous, visual.animator.current_animation_position):
			updates += 1
	check(updates == 6, "distant animation evaluates at 15 Hz")
	check(is_equal_approx(visual.animator.current_animation_position, 0.4), "throttling preserves elapsed animation time")
	visual.free()
	var game = load("res://scenes/main.tscn").instantiate()
	game.web_profile = true
	root.add_child(game)
	game.save_records = false
	check(is_equal_approx(root.scaling_3d_scale, 1.0), "web uses Sharp at full viewport resolution")
	var old_quality_key = InputEventKey.new()
	old_quality_key.physical_keycode = KEY_F6
	old_quality_key.pressed = true
	game._unhandled_input(old_quality_key)
	check(is_equal_approx(root.scaling_3d_scale, 1.0), "F6 cannot re-enable upscaling")
	check(game.state == "title" and game.coins == 0 and game.level == 1, "unused quality shortcut preserves game state")
	game.start()
	game.set_mode("paused")
	var graphics_button: Button
	for button in game.hud.buttons:
		if button.text.begins_with("Graphics"):
			graphics_button = button
	check(graphics_button == null, "pause menu has no resolution-switching control")
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and game.state == "paused", "pausing preserves full resolution")
	game.set_mode("shop")
	check(game.hud.buttons.size() > 0, "menus remain interactive with throttled HUD drawing")
	game.free()
	if failures.is_empty():
		print("PASS: %d web performance regression checks" % checks)
		quit(0)
	else:
		quit(1)
