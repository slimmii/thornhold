extends SceneTree
## Stages the actual game-spawned enemies in the entrance courtyard.
## Optional --frames=/absolute/directory writes a short sequence for video QA.

var game: ThornholdGame
var actors: Array[MazeEnemy] = []
var frames_directory = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames_directory = arg.trim_prefix("--frames=")
	run.call_deferred()

func draw_frame() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	game.capture_path = "animation-visual"
	game.capture_frames = 100000
	game.start()
	game.set_process_unhandled_input(false)
	game.hud.hide()
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.hide()
	for kind in range(3):
		for enemy in game.enemies:
			if enemy.kind == kind:
				actors.append(enemy)
				enemy.show()
				enemy.position = Vector3(8.15 - kind * 3.4, 0, 4.4)
				enemy.model.rotation.y = 0
				break
	game.player.position = Vector3(4.8, 0, -2.05)
	var camera = Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(4.8, 3.1, -2.0)
	camera.fov = 72
	camera.look_at(Vector3(4.8, 1.25, 4.4))
	camera.make_current()
	var captions = CanvasLayer.new()
	game.add_child(captions)
	var caption = Label.new()
	caption.position = Vector2(28, 24)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color("eee7d2"))
	caption.add_theme_color_override("font_shadow_color", Color("101d26"))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.text = "THORNHOLD · BLACKGUARD / ASH HOUND / HORNED SENTINEL"
	captions.add_child(caption)
	for i in range(15):
		await process_frame
	var still = await draw_frame()
	still.save_png("res://screenshots/enemies-in-game.png")
	if not frames_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(frames_directory)
		var previous_stage = -1
		for frame in range(150):
			var time = float(frame) / 20.0
			var stage = 0 if time < 1.0 else (1 if time < 2.25 else (2 if time < 3.5 else (3 if time < 4.8 else (4 if time < 5.4 else 5))))
			caption.text = "THORNHOLD · " + ["IDLE", "PATROL", "CHASE", "ATTACK", "HIT REACTION", "DEATH"][stage]
			for actor in actors:
				if stage != previous_stage:
					if stage == 3:
						actor.model.play_action(&"attack")
					elif stage == 4:
						actor.model.play_action(&"hit")
					elif stage == 5:
						actor.model.play_action(&"death")
				var speed = 0.0
				if stage == 1:
					speed = EnemyVisual.WALK_SPEED[actor.kind]
				elif stage == 2:
					speed = EnemyVisual.RUN_SPEED[actor.kind]
				actor.model.tick(0.05, speed, stage == 2)
			previous_stage = stage
			var image = await draw_frame()
			image.save_png(frames_directory.path_join("%04d.png" % frame))
			if frame in [30, 51, 73, 75, 78, 84, 124, 149]:
				image.save_png("res://screenshots/enemy-animation-%03d.png" % frame)
		print("ANIMATION FRAMES: ", frames_directory)
	game.queue_free()
	await process_frame
	quit()
