extends SceneTree

var failures: Array[String] = []
var checks = 0
var game: ThornholdGame

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	# Graph invariants across many layouts, including boundary walls and both
	# sides of every passage. These catch unreachable exits and AI wall cuts.
	var maze = CastleMaze.new()
	maze.brick(Vector3.ZERO, Vector3(4.8, 0.5, 0.6), "test", PI / 2)
	var brick_transform: Transform3D = maze.batches["test"][0]
	check(is_equal_approx(brick_transform.basis.x.length(), 4.8), "rotated masonry preserves local length")
	check(is_equal_approx(brick_transform.basis.z.length(), 0.6), "rotated masonry preserves local thickness")
	maze.batches.clear()
	for seed_value in range(20):
		maze.generate(1001 + seed_value * 797, false)
		check(maze.distances.size() == CastleMaze.SIZE * CastleMaze.SIZE, "all cells connected, seed %d" % seed_value)
		check(maze.distances[maze.exit_cell] > 15, "exit is meaningfully distant")
		for y in range(CastleMaze.SIZE):
			for x in range(CastleMaze.SIZE):
				var cell = Vector2i(x, y)
				for d in range(4):
					var next = cell + CastleMaze.DIRECTIONS[d]
					var wall = maze.cells[maze.index(cell)] & (1 << d)
					if maze.inside(next):
						var opposite = maze.cells[maze.index(next)] & (1 << ((d + 2) % 4))
						check(bool(wall) == bool(opposite), "reciprocal walls")
					else:
						check(wall != 0, "sealed boundary")
		var route = maze.path(Vector2i(1, 0), maze.exit_cell)
		var previous = Vector2i(1, 0)
		for step in route:
			check(step in maze.neighbors(previous), "AI path follows open passages")
			previous = step
		check(previous == maze.exit_cell, "path reaches portal")
	maze.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	await frames(3)
	check(game.state == "title", "starts at title")
	check(game.enemies.size() >= 10, "populates knights and monsters")
	check(game.total_coins >= 30, "enough coins for upgrade progression")
	var original_layout = game.maze.cells.duplicate()
	game.start()
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	check(game.state == "playing", "starts gameplay")
	# Let a real blackguard navigate a right-angle passage and attack.
	var escape_route = game.maze.path(Vector2i(1, 0), game.maze.exit_cell)
	var corner = -1
	for i in range(5, escape_route.size() - 1):
		if escape_route[i] - escape_route[i - 1] != escape_route[i + 1] - escape_route[i]:
			corner = i
			break
	check(corner >= 0, "maze contains a corner for chase test")
	if corner >= 0:
		var hunter = game.enemies[0]
		for npc in game.enemies:
			npc.collision_layer = 0
		hunter.collision_layer = 4
		hunter.position = game.maze.center(escape_route[corner - 1])
		hunter.velocity = Vector3.ZERO
		hunter.path_timer = 0
		game.player.position = game.maze.center(escape_route[corner + 1])
		hunter.set_physics_process(true)
		await frames(310)
		check(hunter.alert, "hunter hears player around a corner")
		check(hunter.position.distance_to(game.player.position) < 1.8, "hunter follows turn without crossing or sticking in walls")
		check(game.player.health < 100, "hunter closes distance and attacks")
		hunter.set_physics_process(false)
		hunter.position = game.maze.center(hunter.home)
		hunter.velocity = Vector3.ZERO
		for npc in game.enemies:
			npc.collision_layer = 4
		game.player.health = 100
		game.player.invulnerability = 0
		# Clear any pickups collected while placing the player for the AI test.
		game.coins = 0
		game.coins_found = 0
	# Real movement and collision through the physics server.
	game.player.position = Vector3(0, 0.05, 0)
	game.player.rotation.y = 0
	Input.action_press("forward")
	await frames(50)
	Input.action_release("forward")
	check(game.player.position.z > -1.83 and game.player.position.z < -1.4, "W moves and stops at a solid wall")
	game.player.position = game.maze.center(Vector2i(1, 0))
	game.player.velocity = Vector3.ZERO
	game.player.rotation.y = PI
	await frames(3)
	Input.action_press("jump")
	await frames(12)
	Input.action_release("jump")
	check(game.player.position.y > 0.3, "space jumps")
	await frames(40)
	check(game.player.is_on_floor(), "jump lands on castle floor")
	# Pickups are collected by proximity and cannot award twice.
	game.player.position = game.maze.center(Vector2i(1, 1))
	game.player.velocity = Vector3.ZERO
	await frames(3)
	check(game.coins == 3, "first coin awards three gold")
	await frames(3)
	check(game.coins == 3, "coin only collected once")
	game.player.position = game.maze.center(Vector2i(1, 2))
	await frames(3)
	check(game.coins == 6, "safe courtyard funds the stick")
	# Shopping validates order and funds, deducts exactly once and accumulates reach.
	game.set_mode("shop")
	check(not game.buy(2), "cannot skip the stick")
	check(game.buy(1), "can buy first stick")
	check(game.weapon_tier == 1 and game.coins == 0, "stick equipped with correct balance")
	check(not game.buy(1), "cannot purchase the same weapon twice")
	check(not game.buy(2), "insufficient funds rejected")
	game.coins = 100
	for tier in range(2, 5):
		check(game.buy(tier), "sequential weapon upgrade %d" % tier)
		check(game.WEAPONS[tier].reach > game.WEAPONS[tier - 1].reach, "reach increases")
	check(game.coins == 16, "total upgrade costs correctly deducted")
	game.set_mode("playing")
	game.player.position = game.maze.center(Vector2i(1, 0))
	game.player.velocity = Vector3.ZERO
	game.player.rotation.y = PI
	game.player.camera.rotation.x = 0
	var enemy = game.enemies[0]
	enemy.position = game.player.position + Vector3(0, 0.05, 3.2)
	await frames(3)
	game.player.attack_cooldown = 0
	game.player.attack()
	check(enemy.dead, "halberd hits and kills at extended reach")
	check(game.kills == 1 and game.coins == 21, "kill rewards gold once")
	# Test wall occlusion in melee, independently from distance.
	var other = game.enemies[1]
	game.player.position = Vector3(0, 0.02, -1.3)
	game.player.rotation.y = 0
	other.position = Vector3(0, 0.02, -3.7)
	await frames(3)
	var old_health = other.health
	game.player.attack_cooldown = 0
	game.player.attack()
	check(other.health == old_health, "weapons cannot strike through walls")
	game.player.invulnerability = 0
	game.player.health = 100
	game.player.hurt(20, game.player.position + Vector3(0, 0, -1))
	check(game.player.health == 80, "enemy damage applies")
	game.player.hurt(20, game.player.position + Vector3(0, 0, -1))
	check(game.player.health == 80, "invulnerability prevents stacked instant damage")
	game.player.invulnerability = 0
	game.player.blocking = true
	game.player.stamina = 100
	game.player.hurt(20, game.player.position + Vector3(0, 0, -1))
	check(game.player.health == 76 and game.player.stamina == 83, "front shield blocks 80 percent and spends stamina")
	game.player.health = 40
	game.spawn_pickup(game.player.position, true)
	await frames(3)
	check(game.player.health == 75, "tonic restores 35 health")
	game.player.blocking = false
	game.player.invulnerability = 0
	game.player.hurt(200, game.player.position)
	check(game.state == "dead", "death opens retry screen")
	game.restart()
	check(game.player.health == 100 and game.weapon_tier == 4 and game.coins == 21 and game.level == 1, "retry restores health and preserves gear, coins and level")
	check(game.maze.cells == original_layout, "retry preserves maze seed")
	game.set_mode("paused")
	var paused_time = game.elapsed
	var paused_pos = game.player.position
	Input.action_press("forward")
	await frames(10)
	Input.action_release("forward")
	check(game.elapsed == paused_time and game.player.position == paused_pos, "pause freezes movement and timer")
	game.set_mode("playing")
	game.player.position = game.maze.center(game.maze.exit_cell)
	await frames(3)
	check(game.state == "victory", "entering green portal wins")
	game.restart(true)
	check(game.current_seed != 734291 and game.maze.cells != original_layout, "new maze creates a different layout")
	check(game.level == 1 and game.coins == 0 and game.weapon_tier == 0, "explicit new journey resets progression")
	if failures.is_empty():
		print("PASS: ", checks, " checks — maze graph, input, collision, jumping, pickups, purchases, combat, shield, death, pause, portal and replay.")
	else:
		print("FAILED: ", failures.size(), " / ", checks, " checks: ", failures)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
