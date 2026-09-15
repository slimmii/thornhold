extends SceneTree

var game: ThornholdGame
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): push_error("Progression test timed out"); quit(1))
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
	# Level completion runs in _process, after any startup physics catch-up.
	await process_frame
	await process_frame

func freeze_enemies() -> void:
	for enemy in game.enemies:
		enemy.set_physics_process(false)

func advance() -> void:
	game.finish(true)
	game.next_level()
	freeze_enemies()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	await frames()
	game.start()
	freeze_enemies()
	var baseline = game.enemies[0]
	var base_health = baseline.max_health
	var base_damage = baseline.damage
	var base_speed = baseline.speed
	var base_hearing = baseline.hearing_range
	var base_memory = baseline.memory_duration
	var base_reaction = baseline.reaction_interval
	var original_seed = game.current_seed
	var original_layout = game.maze.cells.duplicate()
	game.coins = 60
	game.set_mode("shop")
	check(game.buy(1) and game.buy(2), "purchase a stick and sword before leaving level one")
	check(game.coins == 39, "purchases deducted before carryover")
	var sword_parts = game.player.hand.get_child_count()
	game.set_mode("playing")
	game.player.health = 40
	game.player.stamina = 25
	game.elapsed = 123
	game.kills = 2
	game.coins_found = 4
	game.show_map = true
	game.player.position = game.maze.center(game.maze.exit_cell)
	await frames()
	check(game.state == "victory" and game.level == 1, "portal shows the completed level before advancing")
	check(game.coins == 39 and game.weapon_tier == 2, "completion preserves inventory")
	check(game.hud.buttons[0].text == "Enter level 2  [Enter]", "completion offers the next level")
	game.hud.buttons[0].pressed.emit()
	freeze_enemies()
	check(game.state == "playing" and game.level == 2, "completion button advances exactly one level")
	check(game.current_seed != original_seed and game.maze.cells != original_layout, "next level creates a new maze")
	check(game.coins == 39 and game.weapon_tier == 2, "next level carries gold and equipment")
	check(game.player.hand.get_child_count() == sword_parts, "equipped sword model is rebuilt instead of fists")
	check(game.player.health == 100 and game.player.stamina == 100, "next level restores health and stamina")
	check(game.elapsed == 0 and game.kills == 0 and game.coins_found == 0, "level statistics reset")
	check(not game.show_map and game.discovered.size() < 10, "next maze starts with fresh exploration")
	game.next_level()
	check(game.level == 2, "repeated continue cannot skip a level")
	var hunter = game.enemies[0]
	check(hunter.max_health > base_health and hunter.damage > base_damage, "level two enemies are stronger")
	check(hunter.speed > base_speed and hunter.hearing_range > base_hearing, "level two enemies move faster and hear farther")
	check(hunter.memory_duration > base_memory and hunter.reaction_interval < base_reaction, "level two enemies remember longer and react faster")
	var junction = Vector2i(1, 1)
	var behind = Vector2i(1, 0)
	for i in range(12):
		hunter.previous_patrol_cell = behind
		check(hunter.choose_patrol_target(junction) != behind, "experienced patrol avoids immediately doubling back")
	hunter.alert = false
	hunter.remember_player(junction)
	hunter.search_previous_cell = behind
	var search_target = hunter.search_goal(junction)
	check(search_target in game.maze.neighbors(junction) and search_target != behind, "lost-target search explores an open adjoining passage")
	check(hunter.search_steps_left == 0, "level two search has a bounded budget")
	check(hunter.search_goal(search_target) == search_target, "search ends instead of tracking an unseen player forever")
	var ally = game.enemies[1]
	ally.alert = false
	hunter.call_allies()
	check(not ally.alert, "level two cannot yet call allies")
	game.set_mode("shop")
	check(not game.buy(1) and not game.buy(2), "already-owned equipment cannot be bought again")
	check(game.buy(3) and game.coins == 12, "carried coins can fund the next upgrade")
	game.set_mode("playing")
	advance()
	check(game.level == 3 and game.weapon_tier == 3 and game.coins == 12, "third level keeps the new spear and remaining gold")
	hunter = game.enemies[0]
	ally = game.enemies[1]
	var isolated = game.enemies[2]
	# Find adjacent cells separated by a wall and more than two real passages.
	var caller_cell = Vector2i.ZERO
	var isolated_cell = Vector2i.ZERO
	var found_wall = false
	for cell in game.maze.distances:
		for direction in CastleMaze.DIRECTIONS:
			var candidate = cell + direction
			if game.maze.inside(candidate) and game.maze.path(cell, candidate).size() > 2:
				caller_cell = cell
				isolated_cell = candidate
				found_wall = true
				break
		if found_wall:
			break
	check(found_wall, "found a wall for shout occlusion test")
	for enemy in game.enemies:
		enemy.alert = false
	hunter.position = game.maze.center(caller_cell)
	ally.position = game.maze.center(game.maze.neighbors(caller_cell)[0])
	isolated.position = game.maze.center(isolated_cell)
	var reported_cell = Vector2i(7, 7)
	hunter.remember_player(reported_cell)
	hunter.call_allies()
	check(ally.alert and ally.last_seen == reported_cell, "nearby ally follows the caller's reported sighting")
	check(not isolated.alert, "a nearby enemy across a long wall route cannot hear the shout")
	check(ally.memory > 0 and ally.memory < ally.memory_duration, "secondhand sightings have a shorter memory")
	advance()
	check(game.level == 4 and game.coins == 12 and game.weapon_tier == 3, "fourth level retains progression")
	hunter = game.enemies[1]
	hunter.tactic_id = 1
	hunter.alert = false
	hunter.remember_player(Vector2i(1, 2))
	hunter.remember_player(Vector2i(1, 3))
	check(hunter.interception_target(Vector2i(1, 0)) == Vector2i(1, 4), "hunter anticipates the next passage from observed motion")
	hunter.tactic_id = 0
	check(hunter.interception_target(Vector2i(1, 0)) == Vector2i(1, 3), "direct pursuer targets a different point than interceptor")
	hunter.tactic_id = 1
	hunter.last_seen = Vector2i(1, 0)
	hunter.observed_direction = Vector2i(0, -1)
	check(hunter.interception_target(Vector2i(1, 3)) == hunter.last_seen, "interception never projects through a closed boundary")
	# New levels continue scaling even after all tactics have unlocked.
	var prior_health = game.enemies[0].max_health
	var prior_damage = game.enemies[0].damage
	var prior_memory = game.enemies[0].memory_duration
	for target_level in range(5, 8):
		advance()
		hunter = game.enemies[0]
		check(game.level == target_level, "level number continues increasing")
		check(hunter.max_health > prior_health and hunter.damage > prior_damage, "later enemies continue gaining strength")
		check(hunter.memory_duration > prior_memory, "later enemies continue improving their tracking")
		check(game.coins == 12 and game.weapon_tier == 3, "inventory survives multiple consecutive exits")
		for enemy in game.enemies:
			check(enemy.speed < 6.3, "player can still outrun every enemy by sprinting")
		prior_health = hunter.max_health
		prior_damage = hunter.damage
		prior_memory = hunter.memory_duration
	var retry_seed = game.current_seed
	game.player.invulnerability = 0
	game.player.hurt(1000, game.player.position)
	check(game.state == "dead", "death interrupts a later level")
	game.next_level()
	check(game.level == 7 and game.state == "dead", "death cannot advance difficulty")
	var enter = InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	freeze_enemies()
	check(game.level == 7 and game.current_seed == retry_seed, "Enter after death retries the same level")
	check(game.coins == 12 and game.weapon_tier == 3 and game.player.health == 100, "retry keeps inventory and heals the player")
	game.finish(true)
	game._unhandled_input(enter)
	check(game.level == 8, "Enter after completion advances the level")
	game.restart(true)
	check(game.level == 1 and game.coins == 0 and game.weapon_tier == 0, "explicit new journey clears inventory and level")
	check(is_equal_approx(game.enemies[0].max_health, base_health), "new journey restores the original enemy difficulty")
	print("PASS: %d progression checks — carryover, transitions, scaling, search, ally alerts, interception and retries." % checks if failures.is_empty() else "FAILED: " + str(failures))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
