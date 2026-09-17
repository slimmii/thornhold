extends SceneTree
## Real Compatibility rendering: readable, stable comic colors with no lights.
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func capture(view: SubViewport) -> Image:
	for frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	return view.get_texture().get_image()

func sample(image: Image, camera: Camera3D, point: Vector3) -> Color:
	return image.get_pixelv(Vector2i(camera.unproject_position(point)))

func close_color(a: Color, b: Color) -> bool:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.02

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use an X11/Wayland display and the Compatibility renderer for this image-based check.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://builds/visual-checks")
	var reference: Array[Color] = []
	for web in [false, true]:
		var view = SubViewport.new()
		view.size = Vector2i(512, 512)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.positional_shadow_atlas_size = 0
		root.add_child(view)
		var environment = WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("9eafb5")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
		view.add_child(environment)
		var maze = CastleMaze.new()
		maze.web_profile = web
		view.add_child(maze)
		maze.brick(Vector3(0, 1, 0), Vector3(2, 2, 2), "97a9ac")
		maze.brick(Vector3(0, -0.05, 0), Vector3(8, 0.1, 8), "44565d")
		if web:
			maze.build_web_masonry()
		else:
			maze.build_native_masonry()
		var camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 7
		camera.position = Vector3(6, 5, 7)
		view.add_child(camera)
		camera.look_at(Vector3(0, 0.8, 0))
		camera.make_current()
		var points = [Vector3(0, 2, 0), Vector3(0, 1, 1), Vector3(1, 1, 0), Vector3(2, 0, 2)]
		var image: Image = await capture(view)
		var colors: Array[Color] = []
		for point in points:
			colors.append(sample(image, camera, point))
		check(colors[0].get_luminance() > colors[1].get_luminance() + 0.04 and colors[1].get_luminance() > colors[2].get_luminance() + 0.04, "three distinct face tones preserve depth without lights")
		check(colors[3].get_luminance() > 0.1, "floor remains readable without ambient or direct lighting")
		if web:
			for i in range(colors.size()):
				check(close_color(colors[i], reference[i]), "instance colors match native solid-color materials")
		else:
			reference = colors
		image.save_png("res://builds/visual-checks/comic-materials-%s.png" % web)
		# Move toward the same surfaces. Fixed world-space tones must not follow
		# the camera or depend on nearby light selection.
		camera.position = Vector3(4.5, 4.5, 5.5)
		camera.look_at(Vector3(0, 0.8, 0))
		image = await capture(view)
		for i in range(points.size()):
			check(close_color(sample(image, camera, points[i]), colors[i]), "surface tone stays stable when approaching")
		# An accidentally added light cannot affect these unshaded materials.
		var light = OmniLight3D.new()
		light.position = Vector3(0, 4, 3)
		light.light_color = Color.RED
		light.light_energy = 10
		light.omni_range = 20
		view.add_child(light)
		image = await capture(view)
		for i in range(points.size()):
			check(close_color(sample(image, camera, points[i]), colors[i]), "comic surfaces ignore dynamic light sources")
		light.free()
		# Perspective at eye height used to paint a moving dark band on the
		# floor once its angle to the camera crossed the silhouette threshold.
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 78
		var floor_point = Vector3(2, 0, 2)
		for distance in [2.0, 6.0, 9.0, 10.0, 11.0, 16.0]:
			camera.position = floor_point + Vector3(0, 1.62, distance)
			camera.look_at(floor_point)
			image = await capture(view)
			check(close_color(sample(image, camera, floor_point), colors[3]), "floor stays the same color at eye height, distance %.1f (web=%s)" % [distance, web])
			if distance == 16.0:
				image.save_png("res://builds/visual-checks/comic-grazing-floor-%s.png" % web)
		var wall_point = Vector3(0, 1, 1)
		for distance in [2.0, 5.0, 7.0, 10.0]:
			camera.position = wall_point + Vector3(distance, 0.4, 1)
			camera.look_at(wall_point)
			image = await capture(view)
			check(close_color(sample(image, camera, wall_point), colors[1]), "wall keeps its tone at grazing angles (web=%s)" % web)
		view.free()
	await check_block_light_render()
	await check_ground_shadow_render()
	if failures.is_empty():
		print("PASS: %d image-based comic rendering checks" % checks)
		quit(0)
	else:
		quit(1)

func check_block_light_render() -> void:
	var field = BlockLighting.new(Vector3(-4.4, -0.4, -4.4), Vector3i(12, 8, 12))
	# A sealed partition and roof isolate both sides of an indoor light test.
	field.add_box(AABB(Vector3(-4.4, 0, -0.4), Vector3(9.6, 6.4, 0.8)))
	field.add_box(AABB(Vector3(-4.4, 4.4, -4.4), Vector3(9.6, 0.8, 9.6)))
	field.bake([Vector3(0, 1.6, -1.6)])
	field.make_texture()
	CastleArt.use_block_light(field)
	var view = SubViewport.new()
	view.size = Vector2i(512, 512)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world = Node3D.new()
	view.add_child(world)
	CastleArt.box(world, Vector3(0, -0.05, 0), Vector3(8, 0.1, 8), CastleArt.mat("b0b0b0"))
	CastleArt.box(world, Vector3(0, 1.6, 0), Vector3(8, 3.2, 0.8), CastleArt.mat("808a90"))
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(0, 9, 0)
	camera.rotation.x = -PI / 2
	view.add_child(camera)
	camera.make_current()
	var near_point = Vector3(0, 0, -1.6)
	var far_point = Vector3(3.2, 0, -1.6)
	var blocked_point = Vector3(0, 0, 1.6)
	var image: Image = await capture(view)
	var warm = sample(image, camera, near_point)
	var far_color = sample(image, camera, far_point)
	var blocked = sample(image, camera, blocked_point)
	check(warm.r > warm.b * 1.2, "baked torchlight has a warm color")
	check(warm.get_luminance() > far_color.get_luminance() + 0.06, "baked torchlight fades with world distance")
	check(warm.get_luminance() > blocked.get_luminance() * 1.6, "solid wall keeps the opposite room dark")
	image.save_png("res://builds/visual-checks/block-light-wall.png")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	for distance in [2.0, 8.0, 16.0]:
		camera.position = near_point + Vector3(0, 1.62, -distance)
		camera.look_at(near_point)
		image = await capture(view)
		check(close_color(sample(image, camera, near_point), warm), "baked lighting stays fixed as the camera moves")
	CastleArt.use_block_light(null)
	view.free()

func check_ground_shadow_render() -> void:
	var view = SubViewport.new()
	view.size = Vector2i(512, 512)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.positional_shadow_atlas_size = 0
	root.add_child(view)
	var maze = CastleMaze.new()
	maze.generate(1, false)
	maze.cells.fill(15)
	view.add_child(maze)
	CastleArt.box(maze, Vector3(0, -0.05, 1), Vector3(8, 0.1, 8), CastleArt.mat("b0b0b0"))
	CastleArt.box(maze, Vector3(0, 0.7, 2.4), Vector3(8, 1.4, 0.8), CastleArt.mat("808a90"))
	var caster = Node3D.new()
	caster.position = Vector3(0, 0, 1.85)
	caster.set_meta("ground_shadow_radii", Vector2(1.35, 1.25))
	maze.add_child(caster)
	var shadows = GroundShadows.new()
	view.add_child(shadows)
	shadows.configure({"maze": maze, "enemies": [], "state": "title"})
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(0, 10, 1)
	camera.rotation.x = -PI / 2
	view.add_child(camera)
	camera.make_current()
	var points = [Vector3(0, 0, 1.85), Vector3(0.75, 0, 1.85), Vector3(1.34, 0, 1.85), Vector3(0, 0, 2.98), Vector3(0, 1.4, 2.4)]
	shadows.visible = false
	var baseline: Image = await capture(view)
	var baseline_draws = view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	shadows.visible = true
	var shaded: Image = await capture(view)
	check(view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) == baseline_draws + 1, "contact shadows add exactly one draw call")
	var center = sample(shaded, camera, points[0])
	var plain = sample(baseline, camera, points[0])
	check(center.get_luminance() < plain.get_luminance() * 0.85 and center.get_luminance() > plain.get_luminance() * 0.6, "contact shadow visibly grounds objects without blackening the floor")
	check(sample(shaded, camera, points[1]).get_luminance() > center.get_luminance() + 0.02, "contact shadow softens toward its edge")
	for i in [2, 3, 4]:
		check(close_color(sample(shaded, camera, points[i]), sample(baseline, camera, points[i])), "shadow edge, opposite room and raised wall remain unaffected (%d)" % i)
	shaded.save_png("res://builds/visual-checks/ground-shadow-wall.png")
	# Use the raised patch height when tracking its projected center at grazing
	# angles. The tiny depth offset is intentional and constant in world space.
	var shadow_center = points[0] + Vector3.UP * GroundShadows.FLOOR_Y
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	for distance in [2.0, 6.0, 12.0]:
		camera.position = shadow_center + Vector3(0, 1.62, -distance)
		camera.look_at(shadow_center)
		shaded = await capture(view)
		check(close_color(sample(shaded, camera, shadow_center), center), "contact shadow stays fixed as the camera approaches")
	view.free()
