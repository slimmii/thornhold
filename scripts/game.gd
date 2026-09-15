class_name ThornholdGame
extends Node3D

const WEAPONS = [
	{"name": "Iron gauntlets", "short": "GAUNTLETS", "reach": 1.65, "damage": 12.0, "cost": 0, "cooldown": 0.48, "lore": "A knight's last defense."},
	{"name": "Ashwood stick", "short": "ASHWOOD STICK", "reach": 2.5, "damage": 26.0, "cost": 6, "cooldown": 0.52, "lore": "A humble branch. A fighting chance."},
	{"name": "Knight's sword", "short": "KNIGHT'S SWORD", "reach": 3.3, "damage": 42.0, "cost": 15, "cooldown": 0.47, "lore": "Steel sworn to the old kingdom."},
	{"name": "Warden's spear", "short": "WARDEN'S SPEAR", "reach": 4.7, "damage": 58.0, "cost": 27, "cooldown": 0.58, "lore": "Keep the darkness at arm's length."},
	{"name": "Royal halberd", "short": "ROYAL HALBERD", "reach": 6.2, "damage": 85.0, "cost": 42, "cooldown": 0.64, "lore": "The final word of a fallen king."}
]

var state = "title"
var maze: CastleMaze
var player: MazePlayer
var hud: MazeHUD
var sound: MazeSound
var world: Node3D
var enemies: Array[MazeEnemy] = []
var discovered: Dictionary = {}
var level: int = 1
var coins = 0
var coins_found = 0
var total_coins = 0
var kills = 0
var weapon_tier = 0
var elapsed: float = 0
var clock: float = 0
var damage_flash: float = 0
var hit_flash: float = 0
var target_enemy: MazeEnemy
var target_timer: float = 0
var message = ""
var message_timer: float = 0
var show_map = false
var current_seed = 734291
var best_time: float = 0
var save_records = true
var capture_path = ""
var capture_frames = 0

func _ready() -> void:
	configure_input()
	make_environment()
	sound = MazeSound.new()
	add_child(sound)
	var save = ConfigFile.new()
	if save.load("user://record.cfg") == OK:
		best_time = float(save.get_value("record", "time", 0))
	new_run(current_seed)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = MazeHUD.new()
	hud.game = self
	canvas.add_child(hud)
	for arg in OS.get_cmdline_user_args():
		if arg == "--autostart":
			start()
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if state == "title" else Input.MOUSE_MODE_CAPTURED

func configure_input() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key = InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
	for action in ["attack", "block"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var button = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, button)

func make_environment() -> void:
	var environment_node = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("132a40")
	sky_material.sky_horizon_color = Color("465e70")
	sky_material.ground_bottom_color = Color("17252f")
	sky_material.ground_horizon_color = Color("465e70")
	sky_material.sky_curve = 0.20
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a3c2d4")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("455e6c")
	environment.fog_density = 0.007
	environment_node.environment = environment
	add_child(environment_node)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -32, 0)
	sun.light_color = Color("ffdaa5")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)

func new_run(value: int) -> void:
	level = 1
	coins = 0
	weapon_tier = 0
	load_level(value)

func load_level(value: int) -> void:
	# Only the maze and level statistics reset; inventory belongs to the journey.
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	world.name = "Castle"
	add_child(world)
	enemies.clear()
	discovered.clear()
	coins_found = 0
	total_coins = 0
	kills = 0
	elapsed = 0
	damage_flash = 0
	hit_flash = 0
	target_timer = 0
	target_enemy = null
	message_timer = 0
	show_map = false
	current_seed = value
	maze = CastleMaze.new()
	world.add_child(maze)
	maze.generate(value)
	player = MazePlayer.new()
	player.game = self
	player.position = maze.center(Vector2i(1, 0)) + Vector3(0, 0.05, -0.35)
	player.rotation.y = PI
	world.add_child(player)
	if weapon_tier > 0:
		CastleArt.weapon(player.hand, weapon_tier)
	spawn_population()
	reveal_map()

func spawn_population() -> void:
	# Six gold is available before leaving the guardian courtyard.
	for cell in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)]:
		spawn_pickup(maze.center(cell))
	var candidates: Array[Vector2i] = []
	for y in range(CastleMaze.SIZE):
		for x in range(CastleMaze.SIZE):
			var cell = Vector2i(x, y)
			if maze.distances[cell] < 5 or cell == maze.exit_cell:
				continue
			if maze.rng.randf() < 0.50:
				spawn_pickup(maze.center(cell))
			if maze.distances[cell] > 8:
				candidates.append(cell)
	# Seeded randomization keeps retrying the same maze fair and reproducible.
	for i in range(candidates.size() - 1, 0, -1):
		var j = maze.rng.randi_range(0, i)
		var temp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temp
	var occupied: Array[Vector2i] = []
	for cell in candidates:
		if occupied.size() >= 13:
			break
		var too_close = false
		for other in occupied:
			if Vector2(cell - other).length() < 2.2:
				too_close = true
		if too_close:
			continue
		var enemy = MazeEnemy.new()
		enemy.game = self
		enemy.tactic_id = occupied.size()
		enemy.kind = [0, 1, 0, 2, 1, 0, 2][occupied.size() % 7]
		enemy.position = maze.center(cell) + Vector3(0, 0.05, 0)
		world.add_child(enemy)
		enemies.append(enemy)
		occupied.append(cell)
	for i in range(mini(9, candidates.size())):
		spawn_pickup(maze.center(candidates[i]) + Vector3(0.8, 0, 0.7), true)

func spawn_pickup(pos: Vector3, healing: bool = false) -> MazePickup:
	var pickup = MazePickup.new()
	pickup.position = pos
	pickup.game = self
	pickup.healing = healing
	world.add_child(pickup)
	if not healing:
		total_coins += 1
	return pickup

func start() -> void:
	state = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.camera.rotation.x = 0
	if level == 1 and weapon_tier == 0:
		toast("Level 1 · Find the Emerald Gate. Collect 6 gold for your first weapon [B].", 7)
	else:
		toast("Level %d · %s · %d gold carried forward" % [level, WEAPONS[weapon_tier].name, coins], 6)
	if is_instance_valid(hud):
		hud.refresh_buttons()

func set_mode(mode: String) -> void:
	state = mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "playing" else Input.MOUSE_MODE_VISIBLE
	player.blocking = false
	hud.refresh_buttons()

func restart(fresh: bool = false) -> void:
	state = "loading"
	if fresh:
		new_run(100000 + posmod(current_seed - 100000 + randi_range(1, 899999), 900000))
	else:
		load_level(current_seed)
	start()

func next_level() -> void:
	if state != "victory":
		return
	state = "loading"
	level += 1
	load_level(100000 + posmod(current_seed - 100000 + 104729, 900000))
	start()

func enemy_tactics_description(for_level: int) -> String:
	if for_level >= 4:
		return "Enemies call allies and try to cut you off."
	if for_level >= 3:
		return "Enemies can call nearby allies into the hunt."
	if for_level >= 2:
		return "Enemies search side passages when they lose you."
	return "Enemies patrol and follow your trail."

func buy(tier: int) -> bool:
	if state != "shop" or tier != weapon_tier + 1 or tier >= WEAPONS.size() or coins < WEAPONS[tier].cost:
		return false
	coins -= WEAPONS[tier].cost
	weapon_tier = tier
	CastleArt.weapon(player.hand, tier)
	sound.play("buy", 0.7)
	toast(WEAPONS[tier].name + " equipped · your reach grows", 3)
	hud.refresh_buttons()
	return true

func add_coins(amount: int) -> void:
	coins += amount
	if weapon_tier < 4 and coins - amount < WEAPONS[weapon_tier + 1].cost and coins >= WEAPONS[weapon_tier + 1].cost:
		toast("Upgrade ready  ·  Press B to visit the armory", 4)

func toast(text: String, seconds: float = 3) -> void:
	message = text
	message_timer = seconds

func finish(won: bool) -> void:
	if state != "playing":
		return
	set_mode("victory" if won else "dead")
	if won:
		sound.play("win", 0.7)
		if save_records and (best_time <= 0 or elapsed < best_time):
			best_time = elapsed
			var save = ConfigFile.new()
			save.set_value("record", "time", best_time)
			save.save("user://record.cfg")

func reveal_map() -> void:
	var cell = maze.cell_at(player.position)
	discovered[cell] = true
	for next in maze.neighbors(cell):
		discovered[next] = true

func _process(delta: float) -> void:
	clock += delta
	maze.animate(clock, player.position)
	if state == "playing":
		elapsed += delta
		damage_flash = maxf(0, damage_flash - delta)
		hit_flash = maxf(0, hit_flash - delta)
		target_timer = maxf(0, target_timer - delta)
		message_timer = maxf(0, message_timer - delta)
		reveal_map()
		if player.position.distance_to(maze.center(maze.exit_cell)) < 1.35:
			finish(true)
	elif state == "title":
		player.rotation.y = PI - 0.17 + sin(clock * 0.11) * 0.08
		player.camera.rotation.x = 0.06
		player.hand.visible = false
		player.shield.visible = false
	if state != "title":
		player.hand.visible = true
		player.shield.visible = true
	if is_instance_valid(hud):
		hud.queue_redraw()
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 45:
			capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var error = get_viewport().get_texture().get_image().save_png(capture_path)
	print("SCREENSHOT ", capture_path, " result=", error)
	get_tree().quit(error)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if state == "playing":
					set_mode("paused")
				elif state in ["paused", "shop"]:
					set_mode("playing")
			KEY_B:
				if state == "playing":
					set_mode("shop")
				elif state == "shop":
					set_mode("playing")
			KEY_M:
				if state == "playing":
					show_map = not show_map
			KEY_F11:
				var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_ENTER:
				if state == "title":
					start()
				elif state == "victory":
					next_level()
				elif state == "dead":
					restart()
			KEY_1, KEY_2, KEY_3, KEY_4:
				if state == "shop":
					buy(event.physical_keycode - KEY_1 + 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing" and is_instance_valid(hud) and capture_path.is_empty():
		set_mode("paused")

func time_text(value: float) -> String:
	return "%02d:%02d" % [int(value) / 60, int(value) % 60]
