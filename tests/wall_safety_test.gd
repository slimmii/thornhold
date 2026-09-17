extends SceneTree
## Physical clearance of every first-person weapon and wall collision.
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
	var game: ThornholdGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	game.start()
	game.set_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	var player = game.player
	# An isolated square checks actual contact on all four wall orientations.
	var arena = Node3D.new()
	game.world.add_child(arena)
	arena.position = Vector3(-50, 0, -50)
	CastleArt.solid_box(arena, Vector3(0, -0.25, 0), Vector3(10, 0.5, 10))
	for side in range(4):
		var wall_basis = Basis(Vector3.UP, side * PI / 2)
		var wall = CastleArt.solid_box(arena, wall_basis * Vector3(0, 1.65, -2.4), Vector3(4.93, 3.3, 0.82))
		wall.rotation.y = side * PI / 2
	for side in range(4):
		player.set_physics_process(true)
		player.position = arena.position + Vector3(0, 0.05, 0)
		player.velocity = Vector3.ZERO
		player.rotation.y = side * PI / 2
		player.camera.rotation.x = 0
		Input.action_press("forward")
		for frame in range(45):
			await physics_frame
		Input.action_release("forward")
		player.set_physics_process(false)
		var wall_distance = (player.position - arena.position).length()
		check(wall_distance > 1.6 and wall_distance < 1.69, "movement stops before stone overhang, side %d" % side)
		for tier in range(game.WEAPONS.size()):
			CastleArt.weapon(player.hand, tier)
			for pitch in [-1.35, 0.0, 1.35]:
				player.camera.rotation.x = pitch
				for phase in range(21):
					player.swing = phase / 20.0
					player.blocking = phase % 2 == 0
					player.update_equipment_pose(1.0 / 12.0)
					var clear = true
					var fits = true
					for equipment in [player.hand, player.shield]:
						for mesh: MeshInstance3D in equipment.get_children():
							for corner in range(8):
								var point: Vector3 = mesh.global_transform * mesh.mesh.get_aabb().get_endpoint(corner)
								fits = fits and point.distance_to(player.camera.global_position) < 0.30
								var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position, point, 1)
								clear = clear and player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
					check(fits and clear, "weapon and shield clear walls: side %d tier %d pitch %.2f phase %d" % [side, tier, pitch, phase])
			for mesh in player.hand.get_children():
				check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "first-person equipment never casts miniature world shadows")
				check(mesh.layers == 2, "replacement weapons preserve the equipment render layer")
	game.free()
	if failures.is_empty():
		print("PASS: %d wall and equipment checks" % checks)
		quit(0)
	else:
		quit(1)
