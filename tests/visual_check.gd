extends SceneTree

var game: ThornholdGame

func _initialize() -> void:
	run.call_deferred()

func shot(name: String) -> void:
	print("VISUAL CHECK: rendering ", name)
	for i in range(20):
		await process_frame
	# Force an offscreen draw so an unfocused/minimized test window still captures.
	RenderingServer.force_draw(false)
	var path = "res://screenshots/" + name + ".png"
	var result = root.get_texture().get_image().save_png(path)
	print("VISUAL CHECK: ", name, " result=", result)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	# The capture flag suppresses pause-on-focus-loss during visual automation.
	game.capture_path = "visual-test"
	game.capture_frames = 10000
	await shot("title")
	game.start()
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	game.coins = 6
	game.set_mode("shop")
	await shot("armory")
	game.buy(1)
	game.set_mode("playing")
	game.show_map = true
	await shot("map")
	game.show_map = false
	game.weapon_tier = 3
	CastleArt.weapon(game.player.hand, 3)
	var monster: MazeEnemy
	for enemy in game.enemies:
		if enemy.kind == 2:
			monster = enemy
			break
	# Inspect the actual sentinel model in the spacious starting courtyard.
	monster.position = game.maze.center(Vector2i(1, 1)) + Vector3(0, 0.05, 1.0)
	monster.model.rotation.y = 0
	monster.alert = true
	game.target_enemy = monster
	game.target_timer = 100
	game.player.rotation.y = PI
	game.player.camera.rotation.x = 0
	game.message_timer = 0
	await shot("sentinel")
	var approach = game.maze.neighbors(game.maze.exit_cell)[0]
	game.player.position = game.maze.center(approach)
	game.player.velocity = Vector3.ZERO
	game.player.look_at(game.maze.center(game.maze.exit_cell))
	game.player.camera.rotation.x = 0.06
	game.target_timer = 0
	await shot("portal")
	game.coins = 37
	game.elapsed = 128
	game.finish(true)
	await shot("victory")
	game.hud.buttons[0].pressed.emit()
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await shot("level-2")
	game.set_mode("shop")
	await shot("armory-level-2")
	game.set_mode("playing")
	game.finish(false)
	await shot("retry-level-2")
	game.queue_free()
	await process_frame
	quit()
