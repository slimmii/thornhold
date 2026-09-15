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

var kind: int
var imported_model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var state: StringName = &"idle"
var action_remaining: float = 0.0

func configure(enemy_kind: int, phase: float = 0.0) -> void:
	kind = enemy_kind
	name = "EnemyVisual"
	imported_model = (MODELS[kind] as PackedScene).instantiate()
	imported_model.name = "Model"
	# Blender's glTF export faces +Z; the game's steering convention faces -Z.
	imported_model.rotation.y = PI
	imported_model.scale = Vector3.ONE * MODEL_SCALE[kind]
	add_child(imported_model)
	skeleton = imported_model.find_children("*", "Skeleton3D", true, false)[0]
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

func play_action(action: StringName, rate: float = 1.0) -> void:
	if state == &"death":
		return
	state = action
	action_remaining = Motion.duration(kind, action) / rate
	animator.play(action, 0.06, rate)
	animator.seek(0, true)
	animator.advance(0)

func tick(delta: float, movement_speed: float, chasing: bool) -> void:
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
