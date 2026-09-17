class_name MazePlayer
extends CharacterBody3D

var game
var camera: Camera3D
var viewmodel: Node3D
# Scale both the models and their camera offsets: perspective keeps their
# screen size, while every swing stays inside the player's wall clearance.
const VIEWMODEL_SCALE = 0.1
var hand: Node3D
var shield: Node3D
var health: float = 100
var stamina: float = 100
var attack_cooldown: float = 0
var swing: float = 0
var invulnerability: float = 0
var step_clock: float = 0
var bob_clock: float = 0
var blocking = false
var sprinting = false
var mouse_sensitivity = 0.0024

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var shape = CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.76
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.89
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 78
	camera.near = 0.015
	camera.far = 160
	add_child(camera)
	camera.make_current()
	viewmodel = Node3D.new()
	viewmodel.name = "FirstPersonEquipment"
	viewmodel.scale = Vector3.ONE * VIEWMODEL_SCALE
	camera.add_child(viewmodel)
	hand = Node3D.new()
	viewmodel.add_child(hand)
	hand.position = Vector3(0.43, -0.43, -0.68)
	hand.rotation = Vector3(-0.28, -0.12, -0.22)
	CastleArt.weapon(hand, 0)
	shield = Node3D.new()
	viewmodel.add_child(shield)
	shield.position = Vector3(-0.48, -0.60, -0.85)
	var rim = CastleArt.cylinder(shield, Vector3.ZERO, 0.30, 0.30, 0.065, CastleArt.mat("b9a574"), 10)
	rim.rotation.x = PI / 2
	var face = CastleArt.cylinder(shield, Vector3(0, 0, 0.04), 0.26, 0.26, 0.025, CastleArt.mat("335760"), 10)
	face.rotation.x = PI / 2
	CastleArt.box(shield, Vector3(0, 0, 0.067), Vector3(0.04, 0.4, 0.02), CastleArt.mat("c6b680"))
	CastleArt.box(shield, Vector3(0, 0, 0.067), Vector3(0.33, 0.04, 0.02), CastleArt.mat("c6b680"))
	CastleArt.disable_equipment_shadows(shield)

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.state != "playing":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.35, 1.35)
	if event.is_action_pressed("attack"):
		attack()

func _physics_process(delta: float) -> void:
	if game == null or game.state != "playing":
		return
	attack_cooldown = maxf(0, attack_cooldown - delta)
	invulnerability = maxf(0, invulnerability - delta)
	swing = maxf(0, swing - delta * 3.4)
	blocking = Input.is_action_pressed("block") and stamina > 5
	var direction = Input.get_vector("left", "right", "forward", "back")
	sprinting = Input.is_action_pressed("sprint") and direction.length() > 0.1 and stamina > 1 and not blocking
	var speed = 6.3 if sprinting else 3.8
	if blocking:
		speed = 2.25
	stamina = clampf(stamina + delta * (-21 if sprinting else 16), 0, 100)
	var movement = global_basis * Vector3(direction.x, 0, direction.y)
	velocity.x = move_toward(velocity.x, movement.x * speed, delta * 28)
	velocity.z = move_toward(velocity.z, movement.z * speed, delta * 28)
	if not is_on_floor():
		velocity.y -= 20 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 6.0
	move_and_slide()
	var moving = Vector2(velocity.x, velocity.z).length() > 0.3 and is_on_floor()
	if moving:
		bob_clock += delta * (12 if sprinting else 8)
		step_clock += delta
		if step_clock > (0.31 if sprinting else 0.48):
			step_clock = 0
			game.sound.play("step", 0.23)
	camera.position.y = lerpf(camera.position.y, 1.62 + (sin(bob_clock) * 0.037 if moving else 0.0), delta * 12)
	camera.fov = lerpf(camera.fov, 84.0 if sprinting else 78.0, delta * 6)
	update_equipment_pose(delta)
	if Input.is_action_pressed("attack") and attack_cooldown <= 0:
		attack()

func update_equipment_pose(delta: float) -> void:
	var arc = sin(swing * PI)
	hand.position = Vector3(0.43 - arc * 0.33, -0.43 + arc * 0.08 + sin(bob_clock) * 0.012, -0.68 - arc * 0.18)
	hand.rotation = Vector3(-0.28 - arc * 1.15, -0.12 + arc * 0.6, -0.22 + arc * 0.9)
	shield.position = shield.position.lerp(Vector3(-0.22, -0.18, -0.67) if blocking else Vector3(-0.48, -0.60, -0.85), delta * 12)

func attack() -> void:
	if attack_cooldown > 0 or blocking or game.state != "playing":
		return
	var stats = game.WEAPONS[game.weapon_tier]
	attack_cooldown = stats.cooldown
	swing = 1
	game.sound.play("swing", 0.5)
	var best = null
	var best_distance = INF
	var forward = -camera.global_basis.z
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		for target in enemy.melee_targets(camera.global_position):
			var offset = target - camera.global_position
			var distance = offset.length()
			if distance > stats.reach or distance >= best_distance:
				continue
			if distance > 0.001 and forward.dot(offset.normalized()) < 0.68:
				continue
			var query = PhysicsRayQueryParameters3D.create(camera.global_position, target, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			best = enemy
			best_distance = distance
	if best != null:
		best.take_hit(stats.damage, forward)
		game.hit_flash = 0.17
		game.sound.play("hit", 0.65)

func hurt(amount: float, source: Vector3) -> void:
	if invulnerability > 0 or game.state != "playing":
		return
	var incoming = (source - global_position).normalized()
	if blocking and (-global_basis.z).dot(incoming) > 0.2 and stamina >= 12:
		amount *= 0.2
		stamina = maxf(0, stamina - 17)
		game.sound.play("block", 0.7)
		game.toast("Shield raised · blow absorbed", 1.2)
	else:
		game.sound.play("hurt", 0.65)
	health = maxf(0, health - amount)
	invulnerability = 0.65
	game.damage_flash = 0.4
	if health <= 0:
		game.finish(false)
