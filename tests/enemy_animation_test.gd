extends SceneTree

var game: ThornholdGame
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(50).timeout.connect(func(): push_error("Enemy animation test timed out"); quit(1))
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func settle_attack(enemy: MazeEnemy) -> void:
	await frames(ceili(enemy.attack_duration * 60.0) + 3)
	enemy.set_physics_process(false)
	enemy.attack_age = -1.0
	enemy.attack_timer = 10.0

func reset_encounter(enemy: MazeEnemy) -> void:
	game.set_mode("playing")
	game.player.position = game.maze.center(Vector2i(1, 1))
	game.player.velocity = Vector3.ZERO
	game.player.rotation.y = PI
	game.player.health = 100
	game.player.invulnerability = 0
	game.player.blocking = false
	enemy.position = game.player.position + Vector3(0, 0, 1.08)
	enemy.velocity = Vector3.ZERO
	enemy.knockback = Vector3.ZERO
	enemy.stun = 0
	enemy.attack_age = -1
	enemy.attack_timer = 10
	enemy.alert = true
	enemy.memory = 100
	enemy.last_seen = game.maze.cell_at(game.player.position)
	enemy.path_timer = 0
	enemy.set_physics_process(true)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	game.capture_path = "animation-test"
	game.capture_frames = 100000
	game.start()
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
	for kind in range(3):
		var hunter: MazeEnemy
		for enemy in game.enemies:
			if is_instance_valid(enemy) and enemy.kind == kind:
				hunter = enemy
				break
		var visual = hunter.model
		check(visual.skeleton.get_bone_count() == (18 if kind == 0 else 19), "correct imported rig for kind %d" % kind)
		check(visual.imported_model.find_children("*", "MeshInstance3D", true, false).size() == 1, "single skinned GLB mesh for kind %d" % kind)
		check(is_equal_approx(absf(visual.imported_model.rotation.y), PI), "GLB facing corrected for kind %d" % kind)
		for clip: StringName in [&"idle", &"walk", &"run", &"attack", &"hit", &"death"]:
			check(visual.animator.has_animation(clip), "clip %s exists for kind %d" % [clip, kind])
		# A real animation track changes the leg pose in the imported skeleton.
		var leg = visual.skeleton.find_bone("front_upper.L" if kind == 1 else "thigh.L")
		visual.tick(0.16, EnemyVisual.WALK_SPEED[kind], false)
		var pose_a = visual.skeleton.get_bone_pose_rotation(leg)
		visual.tick(0.23, EnemyVisual.WALK_SPEED[kind], false)
		var pose_b = visual.skeleton.get_bone_pose_rotation(leg)
		check(pose_a.angle_to(pose_b) > 0.02, "walking deforms the leg skeleton for kind %d" % kind)
		visual.tick(0.16, EnemyVisual.RUN_SPEED[kind], true)
		check(visual.state == &"run", "chase selects run for kind %d" % kind)
		visual.tick(0.2, 0.0, false)
		check(visual.state == &"idle", "standing selects idle for kind %d" % kind)
		reset_encounter(hunter)
		hunter.begin_attack()
		check(game.player.health == 100 and visual.state == &"attack", "windup begins before damage for kind %d" % kind)
		await frames(2)
		game.set_mode("shop")
		var paused_age = hunter.attack_age
		var paused_animation = visual.animator.current_animation_position
		await frames(6)
		check(hunter.attack_age == paused_age and visual.animator.current_animation_position == paused_animation, "armory pauses attack clock and animation for kind %d" % kind)
		game.set_mode("playing")
		await frames(maxi(1, floori((hunter.strike_time - hunter.attack_age) * 60.0) - 3))
		check(game.player.health == 100, "no damage before impact for kind %d" % kind)
		await frames(6)
		check(is_equal_approx(game.player.health, 100.0 - hunter.damage), "impact deals damage for kind %d" % kind)
		game.player.invulnerability = 0
		await settle_attack(hunter)
		check(is_equal_approx(game.player.health, 100.0 - hunter.damage), "one damage event per swing for kind %d" % kind)
		reset_encounter(hunter)
		hunter.begin_attack()
		game.player.position.x += 3.0
		await settle_attack(hunter)
		check(game.player.health == 100, "moving out of range avoids impact for kind %d" % kind)
		reset_encounter(hunter)
		hunter.begin_attack()
		var wall = CastleArt.solid_box(game.world, game.player.position + Vector3(0, 1.1, 0.54), Vector3(1.5, 2.2, 0.08))
		await settle_attack(hunter)
		check(game.player.health == 100, "wall added during windup blocks impact for kind %d" % kind)
		wall.free()
		reset_encounter(hunter)
		hunter.begin_attack()
		hunter.take_hit(1.0, Vector3.ZERO)
		check(hunter.attack_age < 0 and visual.state == &"hit", "hit interrupts attack for kind %d" % kind)
		await settle_attack(hunter)
		check(game.player.health == 100, "interrupted attack cannot deliver delayed damage for kind %d" % kind)
		reset_encounter(hunter)
		game.player.blocking = true
		game.player.stamina = 100
		hunter.begin_attack()
		await settle_attack(hunter)
		check(is_equal_approx(game.player.health, 100.0 - hunter.damage * 0.2), "shield is evaluated at impact for kind %d" % kind)
		reset_encounter(hunter)
		var previous_gold = game.coins
		hunter.begin_attack()
		hunter.take_hit(10000, Vector3.ZERO)
		check(hunter.dead and visual.state == &"death", "lethal hit starts skeletal death for kind %d" % kind)
		check(hunter.collision_layer == 0 and hunter.collision_mask == 0, "corpse stops blocking for kind %d" % kind)
		hunter.take_hit(10000, Vector3.ZERO)
		check(game.coins == previous_gold + [5, 4, 12][kind], "death rewards once for kind %d" % kind)
		game.set_mode("paused")
		var corpse_time = hunter.death_elapsed
		await frames(5)
		check(hunter.death_elapsed == corpse_time, "pause freezes death and cleanup for kind %d" % kind)
		game.set_mode("playing")
		await frames(ceili((EnemyAnimationFactory.DEATH_LENGTHS[kind] + 1.65) * 60.0))
		check(not is_instance_valid(hunter), "animated corpse is cleaned up for kind %d" % kind)
		check(game.player.health == 100, "death cancels pending strike for kind %d" % kind)
	print("PASS: %d enemy animation checks — models, bone motion, pause, impacts, dodges, walls, interruptions, shields and deaths." % checks if failures.is_empty() else "FAILED: " + str(failures))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
