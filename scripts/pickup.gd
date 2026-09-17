class_name MazePickup
extends Node3D

var game
var healing = false
var collected = false
var model: Node3D
var phase: float = 0

func _ready() -> void:
	phase = position.x + position.z
	model = Node3D.new()
	model.position.y = 0.75
	add_child(model)
	if healing:
		CastleArt.cylinder(model, Vector3.ZERO, 0.16, 0.12, 0.30, CastleArt.mat("ae3f57"), 8)
		CastleArt.cylinder(model, Vector3(0, 0.21, 0), 0.065, 0.065, 0.13, CastleArt.mat("d2b27c"), 8)
		CastleArt.box(model, Vector3(0, 0, -0.15), Vector3(0.06, 0.2, 0.02), CastleArt.mat("ffe3b0"))
		CastleArt.box(model, Vector3(0, 0, -0.15), Vector3(0.16, 0.05, 0.02), CastleArt.mat("ffe3b0"))
	else:
		var coin = CastleArt.cylinder(model, Vector3.ZERO, 0.21, 0.21, 0.055, CastleArt.mat("f1be57"), 12)
		coin.rotation.x = PI / 2
		var inlay = CastleArt.cylinder(model, Vector3(0, 0, -0.033), 0.155, 0.155, 0.015, CastleArt.mat("a97530"), 12)
		inlay.rotation.x = PI / 2
		var glyph = CastleArt.box(model, Vector3(0, 0, -0.05), Vector3(0.10, 0.10, 0.018), CastleArt.mat("ffdd8a"))
		glyph.rotation.z = PI / 4

func _process(delta: float) -> void:
	if collected or game.state != "playing":
		return
	var offset = game.player.global_position - global_position
	if game.web_profile:
		model.visible = offset.length_squared() < 784.0
		if not model.visible:
			return
	phase += delta * 2.4
	model.position.y = 0.75 + sin(phase) * 0.12
	model.rotation.y += delta * 1.4
	if Vector2(offset.x, offset.z).length() < 0.95 and absf(offset.y) < 1.8:
		if healing and game.player.health >= 100:
			return
		collected = true
		if healing:
			game.player.health = minf(100, game.player.health + 35)
			game.toast("Crimson tonic  ·  +35 health", 2)
			game.sound.play("heal", 0.6)
		else:
			game.add_coins(3)
			game.coins_found += 1
			game.sound.play("coin", 0.5)
		queue_free()
