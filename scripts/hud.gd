class_name MazeHUD
extends Control

const INK = Color("101d26")
const CREAM = Color("eee7d2")
const MUTED = Color("9baeb4")
const GOLD = Color("cfb77d")
const GREEN = Color("81e2b2")
var game
var serif: SystemFont
var sans: SystemFont
var buttons: Array[Button] = []
var scale_factor = Vector2.ONE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif", "serif"])
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Avenir Next", "Noto Sans", "DejaVu Sans", "sans-serif"])
	refresh_buttons()
	get_viewport().size_changed.connect(refresh_buttons)

func text_at(value: String, pos: Vector2, size: int = 18, color: Color = CREAM, elegant: bool = false) -> void:
	draw_string(serif if elegant else sans, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, pos: Vector2, size: int = 18, color: Color = CREAM, elegant: bool = false) -> void:
	var font = serif if elegant else sans
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(value, pos - Vector2(width / 2, 0), size, color, elegant)

func tracked(value: String, pos: Vector2, size: int = 13, color: Color = GOLD, spacing: float = 3.0) -> void:
	var x = pos.x
	for character in value:
		text_at(character, Vector2(x, pos.y), size, color)
		x += sans.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing

func diamond(pos: Vector2, radius: float, color: Color, filled: bool = true) -> void:
	var points = PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius, 0), pos + Vector2(0, radius), pos + Vector2(-radius, 0), pos + Vector2(0, -radius)])
	if filled:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, 1.2, true)

func panel(rect: Rect2, color: Color = Color(0.045, 0.085, 0.115, 0.88), border: Color = Color(0.65, 0.72, 0.72, 0.2)) -> void:
	draw_style_box(style(color, border), rect)

func style(color: Color, border: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box

func button(label: String, rect: Rect2, action: Callable, primary: bool = false, disabled: bool = false) -> void:
	var node = Button.new()
	node.text = label
	node.position = rect.position * scale_factor
	node.size = rect.size * scale_factor
	node.add_theme_font_override("font", sans)
	node.add_theme_font_size_override("font_size", int(17 * scale_factor.x))
	var bg = Color("cdb780") if primary else Color("192c37")
	var fg = INK if primary else CREAM
	node.add_theme_color_override("font_color", fg)
	node.add_theme_color_override("font_hover_color", INK if primary else GREEN)
	node.add_theme_color_override("font_pressed_color", fg)
	node.add_theme_color_override("font_disabled_color", Color("6f8189"))
	node.add_theme_stylebox_override("normal", style(bg, Color("b8a573") if primary else Color("40535c")))
	node.add_theme_stylebox_override("hover", style(Color("e5d5ab") if primary else Color("29424c"), GOLD))
	node.add_theme_stylebox_override("pressed", style(Color("b5a170") if primary else Color("29434a"), GREEN))
	node.add_theme_stylebox_override("disabled", style(Color("172630"), Color("2b3d46")))
	node.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), GREEN))
	node.disabled = disabled
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	add_child(node)
	buttons.append(node)

func refresh_buttons() -> void:
	if not is_inside_tree():
		return
	scale_factor = get_viewport_rect().size / Vector2(1440, 900)
	for node in buttons:
		remove_child(node)
		node.queue_free()
	buttons.clear()
	match game.state:
		"title":
			button("Enter the labyrinth     →", Rect2(80, 621, 342, 60), game.start, true)
		"paused":
			button("Resume your journey", Rect2(515, 405, 410, 58), func(): game.set_mode("playing"), true)
			button("Visit the armory", Rect2(515, 477, 410, 53), func(): game.set_mode("shop"))
			button("Retry level", Rect2(515, 543, 198, 50), func(): game.restart())
			button("New journey", Rect2(727, 543, 198, 50), func(): game.restart(true))
			button("Sound: " + ("off" if game.sound.muted else "on"), Rect2(515, 606, 410, 44), func(): game.sound.toggle_mute(); refresh_buttons())
		"shop":
			for tier in range(1, 5):
				var weapon = game.WEAPONS[tier]
				var owned = tier <= game.weapon_tier
				var next = tier == game.weapon_tier + 1
				var affordable = game.coins >= weapon.cost
				var label = "Equipped" if tier == game.weapon_tier else "Acquired" if owned else "Buy · %d gold" % weapon.cost if next else "Unlock previous weapon"
				if next and not affordable:
					label = "Need %d more gold" % (weapon.cost - game.coins)
				button(label, Rect2(147 + (tier - 1) * 292, 586, 266, 51), func(): game.buy(tier), next and affordable, owned or not next or not affordable)
			button("Return to the maze  [B]", Rect2(541, 714, 358, 52), func(): game.set_mode("playing"))
		"victory":
			button("Enter level %d  [Enter]" % (game.level + 1), Rect2(490, 611, 460, 57), game.next_level, true)
			button("New journey · reset progress", Rect2(490, 682, 460, 47), func(): game.restart(true))
		"dead":
			button("Retry level %d  [Enter]" % game.level, Rect2(490, 611, 460, 57), func(): game.restart(), true)
			button("New journey · reset progress", Rect2(490, 682, 460, 47), func(): game.restart(true))

func _draw() -> void:
	if game == null or serif == null:
		return
	scale_factor = get_viewport_rect().size / Vector2(1440, 900)
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	if game.state == "title":
		draw_title()
		return
	draw_hud()
	if game.damage_flash > 0 and game.state == "playing":
		draw_rect(Rect2(0, 0, 1440, 900), Color(0.7, 0.13, 0.12, game.damage_flash * 0.35))
	if game.show_map and game.state == "playing":
		draw_map()
	match game.state:
		"paused": draw_pause()
		"shop": draw_shop()
		"dead", "victory": draw_result()

func draw_title() -> void:
	if game.web_profile:
		draw_rect(Rect2(0, 0, 1440, 900), Color("101d26"))
	# Layered translucent bands keep the living castle visible behind the menu.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1056, 0), Vector2(1056, 900), Vector2(0, 900)]), PackedColorArray([Color(0.025, 0.06, 0.082, 0.98), Color(0.025, 0.06, 0.082, 0.12), Color(0.025, 0.06, 0.082, 0.12), Color(0.025, 0.06, 0.082, 0.98)]))
	draw_rect(Rect2(0, 0, 1440, 100), Color(0.03, 0.06, 0.08, 0.25))
	draw_line(Vector2(80, 92), Vector2(1360, 92), Color(0.8, 0.82, 0.72, 0.23), 1)
	diamond(Vector2(92, 54), 11, GOLD, false)
	diamond(Vector2(92, 54), 4, GREEN)
	tracked("THORNHOLD", Vector2(119, 59), 14, CREAM, 3.2)
	tracked("A MEDIEVAL SURVIVAL MAZE", Vector2(1012, 59), 11, CREAM, 2.0)
	tracked("THE EMERALD GATE", Vector2(83, 222), 14, GREEN, 4.5)
	text_at("Thornhold", Vector2(75, 338), 100, CREAM, true)
	draw_line(Vector2(83, 377), Vector2(145, 377), GOLD, 2)
	diamond(Vector2(159, 377), 4, GOLD)
	text_at("The kingdom fell. The maze remained.", Vector2(83, 431), 25, CREAM, true)
	text_at("Walk its forgotten halls. Gather gold. Keep the", Vector2(83, 475), 18, MUTED)
	text_at("darkness at bay — and find the green light home.", Vector2(83, 504), 18, MUTED)
	tracked("EXPLORE  /  ARM YOURSELF  /  ESCAPE", Vector2(83, 566), 11, GOLD, 2.1)
	text_at("or press Enter", Vector2(443, 659), 14, MUTED)
	var controls = [["W A S D", "Move"], ["MOUSE", "Look around"], ["LMB / RMB", "Strike / guard"], ["B", "Armory"]]
	for i in range(controls.size()):
		var x = 83 + i * 164
		text_at(controls[i][0], Vector2(x, 754), 12, GOLD)
		text_at(controls[i][1], Vector2(x, 780), 14, MUTED)
	draw_line(Vector2(80, 830), Vector2(1360, 830), Color(0.8, 0.82, 0.72, 0.2), 1)
	tracked("I  /  THE OUTER KEEP", Vector2(82, 861), 11, MUTED, 2.2)
	text_at("Keep your gear. Face a stronger hunt.", Vector2(1041, 861), 13, MUTED)
	# A quiet world-space caption balances the title on the left.
	panel(Rect2(1101, 691, 257, 90), Color(0.045, 0.085, 0.10, 0.7))
	diamond(Vector2(1130, 720), 5, GREEN)
	tracked("YOUR OBJECTIVE", Vector2(1145, 724), 10, MUTED, 1.7)
	text_at("Find the Emerald Gate", Vector2(1119, 754), 18, CREAM, true)

func draw_hud() -> void:
	# Objective and purse.
	panel(Rect2(32, 29, 307, 79))
	diamond(Vector2(59, 56), 5, GREEN)
	tracked("LEVEL %02d · EMERALD GATE" % game.level, Vector2(74, 60), 10, GREEN, 1.6)
	text_at("Find the way out", Vector2(51, 89), 23, CREAM, true)
	panel(Rect2(1212, 29, 196, 79))
	draw_circle(Vector2(1242, 57), 10, GOLD)
	draw_circle(Vector2(1242, 57), 6, INK)
	text_at(str(game.coins), Vector2(1261, 67), 27, CREAM)
	text_at("GOLD    /    [B] Armory", Vector2(1230, 91), 11, MUTED)
	draw_compass()
	# Crosshair is intentionally small and readable against both stone and sky.
	var cross = GREEN if game.hit_flash > 0 else Color(0.93, 0.94, 0.85, 0.85)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(Vector2(720, 450) + direction * 5, Vector2(720, 450) + direction * 10, cross, 1.4, true)
	draw_circle(Vector2(720, 450), 1.2, cross)
	if game.hit_flash > 0:
		for side in [-1, 1]:
			for up in [-1, 1]:
				draw_line(Vector2(720 + side * 13, 450 + up * 13), Vector2(720 + side * 19, 450 + up * 19), GREEN, 2, true)
	panel(Rect2(32, 764, 312, 103))
	tracked("VITALITY", Vector2(52, 789), 10, MUTED, 2.0)
	text_at("%d / 100" % ceili(game.player.health), Vector2(257, 789), 12, CREAM)
	draw_rect(Rect2(52, 801, 272, 9), Color("263840"))
	draw_rect(Rect2(52, 801, 272 * game.player.health / 100, 9), Color("c97971"))
	tracked("STAMINA", Vector2(52, 837), 9, MUTED, 1.9)
	draw_rect(Rect2(146, 829, 178, 5), Color("263840"))
	draw_rect(Rect2(146, 829, 178 * game.player.stamina / 100, 5), GOLD)
	var stats = game.WEAPONS[game.weapon_tier]
	panel(Rect2(1096, 764, 312, 103))
	tracked("%02d / ARMAMENT" % game.weapon_tier, Vector2(1116, 789), 10, GOLD, 2.0)
	text_at(stats.name, Vector2(1116, 819), 23, CREAM, true)
	text_at("%.1f m reach   ·   %d damage" % [stats.reach, stats.damage], Vector2(1116, 845), 12, MUTED)
	centered("SHIFT  Sprint     SPACE  Jump     M  Map     ESC  Pause", Vector2(720, 864), 12, Color(0.78, 0.84, 0.84, 0.8))
	if game.player.blocking:
		centered("GUARDING", Vector2(720, 513), 12, GOLD)
	if game.message_timer > 0:
		var width = sans.get_string_size(game.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 46
		panel(Rect2(720 - width / 2, 690, width, 44), Color(0.045, 0.085, 0.10, 0.91))
		centered(game.message, Vector2(720, 718), 15, CREAM)
	if game.target_timer > 0 and is_instance_valid(game.target_enemy) and not game.target_enemy.dead:
		var target = game.target_enemy
		centered(target.display_name(), Vector2(720, 580), 11, CREAM)
		draw_rect(Rect2(620, 593, 200, 5), Color("25353d"))
		draw_rect(Rect2(620, 593, 200 * target.health / target.max_health, 5), Color("d17d6b"))
	var nearby = 0
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.alert and enemy.position.distance_to(game.player.position) < 15:
			nearby += 1
	if nearby > 0:
		centered("◆  YOU ARE BEING HUNTED", Vector2(720, 152), 11, Color("f0ac89"))

func draw_compass() -> void:
	panel(Rect2(549, 28, 342, 57), Color(0.045, 0.085, 0.115, 0.63))
	var heading = fposmod(-game.player.rotation.y, TAU)
	for i in range(24):
		var angle = i * TAU / 24
		var diff = wrapf(angle - heading, -PI, PI)
		if absf(diff) < 1.1:
			var x = 720 + diff * 140
			draw_line(Vector2(x, 66), Vector2(x, 72 if i % 6 else 76), MUTED, 1)
			if i % 6 == 0:
				centered(["N", "E", "S", "W"][i / 6], Vector2(x, 56), 12, CREAM)
	var offset = game.maze.center(game.maze.exit_cell) - game.player.position
	var bearing = atan2(offset.x, -offset.z)
	var difference = wrapf(bearing - heading, -PI, PI)
	var gate_x = 720 + clampf(difference, -1.1, 1.1) * 140
	diamond(Vector2(gate_x, 40), 4, GREEN)
	draw_line(Vector2(720, 76), Vector2(720, 83), GOLD, 2)

func draw_map() -> void:
	panel(Rect2(941, 139, 467, 546), Color(0.04, 0.075, 0.1, 0.97))
	tracked("CARTOGRAPHER'S NOTES", Vector2(966, 173), 11, GOLD, 2.0)
	text_at("The paths you remember", Vector2(966, 205), 23, CREAM, true)
	var origin = Vector2(972, 231)
	var unit = 30.5
	for y in range(CastleMaze.SIZE):
		for x in range(CastleMaze.SIZE):
			var cell = Vector2i(x, y)
			var p = origin + Vector2(cell) * unit
			if not game.discovered.has(cell):
				draw_rect(Rect2(p + Vector2.ONE, Vector2.ONE * (unit - 2)), Color("15262f"))
				continue
			draw_rect(Rect2(p, Vector2.ONE * unit), Color("33474c"))
			var walls = game.maze.cells[game.maze.index(cell)]
			if walls & 1: draw_line(p, p + Vector2(unit, 0), MUTED, 1.5)
			if walls & 2: draw_line(p + Vector2(unit, 0), p + Vector2(unit, unit), MUTED, 1.5)
			if walls & 4: draw_line(p + Vector2(0, unit), p + Vector2(unit, unit), MUTED, 1.5)
			if walls & 8: draw_line(p, p + Vector2(0, unit), MUTED, 1.5)
	# The portal's beacon is a compass landmark; its surrounding paths stay hidden.
	diamond(origin + (Vector2(game.maze.exit_cell) + Vector2.ONE * 0.5) * unit, 5, GREEN)
	var player_cell = Vector2(game.player.position.x, game.player.position.z) / CastleMaze.CELL
	var player_point = origin + (player_cell + Vector2.ONE * 0.5) * unit
	draw_circle(player_point, 5, GOLD)
	var forward = -game.player.global_basis.z
	draw_line(player_point, player_point + Vector2(forward.x, forward.z) * 13, CREAM, 2, true)
	text_at("● You       ◆ Emerald Gate       [M] Close", Vector2(966, 660), 12, MUTED)

func overlay() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.015, 0.035, 0.05, 0.82))

func draw_pause() -> void:
	overlay()
	panel(Rect2(460, 208, 520, 488), Color("0e1d27"), Color("475953"))
	diamond(Vector2(720, 251), 9, GOLD, false)
	centered("A moment of respite", Vector2(720, 314), 36, CREAM, true)
	centered("Level %d · Your gear and gold stay with you on retry." % game.level, Vector2(720, 351), 14, MUTED)
	centered("New journey starts at level 1 and resets gold and gear.", Vector2(720, 676), 12, MUTED)
	centered("WASD · move     Mouse · look     LMB · strike     RMB · guard", Vector2(720, 748), 14, MUTED)
	centered("Shift · sprint     Space · jump     B · armory     M · map     F11 · fullscreen", Vector2(720, 779), 13, MUTED)

func draw_shop() -> void:
	overlay()
	panel(Rect2(116, 138, 1208, 655), Color("101f29"), Color("506258"))
	tracked("THE TRAVELER'S ARMORY", Vector2(150, 182), 11, GOLD, 3.3)
	text_at("Give yourself a fighting chance.", Vector2(148, 240), 39, CREAM, true)
	text_at("Purchase in order. Each upgrade builds on your reach and damage. Your new weapon equips immediately.", Vector2(150, 276), 15, MUTED)
	draw_circle(Vector2(1196, 194), 10, GOLD)
	text_at(str(game.coins), Vector2(1216, 204), 27, CREAM)
	for tier in range(1, 5):
		var x = 137 + (tier - 1) * 292
		var weapon = game.WEAPONS[tier]
		var active = tier == game.weapon_tier + 1
		var owned = tier <= game.weapon_tier
		panel(Rect2(x, 314, 286, 340), Color("1b3037") if active else Color("14262f"), GOLD if active else Color("31444b"))
		tracked("%02d" % tier, Vector2(x + 18, 343), 11, GOLD if active else MUTED, 1)
		text_at("ACQUIRED" if owned else "NEXT UPGRADE" if active else "LOCKED", Vector2(x + 112, 343), 10, GREEN if owned else GOLD if active else MUTED)
		draw_weapon_icon(Vector2(x + 143, 410), tier)
		centered(weapon.name, Vector2(x + 143, 489), 23, CREAM, true)
		centered("%.1f m reach    /    %d damage" % [weapon.reach, weapon.damage], Vector2(x + 143, 520), 13, GREEN if active else MUTED)
		var reach_gain = weapon.reach - game.WEAPONS[tier - 1].reach
		centered("+%.2f m reach from previous" % reach_gain, Vector2(x + 143, 551), 12, GOLD)
	centered("Your journey is paused while you browse.  ·  Keys 1–4 purchase an upgrade.", Vector2(720, 690), 12, MUTED)

func draw_weapon_icon(p: Vector2, tier: int) -> void:
	var wood = Color("a77d50")
	var steel = Color("c7dcda")
	var a = p + Vector2(-24, 40)
	var b = p + Vector2(25, -40)
	if tier == 1:
		draw_line(a, b, wood, 7, true)
		draw_line(p + Vector2(10, -12), p + Vector2(23, -18), wood, 4, true)
	elif tier == 2:
		draw_line(a, p + Vector2(-12, 20), wood, 7, true)
		draw_line(p + Vector2(-12, 20), b, steel, 8, true)
		draw_line(p + Vector2(-27, 13), p + Vector2(2, 30), GOLD, 5, true)
		diamond(b + Vector2(2, -3), 5, steel)
	else:
		draw_line(a + Vector2(-5, 9), b, wood, 5, true)
		var points = PackedVector2Array([b + Vector2(9, -17), b + Vector2(-10, 0), b + Vector2(1, 8)])
		draw_colored_polygon(points, steel)
		draw_line(b + Vector2(-8, 8), b + Vector2(2, 14), GOLD, 5, true)
		if tier == 4:
			draw_colored_polygon(PackedVector2Array([b + Vector2(-5, 0), b + Vector2(-30, -12), b + Vector2(-38, 8), b + Vector2(-23, 25), b + Vector2(-9, 16)]), steel)

func draw_result() -> void:
	overlay()
	var won = game.state == "victory"
	panel(Rect2(380, 126, 680, 646), Color("0e1e28"), Color("526459"))
	diamond(Vector2(720, 179), 20, GREEN if won else Color("c27c6e"), false)
	diamond(Vector2(720, 179), 8, GREEN if won else Color("c27c6e"))
	centered("LEVEL %02d COMPLETE" % game.level if won else "LEVEL %02d · FALLEN IN THE KEEP" % game.level, Vector2(720, 237), 12, GREEN if won else GOLD)
	centered("The hunt grows stronger." if won else "Your watch has ended.", Vector2(720, 297), 38, CREAM, true)
	centered("Level %d awaits. Stronger enemies. Sharper instincts." % (game.level + 1) if won else "Rise again. Your equipment and gold are safe.", Vector2(720, 339), 16, MUTED)
	draw_line(Vector2(460, 375), Vector2(980, 375), Color("3e5358"), 1)
	var stats = [[game.time_text(game.elapsed), "LEVEL TIME"], [str(game.kills), "MONSTERS SLAIN"], [str(game.coins_found), "COINS FOUND"]]
	for i in range(3):
		var x = 554 + i * 166
		centered(stats[i][0], Vector2(x, 431), 33, GOLD, true)
		centered(stats[i][1], Vector2(x, 461), 10, MUTED)
	centered("%s · %d gold kept" % [game.WEAPONS[game.weapon_tier].name, game.coins], Vector2(720, 509), 18, GREEN)
	centered("Your health and stamina will be restored.", Vector2(720, 541), 14, MUTED)
	centered(game.enemy_tactics_description(game.level + 1 if won else game.level), Vector2(720, 575), 14, GOLD)
