class_name EnemyVisual
extends Node3D
## Imported, skinned enemy presentation. The owner advances it on physics ticks,
## so combat, animation, hit stun, pause, and corpse cleanup share one clock.

const Motion = preload("res://scripts/enemy_animation_factory.gd")
const MODELS = [
	preload("res://assets/enemies/blackguard-model/blackguard.glb"),
	preload("res://assets/enemies/ash-hound-model/ash-hound.glb"),
	preload("res://assets/enemies/horned-sentinel-model/horned-sentinel.glb")
]
const LIBRARIES = [
	preload("res://assets/enemies/animations/blackguard.res"),
	preload("res://assets/enemies/animations/ash-hound.res"),
	preload("res://assets/enemies/animations/horned-sentinel.res")
]
const MODEL_SCALE = [1.0, 0.86, 0.95]
const WALK_SPEED = [1.17, 1.534, 1.014]
const RUN_SPEED = [2.25, 2.95, 1.95]
# Combat regions in the hound GLB's rest coordinates (+Z forward, before its
# 180-degree facing correction and 0.86 scale). Small overlapping volumes
# follow the rig rather than using the navigation capsule as a damage target.
const HOUND_HIT_REGIONS = [
	["pelvis", Vector3(0, 0.91, -0.58), Vector3(0.94, 0.66, 0.88)],
	["chest", Vector3(0, 1.02, 0.29), Vector3(0.88, 0.72, 1.0)],
	["head", Vector3(0, 1.36, 1.10), Vector3(0.62, 0.78, 0.58)],
	["head", Vector3(0, 1.16, 1.49), Vector3(0.40, 0.32, 0.44)],
	["front_upper.L", Vector3(0.34, 0.55, 0.56), Vector3(0.38, 1.04, 0.52)],
	["front_upper.R", Vector3(-0.34, 0.55, 0.56), Vector3(0.38, 1.04, 0.52)],
	["hind_upper.L", Vector3(0.37, 0.50, -0.60), Vector3(0.38, 0.95, 0.56)],
	["hind_upper.R", Vector3(-0.37, 0.50, -0.60), Vector3(0.38, 0.95, 0.56)]
]

var kind: int
var imported_model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var state: StringName = &"idle"
var action_remaining: float = 0.0
var update_interval: float = 0.0
var accumulated_delta: float = 0.0
var melee_regions: Array[Dictionary] = []

func configure(enemy_kind: int, phase: float = 0.0) -> void:
	kind = enemy_kind
	name = "EnemyVisual"
	imported_model = (MODELS[kind] as PackedScene).instantiate()
	imported_model.name = "Model"
	# Blender's glTF export faces +Z; the game's steering convention faces -Z.
	imported_model.rotation.y = PI
	imported_model.scale = Vector3.ONE * MODEL_SCALE[kind]
	add_child(imported_model)
	CastleArt.style_imported_model(imported_model)
	skeleton = imported_model.find_children("*", "Skeleton3D", true, false)[0]
	if kind == 1:
		for region in HOUND_HIT_REGIONS:
			var bone = skeleton.find_bone(region[0])
			melee_regions.append({"bone": bone,
				"rest_inverse": skeleton.get_bone_global_rest(bone).affine_inverse(),
				"bounds": AABB(region[1] - region[2] * 0.5, region[2])})
	for mesh: MeshInstance3D in imported_model.find_children("*", "MeshInstance3D", true, false):
		# Weapon swings and death poses extend beyond the resting mesh bounds.
		mesh.extra_cull_margin = 3.5
	animator = AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.root_node = NodePath("..")
	add_child(animator)
	animator.add_animation_library(&"", LIBRARIES[kind])
	animator.play(&"idle")
	animator.seek(fposmod(phase, Motion.duration(kind, "idle")), true)
	animator.advance(0)

func melee_targets(origin: Vector3) -> Array[Vector3]:
	var targets: Array[Vector3] = []
	for region in melee_regions:
		var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(region.bone) * region.rest_inverse
		var local_origin = pose.affine_inverse() * origin
		var bounds: AABB = region.bounds
		# Reach is measured to the nearest surface, allowing a visible muzzle
		# or flank to be struck even when the enemy's center is farther away.
		targets.append(pose * local_origin.clamp(bounds.position, bounds.end))
	return targets

func play_action(action: StringName, rate: float = 1.0) -> void:
	if state == &"death":
		return
	state = action
	accumulated_delta = 0.0
	action_remaining = Motion.duration(kind, action) / rate
	animator.play(action, 0.06, rate)
	animator.seek(0, true)
	animator.advance(0)

func tick(delta: float, movement_speed: float, chasing: bool) -> void:
	accumulated_delta += delta
	if accumulated_delta + 0.00001 < update_interval:
		return
	delta = accumulated_delta
	accumulated_delta = 0.0
	if action_remaining > 0.0 or state == &"death":
		animator.advance(delta)
		action_remaining = maxf(0.0, action_remaining - delta)
		return
	var next_state: StringName = &"idle"
	var rate = 1.0
	if movement_speed > 0.12:
		next_state = &"run" if chasing else &"walk"
		rate = clampf(movement_speed / (RUN_SPEED[kind] if chasing else WALK_SPEED[kind]), 0.35, 1.7)
	if next_state != state:
		state = next_state
		animator.play(state, 0.12, rate)
	else:
		animator.speed_scale = 1.0
		# play() on the same clip changes its rate without restarting its phase.
		animator.play(state, -1.0, rate)
	animator.advance(delta)
