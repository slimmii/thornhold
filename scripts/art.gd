class_name CastleArt
extends RefCounted

const COMIC_SHADER = preload("res://assets/shaders/comic.gdshader")
static var materials: Dictionary = {}
static var block_light: BlockLighting

static func use_block_light(light: BlockLighting) -> void:
	block_light = light
	for material: ShaderMaterial in materials.values():
		if light != null:
			light.apply(material)
		else:
			material.set_shader_parameter("block_lighting", false)
			material.set_shader_parameter("light_volume", null)

static func web_masonry_material() -> ShaderMaterial:
	if not materials.has("web_masonry"):
		var material = ShaderMaterial.new()
		material.shader = COMIC_SHADER
		material.set_shader_parameter("use_instance_color", true)
		if block_light != null:
			block_light.apply(material)
		materials["web_masonry"] = material
	return materials["web_masonry"]

static func stone(hex: String) -> ShaderMaterial:
	return mat(hex)

static func mat(hex: String, full_bright: bool = false) -> ShaderMaterial:
	var key = hex + ("_bright" if full_bright else "")
	if not materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = COMIC_SHADER
		material.set_shader_parameter("base_color", Color(hex))
		material.set_shader_parameter("full_bright", full_bright)
		if block_light != null:
			block_light.apply(material)
		materials[key] = material
	return materials[key]

static func style_imported_model(model: Node3D) -> void:
	# The bundled GLBs use solid-color surfaces. Keep their palette and skinning,
	# replacing metallic/emissive materials without modifying imported assets.
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(node.mesh.get_surface_count()):
			var source = node.get_active_material(surface)
			if source is BaseMaterial3D:
				node.set_surface_override_material(surface, mat(source.albedo_color.to_html()))

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, material)

static func cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, material: Material, sides: int = 10) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = sides
	return mesh(parent, shape, pos, material)

static func sphere(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	return mesh(parent, shape, pos, material)

static func solid_box(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

static func torch(parent: Node3D, pos: Vector3) -> Node3D:
	var node = Node3D.new()
	node.position = pos
	parent.add_child(node)
	cylinder(node, Vector3(0, 0.6, 0), 0.11, 0.075, 1.2, mat("393339"))
	cylinder(node, Vector3(0, 1.25, 0), 0.12, 0.24, 0.27, mat("645646"))
	var flame = sphere(node, Vector3(0, 1.57, 0), 0.20, mat("ff8f27", true))
	flame.scale = Vector3(0.7, 1.9, 0.7)
	var inner = sphere(node, Vector3(0, 1.56, 0), 0.13, mat("ffd47b", true))
	inner.scale.y = 1.8
	return node

static func banner(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> void:
	var node = Node3D.new()
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)
	box(node, Vector3(0, 0.8, 0), Vector3(0.88, 1.8, 0.045), mat("234f56"))
	box(node, Vector3(0, 1.76, 0), Vector3(1.1, 0.075, 0.12), mat("c8ac70"))
	box(node, Vector3(-0.37, 0.8, -0.03), Vector3(0.035, 1.72, 0.015), mat("bca374"))
	box(node, Vector3(0.37, 0.8, -0.03), Vector3(0.035, 1.72, 0.015), mat("bca374"))
	var emblem = box(node, Vector3(0, 0.9, -0.04), Vector3(0.26, 0.26, 0.03), mat("d0b879"))
	emblem.rotation.z = PI / 4
	box(node, Vector3(0, 0.8, -0.065), Vector3(0.045, 0.72, 0.035), mat("e2d3a2"))

static func knight(parent: Node3D, pos: Vector3, statue: bool = false) -> Node3D:
	var node = Node3D.new()
	node.position = pos
	parent.add_child(node)
	var armor = mat("737f83" if statue else "454e5d")
	var edge = mat("aa9c77" if statue else "978568")
	var dark = mat("28313b")
	for side in [-1.0, 1.0]:
		box(node, Vector3(side * 0.21, 0.48, 0), Vector3(0.26, 0.79, 0.3), armor)
		box(node, Vector3(side * 0.21, 0.13, -0.12), Vector3(0.3, 0.24, 0.52), dark)
		var shoulder = sphere(node, Vector3(side * 0.51, 1.57, 0), 0.30, armor)
		shoulder.scale.y = 0.72
		box(node, Vector3(side * 0.54, 1.2, 0), Vector3(0.23, 0.52, 0.26), armor)
	cylinder(node, Vector3(0, 1.31, 0), 0.34, 0.46, 0.76, armor, 6)
	box(node, Vector3(0, 0.98, 0), Vector3(0.76, 0.12, 0.42), edge)
	box(node, Vector3(0, 1.31, -0.395), Vector3(0.28, 0.56, 0.035), mat("315f63" if statue else "672f40"))
	cylinder(node, Vector3(0, 1.98, 0), 0.28, 0.25, 0.48, armor, 8)
	box(node, Vector3(0, 2.00, -0.252), Vector3(0.37, 0.052, 0.055), dark)
	box(node, Vector3(0, 1.93, -0.282), Vector3(0.052, 0.28, 0.05), edge)
	if not statue:
		for side in [-1.0, 1.0]:
			box(node, Vector3(side * 0.1, 2.01, -0.286), Vector3(0.1, 0.025, 0.03), mat("ff5e4f"))
	# Blade and a thick kite shield make the silhouette unmistakably medieval.
	box(node, Vector3(-0.59, 1.05, -0.44), Vector3(0.11, 1.42, 0.07), edge)
	box(node, Vector3(-0.59, 0.69, -0.44), Vector3(0.4, 0.07, 0.1), dark)
	var shield = cylinder(node, Vector3(0.57, 1.18, -0.31), 0.44, 0.44, 0.12, edge, 6)
	shield.rotation.x = PI / 2
	var shield_face = cylinder(node, Vector3(0.57, 1.18, -0.39), 0.37, 0.37, 0.05, mat("23494f" if statue else "512b38"), 6)
	shield_face.rotation.x = PI / 2
	box(node, Vector3(0.57, 1.18, -0.43), Vector3(0.07, 0.48, 0.025), edge)
	return node

static func monster(parent: Node3D, kind: int) -> Node3D:
	if kind == 0:
		return knight(parent, Vector3.ZERO)
	var node = Node3D.new()
	parent.add_child(node)
	var skin = mat("674a48" if kind == 2 else "333a4b")
	var armor = mat("3a3039")
	var bone = mat("cbbb8c")
	var eyes = mat("ff7850")
	if kind == 1:
		var torso = sphere(node, Vector3(0, 0.8, 0), 0.52, skin)
		torso.scale = Vector3(0.7, 0.9, 1.6)
		for side in [-1, 1]:
			for end in [-1, 1]:
				box(node, Vector3(side * 0.31, 0.4, end * 0.45), Vector3(0.15, 0.7, 0.19), armor)
		box(node, Vector3(0, 1.04, -0.78), Vector3(0.5, 0.49, 0.56), skin)
		box(node, Vector3(0, 0.92, -1.09), Vector3(0.35, 0.24, 0.38), armor)
		for side in [-1, 1]:
			cylinder(node, Vector3(side * 0.2, 1.45, -0.7), 0.15, 0, 0.4, skin, 4)
			sphere(node, Vector3(side * 0.22, 1.11, -1.04), 0.065, eyes)
			cylinder(node, Vector3(side * 0.13, 0.75, -1.16), 0, 0.055, 0.23, bone, 5)
		for i in range(5):
			cylinder(node, Vector3(0, 1.32, -0.38 + i * 0.22), 0.10, 0, 0.30, bone, 5)
	else:
		for side in [-1, 1]:
			box(node, Vector3(side * 0.33, 0.55, 0), Vector3(0.43, 1.1, 0.45), skin)
			box(node, Vector3(side * 0.33, 0.12, -0.14), Vector3(0.49, 0.25, 0.65), armor)
			var arm = sphere(node, Vector3(side * 0.78, 1.65, 0), 0.36, skin)
			arm.scale.y = 1.65
			sphere(node, Vector3(side * 0.68, 2.05, 0), 0.43, armor)
			var horn = cylinder(node, Vector3(side * 0.49, 2.91, 0), 0.17, 0, 0.88, bone, 6)
			horn.rotation.z = side * -0.6
			sphere(node, Vector3(side * 0.16, 2.54, -0.40), 0.067, eyes)
		var chest = sphere(node, Vector3(0, 1.66, 0), 0.67, skin)
		chest.scale = Vector3(1, 1.16, 0.69)
		box(node, Vector3(0, 1.07, 0), Vector3(1.02, 0.29, 0.66), armor)
		box(node, Vector3(0, 2.48, -0.04), Vector3(0.69, 0.66, 0.68), skin)
		box(node, Vector3(0, 2.28, -0.42), Vector3(0.46, 0.26, 0.32), armor)
		cylinder(node, Vector3(-0.9, 1.26, -0.34), 0.065, 0.065, 2.1, mat("77604b"))
		var blade = cylinder(node, Vector3(-0.9, 2.05, -0.34), 0.43, 0.43, 0.12, mat("879398"), 6)
		blade.rotation.z = PI / 2
	return node

static func disable_equipment_shadows(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.layers = 2

static func weapon(parent: Node3D, tier: int) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var wood = mat("765035")
	var steel = mat("a1b7bc")
	var gold = mat("c9a76b")
	# The armored hand is visible even before the first purchase.
	box(parent, Vector3(0, -0.07, 0.06), Vector3(0.18, 0.23, 0.23), mat("596978"))
	box(parent, Vector3(0, -0.23, 0.13), Vector3(0.22, 0.16, 0.26), gold)
	if tier == 1:
		var stick = cylinder(parent, Vector3(0, 0.37, 0), 0.068, 0.044, 1.18, wood, 7)
		stick.rotation.z = -0.04
		box(parent, Vector3(0, 0.76, 0), Vector3(0.1, 0.12, 0.1), mat("946743"))
	elif tier == 2:
		cylinder(parent, Vector3(0, 0.03, 0), 0.052, 0.052, 0.34, wood)
		box(parent, Vector3(0, 0.21, 0), Vector3(0.43, 0.07, 0.09), gold)
		box(parent, Vector3(0, 0.73, 0), Vector3(0.12, 1.0, 0.045), steel)
		cylinder(parent, Vector3(0, 1.3, 0), 0.08, 0, 0.18, steel, 4)
	elif tier >= 3:
		cylinder(parent, Vector3(0, 0.35, 0), 0.046, 0.035, 2.05, wood)
		cylinder(parent, Vector3(0, 1.52, 0), 0.105, 0, 0.43, steel, 4)
		for y in [0.23, 1.14]:
			cylinder(parent, Vector3(0, y, 0), 0.06, 0.06, 0.12, gold)
		if tier == 4:
			var blade = cylinder(parent, Vector3(0.08, 1.22, 0), 0.30, 0.30, 0.06, steel, 6)
			blade.rotation.x = PI / 2
			box(parent, Vector3(0.05, 1.22, 0), Vector3(0.09, 0.6, 0.08), gold)
	disable_equipment_shadows(parent)
