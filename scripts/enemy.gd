class_name MazeEnemy
extends CharacterBody3D

var game
var kind: int = 0
var tactic_id: int = 0
var health: float = 60
var max_health: float = 60
var target_height: float = 1.4
var speed: float = 2.25
var damage: float = 14
var dead = false
var alert = false
var memory: float = 0
var attack_timer: float = 1.0
var path_timer: float = 0
var stun: float = 0
var age: float = 0
var model: EnemyVisual
var attack_age: float = -1.0
var attack_duration: float = 0.0
var strike_time: float = 0.0
var strike_applied: bool = false
var death_elapsed: float = 0.0
var route: Array[Vector2i] = []
var patrol_target = Vector2i.ZERO
var home = Vector2i.ZERO
var last_seen = Vector2i.ZERO
var knockback = Vector3.ZERO
var hearing_range: float = 10.5
var sight_range: float = 18.0
var memory_duration: float = 9.0
var reaction_interval: float = 0.65
var attack_interval: float = 1.1
var alert_cooldown: float = 0
var previous_patrol_cell = Vector2i(-1, -1)
var search_previous_cell = Vector2i(-1, -1)
var search_target = Vector2i.ZERO
var search_steps_left: int = 0
var observed_direction = Vector2i.ZERO

func configure_difficulty() -> void:
	var threat = float(maxi(0, game.level - 1))
	var growth = threat / (threat + 8.0)
	health *= 1.0 + threat * 0.22
	damage *= 1.0 + threat * 0.13
	# Speed stays below player sprint speed, even in very late levels.
	speed *= 1.0 + growth * 0.35
	hearing_range = 10.5 + growth * 16.0
	sight_range = 18.0 + growth * 18.0
	memory_duration = 9.0 + growth * 24.0
	reaction_interval = (0.65 + kind * 0.13) / (1.0 + growth * 2.0)
	attack_interval = (1.5 if kind == 2 else 1.1) / (1.0 + growth * 0.4)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	if kind == 1:
		health = 42
		speed = 2.95
		damage = 10
		target_height = 0.85
	elif kind == 2:
		health = 135
		speed = 1.95
		damage = 25
		target_height = 1.8
	configure_difficulty()
	max_health = health
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.43 if kind != 2 else 0.61
	shape.height = 1.5 if kind != 2 else 2.7
	collision.shape = shape
	collision.position.y = shape.height / 2
	add_child(collision)
	model = EnemyVisual.new()
	add_child(model)
	model.configure(kind, float(tactic_id) * 0.37)
	home = game.maze.cell_at(position)
	patrol_target = home
	last_seen = home
	search_target = home
	age = float(get_instance_id() % 100)

func _physics_process(delta: float) -> void:
	if game == null or game.state != "playing":
		return
	# Only presentation is throttled; navigation, collisions, and strike timing
	# keep their physics cadence even when a hunter is far from the player.
	model.update_interval = 1.0 / 15.0 if game.web_profile and position.distance_squared_to(game.player.position) > 400.0 else 0.0
	if dead:
		death_elapsed += delta
		model.tick(delta, 0.0, false)
		var disappear_at = EnemyAnimationFactory.DEATH_LENGTHS[kind] + 1.1
		if death_elapsed > disappear_at:
			var dissolve = clampf((death_elapsed - disappear_at) / 0.45, 0.0, 1.0)
			model.scale = Vector3.ONE * lerpf(1.0, 0.001, dissolve)
			if dissolve >= 1.0:
				queue_free()
		return
	age += delta
	attack_timer -= delta
	stun = maxf(0, stun - delta)
	path_timer -= delta
	alert_cooldown = maxf(0, alert_cooldown - delta)
	var player = game.player
	var distance = global_position.distance_to(player.global_position)
	var cell = game.maze.cell_at(global_position)
	var player_cell = game.maze.cell_at(player.global_position)
	if path_timer <= 0:
		path_timer = reaction_interval
		var hearing = hearing_range + (6.5 if player.sprinting else 0.0)
		var route_to_player = game.maze.path(cell, player_cell)
		var can_hear = route_to_player.size() * CastleMaze.CELL < hearing
		var sight_query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, target_height, 0), player.global_position + Vector3(0, 1.3, 0), 1)
		var can_see = distance < sight_range and get_world_3d().direct_space_state.intersect_ray(sight_query).is_empty()
		if can_hear or can_see:
			if not alert and distance < 14:
				game.sound.play("growl", 0.38)
			remember_player(player_cell)
			if game.level >= 3 and alert_cooldown <= 0:
				call_allies()
		if alert:
			var goal = last_seen
			if can_see:
				goal = interception_target(cell)
			elif not can_hear and game.level >= 2:
				goal = search_goal(cell)
			route = game.maze.path(cell, goal)
		else:
			if route.is_empty() or cell == patrol_target:
				patrol_target = choose_patrol_target(cell)
			route = game.maze.path(cell, patrol_target)
		# First return to the cell center before taking a corner. This prevents wall cutting.
		var center = game.maze.center(cell)
		if not route.is_empty() and Vector2(position.x - center.x, position.z - center.z).length() > 0.5:
			var next_direction = (game.maze.center(route[0]) - center).normalized()
			var off_center = position - center
			if absf(off_center.x * next_direction.z - off_center.z * next_direction.x) > 0.4:
				route.push_front(cell)
	memory = maxf(0, memory - delta)
	if memory <= 0:
		if alert:
			route.clear()
		alert = false
	var target = global_position
	if not route.is_empty():
		target = game.maze.center(route[0])
		if Vector2(target.x - position.x, target.z - position.z).length() < 0.25:
			route.pop_front()
	elif alert and cell == player_cell and cell == last_seen:
		target = player.global_position
	var direction = target - global_position
	direction.y = 0
	var movement = direction.normalized() * speed * (1.0 if alert else 0.52)
	if distance < attack_reach() and alert:
		movement = Vector3.ZERO
		if attack_timer <= 0 and stun <= 0 and attack_age < 0:
			var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, target_height, 0), player.global_position + Vector3(0, 1.2, 0), 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				begin_attack()
	if attack_age >= 0:
		movement = Vector3.ZERO
	if stun > 0:
		movement *= 0.1
	knockback = knockback.move_toward(Vector3.ZERO, delta * 18)
	velocity.x = movement.x + knockback.x
	velocity.z = movement.z + knockback.z
	velocity.y -= 20 * delta
	move_and_slide()
	if direction.length() > 0.1 and attack_age < 0:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), delta * 7)
	advance_attack(delta)
	var actual_velocity = get_real_velocity()
	model.tick(delta, Vector2(actual_velocity.x, actual_velocity.z).length(), alert)

func attack_reach() -> float:
	return 1.65 if kind == 2 else 1.3

func melee_targets(origin: Vector3) -> Array[Vector3]:
	if kind == 1:
		return model.melee_targets(origin)
	return [global_position + Vector3(0, target_height, 0)]

func begin_attack() -> void:
	if dead or stun > 0.0 or attack_age >= 0.0:
		return
	var clip_length: float = EnemyAnimationFactory.ATTACK_LENGTHS[kind]
	attack_duration = minf(clip_length, attack_interval * 0.92)
	var rate = clip_length / attack_duration
	strike_time = EnemyAnimationFactory.STRIKE_TIMES[kind] / rate
	attack_age = 0.0
	strike_applied = false
	attack_timer = attack_interval
	var direction: Vector3 = game.player.global_position - global_position
	if Vector2(direction.x, direction.z).length() > 0.001:
		model.rotation.y = atan2(-direction.x, -direction.z)
	model.play_action(&"attack", rate)

func advance_attack(delta: float) -> void:
	if attack_age < 0.0 or dead:
		return
	attack_age += delta
	if not strike_applied and attack_age >= strike_time:
		strike_applied = true
		# Recheck the real target at impact: dodging, walls, and hit stun matter
		# during the windup, and the damage can be delivered only once per clip.
		var player = game.player
		var offset: Vector3 = player.global_position - global_position
		var flat = Vector3(offset.x, 0, offset.z)
		var facing = flat.length() < 0.001 or (-model.global_basis.z).dot(flat.normalized()) > 0.35
		if offset.length() < attack_reach() and facing:
			var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, target_height, 0), player.global_position + Vector3(0, 1.2, 0), 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				player.hurt(damage, global_position)
	if attack_age >= attack_duration:
		attack_age = -1.0

func remember_player(cell: Vector2i) -> void:
	var change = cell - last_seen
	if alert and abs(change.x) + abs(change.y) == 1:
		observed_direction = change
	elif not alert or change != Vector2i.ZERO:
		observed_direction = Vector2i.ZERO
	alert = true
	memory = memory_duration
	last_seen = cell
	search_target = cell
	search_previous_cell = cell - observed_direction
	search_steps_left = mini(game.level - 1, 6)

func choose_patrol_target(cell: Vector2i) -> Vector2i:
	var choices = game.maze.neighbors(cell)
	if game.level >= 2 and choices.size() > 1:
		choices.erase(previous_patrol_cell)
	previous_patrol_cell = cell
	return choices[game.maze.rng.randi_range(0, choices.size() - 1)]

func search_goal(cell: Vector2i) -> Vector2i:
	# Search the remembered trail and adjoining passages, without reading the
	# player's current cell after losing both sight and hearing.
	if cell == search_target and search_steps_left > 0:
		var choices = game.maze.neighbors(cell)
		if choices.size() > 1:
			choices.erase(search_previous_cell)
		var forward = cell + observed_direction
		search_target = forward if forward in choices else choices[game.maze.rng.randi_range(0, choices.size() - 1)]
		search_previous_cell = cell
		search_steps_left -= 1
	return search_target

func interception_target(cell: Vector2i) -> Vector2i:
	# Some hunters aim one passage ahead using movement they actually observed.
	# Others pursue directly, so coordinated hunters approach different points.
	if game.level < 4 or tactic_id % 3 == 0 or observed_direction == Vector2i.ZERO:
		return last_seen
	var ahead = last_seen + observed_direction
	if ahead not in game.maze.neighbors(last_seen):
		return last_seen
	if game.maze.path(cell, last_seen).size() < 2:
		return last_seen
	return ahead

func call_allies() -> void:
	if game.level < 3 or not alert:
		return
	alert_cooldown = 3.0
	var cell = game.maze.cell_at(position)
	var shout_range = mini(2 + (game.level - 3) / 2, 5)
	for ally in game.enemies:
		if not is_instance_valid(ally) or ally == self or ally.dead or ally.alert:
			continue
		var ally_cell = game.maze.cell_at(ally.position)
		if game.maze.path(cell, ally_cell).size() <= shout_range:
			ally.receive_alert(last_seen)

func receive_alert(cell: Vector2i) -> void:
	if dead or game.level < 3:
		return
	remember_player(cell)
	memory = memory_duration * 0.75
	path_timer = 0

func take_hit(amount: float, direction: Vector3) -> void:
	if dead:
		return
	health -= amount
	attack_age = -1.0
	stun = 0.38
	model.play_action(&"hit")
	knockback = Vector3(direction.x, 0, direction.z).normalized() * (3.0 if kind == 2 else 5.0)
	remember_player(game.maze.cell_at(game.player.global_position))
	memory = memory_duration + 3.0
	path_timer = 0
	game.target_enemy = self
	game.target_timer = 3
	if health <= 0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		game.kills += 1
		game.add_coins([5, 4, 12][kind])
		game.toast(["Blackguard defeated  ·  +5 gold", "Ash hound defeated  ·  +4 gold", "Horned sentinel defeated  ·  +12 gold"][kind], 2)
		game.sound.play("defeat", 0.5)
		model.play_action(&"death")

func display_name() -> String:
	return ["BLACKGUARD", "ASH HOUND", "HORNED SENTINEL"][kind]
