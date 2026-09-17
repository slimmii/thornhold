extends SceneTree
## Actual melee against the visible hound, including its rotating animated head.
var checks = 0
var failures: Array[String] = []
var game: ThornholdGame
var hound: MazeEnemy

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func posed_point(bone_name: String, rest_point: Vector3) -> Vector3:
	var skeleton = hound.model.skeleton
	var bone = skeleton.find_bone(bone_name)
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse() * rest_point

func aim_from(origin: Vector3, target: Vector3) -> void:
	game.player.position = origin - Vector3(0, 1.62, 0)
	game.player.rotation = Vector3.ZERO
	game.player.camera.position = Vector3(0, 1.62, 0)
	game.player.camera.look_at(target)
	game.player.attack_cooldown = 0
	game.player.blocking = false

func strike() -> bool:
	var health = hound.health
	game.player.attack()
	return hound.health < health

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.save_records = false
	game.set_process(false)
	game.state = "playing"
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		if enemy.kind == 1 and hound == null:
			hound = enemy
	# Isolate combat in empty space, outside the generated castle.
	game.enemies = [hound]
	hound.position = Vector3(-50, 0, -50)
	hound.health = 100000
	var cases = [
		["muzzle", "head", Vector3(0, 1.17, 1.60), Vector3(0, 0, -1)],
		["head", "head", Vector3(0.22, 1.30, 1.12), Vector3(-1, 0, 0)],
		["chest", "chest", Vector3(0.40, 1.02, 0.45), Vector3(-1, 0, 0)],
		["rump", "pelvis", Vector3(0, 0.94, -0.88), Vector3(0, 0, 1)],
		["front leg", "front_upper.L", Vector3(0.34, 0.55, 0.50), Vector3(-1, 0, 0)],
		["hind leg", "hind_upper.R", Vector3(-0.37, 0.50, -0.58), Vector3(1, 0, 0)]
	]
	for yaw in [0.0, PI / 2, PI, -PI / 2]:
		hound.model.rotation.y = yaw
		for clip in ["idle", "run", "attack"]:
			for phase in [0.0, 0.35, 0.7]:
				for entry in cases:
					hound.model.animator.play(clip)
					hound.model.animator.seek(EnemyAnimationFactory.duration(1, clip) * phase, true)
					hound.model.animator.advance(0)
					var target = posed_point(entry[1], entry[2])
					var outward: Vector3 = Basis(Vector3.UP, yaw) * entry[3]
					var origin = target + outward * 1.0
					origin.y = 1.62
					aim_from(origin, target)
					game.weapon_tier = 0
					check(strike(), "gauntlets hit %s at yaw %.2f during %s %.2f" % [entry[0], yaw, clip, phase])
	# Every weapon uses its actual reach from the head's surface, not the origin.
	hound.model.rotation.y = 0
	for tier in range(game.WEAPONS.size()):
		hound.model.animator.play("idle")
		hound.model.animator.seek(0, true)
		hound.model.animator.advance(0)
		var target = posed_point("head", Vector3(0, 1.17, 1.68))
		var reach: float = game.WEAPONS[tier].reach
		game.weapon_tier = tier
		aim_from(target + Vector3(0, 0.1, -(reach - 0.1)), target)
		check(strike(), "weapon %d reaches the visible muzzle" % tier)
		hound.model.animator.play("idle")
		hound.model.animator.seek(0, true)
		hound.model.animator.advance(0)
		aim_from(target + Vector3(0, 0.1, -(reach + 0.4)), target)
		check(not strike(), "weapon %d cannot hit beyond reach" % tier)
	# Preserve aim, wall blocking, cooldown and corpse behavior.
	game.weapon_tier = 4
	aim_from(hound.position + Vector3(0, 1.62, -3), hound.position + Vector3(0, 4, -3.1))
	check(not strike(), "swinging above the hound misses")
	var target = posed_point("head", Vector3(0, 1.17, 1.5))
	var origin = hound.position + Vector3(0, 1.62, -3)
	aim_from(origin, target)
	var wall = CastleArt.solid_box(game.world, hound.position + Vector3(0, 1.5, -2), Vector3(6, 3, 0.2))
	await physics_frame
	await physics_frame
	check(not strike(), "wall blocks strikes against every hound region")
	wall.free()
	aim_from(origin, target)
	check(strike(), "removing wall restores the hit")
	check(not strike(), "one swing cannot damage twice during cooldown")
	hound.take_hit(1000000, Vector3.ZERO)
	var kills = game.kills
	aim_from(origin, target)
	check(not strike() and game.kills == kills, "dead hound cannot be hit or reward twice")
	game.free()
	if failures.is_empty():
		print("PASS: %d hound melee checks" % checks)
		quit(0)
	else:
		print("FAILED: %d / %d hound melee checks" % [failures.size(), checks])
		quit(1)
