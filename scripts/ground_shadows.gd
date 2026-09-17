class_name GroundShadows
extends MultiMeshInstance3D
## Small contact ellipses: one batch, two triangles per caster, no shadow maps.

const SHADER = preload("res://assets/shaders/ground_shadow.gdshader")
const FLOOR_Y = 0.025 # Above the tiles and gold inlay; below every raised prop.
const OPACITY = 0.30
const ENEMY_RADII = [Vector2(0.6, 0.6), Vector2(0.5, 1.0), Vector2(0.8, 0.8)]
var game
var casters: Array[Dictionary] = []

func configure(owner_game) -> void:
	game = owner_game
	name = "GroundShadows"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Update after the moving models. Paused menus need no buffer updates.
	process_priority = 10
	for enemy: MazeEnemy in game.enemies:
		casters.append({"node": enemy, "radii": ENEMY_RADII[enemy.kind]})
	for node in game.maze.get_children():
		if node.has_meta("ground_shadow_radii"):
			casters.append({"node": node, "radii": node.get_meta("ground_shadow_radii")})
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = plane
	multimesh.instance_count = casters.size()
	# Fifteen tiny quads fit in one draw. Explicit bounds avoid recomputing the
	# batch AABB as enemies move; masonry keeps its separate spatial chunks.
	var span = CastleMaze.SIZE * CastleMaze.CELL
	multimesh.custom_aabb = AABB(Vector3(-4, 0, -4), Vector3(span + 8, 0.1, span + 8))
	var material = ShaderMaterial.new()
	material.shader = SHADER
	material_override = material
	refresh()

func _process(_delta: float) -> void:
	if game.state == "playing":
		refresh()

func refresh() -> void:
	for i in range(casters.size()):
		var caster = casters[i]
		var node = caster.node
		var strength = 0.0
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_visible_in_tree():
			var pos: Vector3 = node.global_position
			var yaw = 0.0
			strength = OPACITY
			if node is MazeEnemy:
				yaw = node.model.rotation.y
				# Keep the patch on the floor during death animations, fading with
				# the body as it disappears. Never shrink it up into the model.
				strength *= node.model.scale.x / (1.0 + maxf(0.0, pos.y - 0.05))
			pos.y = FLOOR_Y
			var radii: Vector2 = caster.radii
			var transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(radii.x * 2, 1, radii.y * 2)), pos)
			if not caster.has("transform") or caster.transform != transform:
				multimesh.set_instance_transform(i, transform)
				multimesh.set_instance_custom_data(i, floor_bounds(pos))
				caster.transform = transform
		if not caster.has("strength") or not is_equal_approx(caster.strength, strength):
			multimesh.set_instance_color(i, Color(1, 1, 1, strength))
			caster.strength = strength

func floor_bounds(pos: Vector3) -> Color:
	var maze: CastleMaze = game.maze
	var cell = maze.cell_at(pos)
	var center = maze.center(cell)
	var walls = maze.cells[maze.index(cell)]
	# Clip at the inside of closed walls. Normal depth testing also hides the
	# patch behind masonry and underneath statues; it cannot shade wall faces.
	var half_floor = CastleMaze.CELL * 0.5 - 0.40
	return Color(
		center.x - half_floor if walls & 8 else -100.0,
		center.z - half_floor if walls & 1 else -100.0,
		center.x + half_floor if walls & 2 else 100.0,
		center.z + half_floor if walls & 4 else 100.0)
