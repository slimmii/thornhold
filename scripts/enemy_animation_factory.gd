class_name EnemyAnimationFactory
extends RefCounted
## Bakes reusable Godot skeleton tracks from the imported rigs' actual rest axes.
## Clip translations are visual only. CharacterBody3D owns movement/collision.

const SLUGS = ["blackguard", "ash-hound", "horned-sentinel"]
const STRIKE_TIMES = [0.30, 0.23, 0.46]
const ATTACK_LENGTHS = [0.82, 0.66, 1.08]
const DEATH_LENGTHS = [1.05, 0.90, 1.20]
const CLIPS = ["idle", "walk", "run", "attack", "hit", "death"]

static func build(kind: int, skeleton: Skeleton3D, skeleton_path: NodePath) -> AnimationLibrary:
	var library = AnimationLibrary.new()
	for clip: String in CLIPS:
		var animation = Animation.new()
		animation.resource_name = SLUGS[kind] + "_" + clip
		animation.length = duration(kind, clip)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in ["idle", "walk", "run"] else Animation.LOOP_NONE
		var rotation_tracks: Array[int] = []
		for bone in range(skeleton.get_bone_count()):
			var track = animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(str(skeleton_path) + ":" + skeleton.get_bone_name(bone)))
			rotation_tracks.append(track)
		var position_track = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position_track, NodePath(str(skeleton_path) + ":root"))
		var times: Array[float] = []
		var samples = ceili(animation.length * 30.0)
		for sample in range(samples + 1):
			times.append(animation.length * float(sample) / float(samples))
		if clip == "attack":
			times.append(STRIKE_TIMES[kind])
			times.sort()
		for time in times:
			var pose = sample_pose(kind, clip, time / animation.length)
			for bone in range(skeleton.get_bone_count()):
				var angles: Vector3 = pose.get(skeleton.get_bone_name(bone), Vector3.ZERO)
				var rest = skeleton.get_bone_rest(bone).basis.orthonormalized()
				var global_rest = skeleton.get_bone_global_rest(bone).basis.orthonormalized()
				# Convert model-space anatomical rotations to each bone's rest frame.
				var local_delta = global_rest.inverse() * Basis.from_euler(angles) * global_rest
				var rotation = (rest * local_delta).get_rotation_quaternion().normalized()
				animation.rotation_track_insert_key(rotation_tracks[bone], time, rotation)
			var offset: Vector3 = pose.get("offset", Vector3.ZERO)
			animation.position_track_insert_key(position_track, time, skeleton.get_bone_rest(skeleton.find_bone("root")).origin + offset)
		library.add_animation(clip, animation)
	return library

static func duration(kind: int, clip: String) -> float:
	match clip:
		"idle": return 2.8
		"walk": return [1.04, 0.92, 1.20][kind]
		"run": return [0.70, 0.54, 0.86][kind]
		"attack": return ATTACK_LENGTHS[kind]
		"hit": return 0.38
		"death": return DEATH_LENGTHS[kind]
	return 1.0

static func sample_pose(kind: int, clip: String, phase: float) -> Dictionary:
	if clip == "attack":
		return sample_attack(kind, phase)
	if clip == "death":
		return sample_death(kind, phase)
	if clip == "hit":
		var recoil = sin(PI * phase) * (1.0 - phase)
		return {"chest": Vector3(-0.22, 0.08, 0.07) * recoil,
			"head": Vector3(-0.19, -0.10, 0.08) * recoil,
			"neck": Vector3(-0.12, 0.0, 0.0) * recoil,
			"jaw": Vector3(0.22 * recoil, 0, 0),
			"upper_arm.R": Vector3(-0.30, 0, -0.10) * recoil,
			"offset": Vector3(0, -0.035, -0.07) * recoil}
	var cycle = TAU * phase
	var breath = sin(cycle)
	if clip == "idle":
		return {"chest": Vector3(0.014 * breath, 0, 0),
			"neck": Vector3(0.018 * breath, 0.025 * sin(cycle), 0),
			"head": Vector3(-0.012 * breath, 0.026 * sin(cycle), 0),
			"forearm.R": Vector3(0.016 * breath, 0, 0),
			"jaw": Vector3(0.025 + 0.015 * breath, 0, 0),
			"offset": Vector3(0, 0.006 * (1.0 - cos(cycle)), 0)}
	var running = clip == "run"
	if kind == 1:
		return sample_hound_gait(cycle, running)
	var amplitude = 0.48 if running else 0.30
	if kind == 2:
		amplitude *= 0.82
	var pose: Dictionary = {"chest": Vector3(0.065 if running else 0.015, sin(cycle) * 0.035, 0),
		"head": Vector3(-0.04 if running else 0.0, -sin(cycle) * 0.02, 0),
		"offset": Vector3(0, 0.026 * (1.0 - cos(cycle * 2.0)), 0)}
	for side: String in ["L", "R"]:
		var wave = sin(cycle + (PI if side == "R" else 0.0))
		var thigh = -amplitude * wave
		var knee = (0.56 if running else 0.30) * maxf(0.0, -wave)
		pose["thigh." + side] = Vector3(thigh, 0, 0)
		pose["shin." + side] = Vector3(knee, 0, 0)
		pose["foot." + side] = Vector3(-thigh - knee, 0, 0)
		var arm_swing = 0.20 if side == "R" else 0.10
		pose["upper_arm." + side] = Vector3(wave * arm_swing, 0, 0)
		pose["forearm." + side] = Vector3(-0.08 - maxf(0.0, -wave) * 0.10, 0, 0)
	return pose

static func sample_hound_gait(cycle: float, running: bool) -> Dictionary:
	var pose: Dictionary = {"spine": Vector3(0.03 * sin(cycle), 0, 0),
		"chest": Vector3(0.035 * sin(cycle), 0, 0),
		"neck": Vector3(-0.04 * sin(cycle), 0, 0),
		"head": Vector3(0.04 * sin(cycle), 0, 0),
		"jaw": Vector3(0.12 if running else 0.03, 0, 0),
		"offset": Vector3(0, (0.045 if running else 0.018) * (1.0 - cos(cycle * 2.0)), 0)}
	var phases = [0.0, 0.14, 0.50, 0.64] if running else [0.0, 0.5, 0.75, 0.25]
	for i in range(4):
		var prefix = "front_" if i < 2 else "hind_"
		var side = "L" if i % 2 == 0 else "R"
		var wave = sin(cycle + TAU * phases[i])
		var upper = -(0.38 if running else 0.24) * wave
		var lower = (0.40 if running else 0.20) * maxf(0, -wave)
		pose[prefix + "upper." + side] = Vector3(upper, 0, 0)
		pose[prefix + "lower." + side] = Vector3(lower, 0, 0)
		pose[prefix + "paw." + side] = Vector3(-upper - lower, 0, 0)
	return pose

static func sample_attack(kind: int, phase: float) -> Dictionary:
	var impact: float = STRIKE_TIMES[kind] / ATTACK_LENGTHS[kind]
	if kind == 1:
		return interpolate(phase, [
			[0.0, {}],
			[impact * 0.72, {"neck": Vector3(-0.16, 0, 0), "head": Vector3(-0.12, 0, 0),
				"jaw": Vector3(0.60, 0, 0), "chest": Vector3(-0.06, 0, 0), "offset": Vector3(0, -0.025, -0.08)}],
			[impact, {"neck": Vector3(0.12, 0, 0), "head": Vector3(0.09, 0, 0),
				"jaw": Vector3(0.05, 0, 0), "chest": Vector3(0.04, 0, 0), "offset": Vector3(0, 0.025, 0.18),
				"front_upper.L": Vector3(-0.18, 0, 0), "front_upper.R": Vector3(-0.18, 0, 0)}],
			[0.68, {"jaw": Vector3(0.08, 0, 0), "offset": Vector3(0, 0, 0.06)}], [1.0, {}]])
	if kind == 0:
		return interpolate(phase, [
			[0.0, {}],
			[impact * 0.75, {"upper_arm.R": Vector3(-1.55, -0.20, -0.10), "forearm.R": Vector3(-0.50, 0, 0),
				"hand.R": Vector3(0, 0, 0.20), "chest": Vector3(-0.04, -0.16, 0),
				"upper_arm.L": Vector3(-0.22, 0, 0.06), "offset": Vector3(0, -0.015, -0.03)}],
			[impact, {"upper_arm.R": Vector3(-0.90, 0.22, 0.05), "forearm.R": Vector3(0.14, 0, 0),
				"hand.R": Vector3(0.24, 0, -0.22), "chest": Vector3(0.13, 0.14, 0),
				"upper_arm.L": Vector3(-0.16, 0, 0.04), "offset": Vector3(0, -0.025, 0.12)}],
			[0.65, {"upper_arm.R": Vector3(-0.28, 0.32, 0.10), "forearm.R": Vector3(0.05, 0, 0),
				"chest": Vector3(0.07, 0.08, 0), "offset": Vector3(0, -0.01, 0.045)}], [1.0, {}]])
	return interpolate(phase, [
		[0.0, {}],
		[impact * 0.74, {"upper_arm.R": Vector3(-1.22, -0.10, 0), "forearm.R": Vector3(-0.32, 0, 0),
			"hand.R": Vector3(1.02, 0, 0), "chest": Vector3(-0.06, -0.12, 0),
			"upper_arm.L": Vector3(-0.20, 0, 0.10), "offset": Vector3(0, -0.025, -0.06)}],
		[impact, {"upper_arm.R": Vector3(-0.74, 0.12, 0), "forearm.R": Vector3(-0.13, 0, 0),
			"hand.R": Vector3(2.15, 0, 0), "chest": Vector3(0.19, 0.14, 0),
			"upper_arm.L": Vector3(-0.11, 0, 0.08), "offset": Vector3(0, -0.13, 0.16)}],
		[0.67, {"upper_arm.R": Vector3(-0.43, 0.16, 0), "forearm.R": Vector3(-0.10, 0, 0),
			"hand.R": Vector3(1.73, 0, 0), "chest": Vector3(0.10, 0.08, 0), "offset": Vector3(0, -0.05, 0.04)}],
		[1.0, {}]])

static func sample_death(kind: int, phase: float) -> Dictionary:
	if kind == 1:
		return interpolate(phase, [[0.0, {}],
			[0.24, {"root": Vector3(0, 0, 0.28), "head": Vector3(-0.17, 0, 0), "offset": Vector3(0, -0.12, 0)}],
			[0.78, {"root": Vector3(0, 0, 1.53), "jaw": Vector3(0.30, 0, 0),
				"front_lower.L": Vector3(0.48, 0, 0), "hind_lower.L": Vector3(0.38, 0, 0), "offset": Vector3(0.08, 0.31, 0)}],
			[1.0, {"root": Vector3(0, 0, 1.50), "jaw": Vector3(0.23, 0, 0),
				"front_lower.L": Vector3(0.40, 0, 0), "hind_lower.L": Vector3(0.33, 0, 0), "offset": Vector3(0.08, 0.31, 0)}]])
	return interpolate(phase, [[0.0, {}],
		[0.22, {"chest": Vector3(-0.22, 0, 0.06), "head": Vector3(-0.17, 0, 0),
			"thigh.L": Vector3(-0.18, 0, 0), "thigh.R": Vector3(-0.18, 0, 0),
			"shin.L": Vector3(0.38, 0, 0), "shin.R": Vector3(0.38, 0, 0), "offset": Vector3(0, -0.12, 0)}],
		[0.82, {"root": Vector3(-1.50, 0, 0.08), "head": Vector3(0.07, 0.12, 0),
			"upper_arm.R": Vector3(-0.16, 0, -0.18), "upper_arm.L": Vector3(-0.12, 0, 0.24),
			"offset": Vector3(0, 0.25 if kind == 0 else 0.34, 0)}],
		[1.0, {"root": Vector3(-1.48, 0, 0.07), "head": Vector3(0.07, 0.12, 0),
			"upper_arm.R": Vector3(-0.16, 0, -0.18), "upper_arm.L": Vector3(-0.12, 0, 0.24),
			"offset": Vector3(0, 0.24 if kind == 0 else 0.33, 0)}]])

static func interpolate(phase: float, frames: Array) -> Dictionary:
	for i in range(1, frames.size()):
		if phase <= frames[i][0]:
			var start: Dictionary = frames[i - 1][1]
			var finish: Dictionary = frames[i][1]
			var weight: float = inverse_lerp(frames[i - 1][0], frames[i][0], phase)
			weight = smoothstep(0.0, 1.0, weight)
			var pose: Dictionary = {}
			for bone in start:
				pose[bone] = (start[bone] as Vector3).lerp(finish.get(bone, Vector3.ZERO), weight)
			for bone in finish:
				if not pose.has(bone):
					pose[bone] = Vector3.ZERO.lerp(finish[bone], weight)
			return pose
	return frames.back()[1]
