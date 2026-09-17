extends SceneTree
## Keep baked lighting and cheap ground patches free of real-time shadow passes.
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
		check(root.positional_shadow_atlas_size == 0, "no local shadow atlas is allocated")
		var environment: Environment = game.find_children("*", "WorldEnvironment", true, false)[0].environment
		check(not environment.fog_enabled and not environment.glow_enabled and not environment.ssao_enabled, "no atmospheric lighting or screen-space effects")
		for seed_value in [734291, 1, 79]:
			game.new_run(seed_value)
			var sky_before = game.maze.block_light.sky.duplicate()
			var torch_before = game.maze.block_light.torch.duplicate()
			var texture_before = game.maze.block_light.texture
			check(game.find_children("*", "Light3D", true, false).is_empty(), "no lights are generated for the sun, torches, portal, or player")
			check(game.ground_shadows.multimesh.instance_count == game.enemies.size() + 2, "only enemies and courtyard statues have contact shadows")
			check(game.ground_shadows.multimesh.instance_count <= 15, "contact shadows stay within fifteen quads in one batch")
			check(game.ground_shadows.multimesh.mesh is PlaneMesh and game.ground_shadows.multimesh.mesh.subdivide_width == 0 and game.ground_shadows.multimesh.mesh.subdivide_depth == 0, "each contact shadow costs only two triangles")
			var surfaces = 0
			for node: GeometryInstance3D in game.find_children("*", "GeometryInstance3D", true, false):
				check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "geometry never participates in shadow passes")
				if node is MeshInstance3D:
					for surface in range(node.mesh.get_surface_count()):
						var material = node.get_active_material(surface)
						check(material is ShaderMaterial and material.shader.resource_path in ["res://assets/shaders/comic.gdshader", "res://assets/shaders/portal.gdshader"], "procedural and imported surfaces use the flat art style")
						surfaces += 1
			check(surfaces > 100, "material checks cover castle props, equipment, pickups and imported enemies")
			for cell in [Vector2i(1, 0), Vector2i(6, 6), game.maze.exit_cell]:
				game.state = "playing"
				game.player.position = game.maze.center(cell) + Vector3(0, 2, 0)
				game._process(0.1)
				check(game.find_children("*", "Light3D", true, false).is_empty(), "movement never creates or enables lighting")
				check(game.maze.block_light.sky == sky_before and game.maze.block_light.torch == torch_before, "movement cannot change the baked world light levels")
				check(game.maze.block_light.texture == texture_before, "movement reuses the existing light texture")
		game.free()
	if failures.is_empty():
		print("PASS: %d simple-style regression checks" % checks)
		quit(0)
	else:
		quit(1)
