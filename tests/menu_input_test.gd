extends SceneTree
## Simulates asynchronous browser grants/rejections through the real menus.
## Browser permission handling still needs a check on the playing device.
var checks = 0
var failures: Array[String] = []

class BrowserGame extends ThornholdGame:
	var locked = false
	var capture_requests = 0
	func capture_pointer() -> void:
		capture_requests += 1
	func release_pointer() -> void:
		locked = false
	func is_pointer_captured() -> bool:
		return locked

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("Menu test timed out"); quit(1))
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func key(code: Key) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func frames(count: int = 3) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func click(button: Button) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = button.get_global_rect().get_center()
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	var game = BrowserGame.new()
	game.browser_pointer = true
	game.web_profile = true
	root.add_child(game)
	game.save_records = false
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await frames()
	click(game.hud.buttons[0])
	check(game.capture_requests == 1 and game.capture_pending, "title click requests capture inside GUI input")
	check(game.state == "title", "gameplay waits for the asynchronous grant")
	game.locked = true
	await frames()
	check(game.state == "playing" and not game.capture_pending, "grant starts gameplay")
	# Escape may release pointer lock before its key event reaches the game.
	game.locked = false
	await frames()
	check(game.state == "paused", "browser-only pointer loss pauses gameplay")
	var requests = game.capture_requests
	game._unhandled_input(key(KEY_ESCAPE))
	check(game.state == "paused" and game.capture_requests == requests, "late Escape does not immediately recapture and resume")
	# A rejected request leaves a working Resume button and freezes simulation.
	Input.action_press("attack")
	Input.action_press("block")
	click(game.hud.buttons[0])
	check(game.capture_requests == requests + 1 and game.state == "paused", "Resume requests capture but does not assume success")
	var paused_position = game.player.position
	var paused_time = game.elapsed
	Input.action_press("forward")
	await frames(8)
	check(game.player.position == paused_position and game.elapsed == paused_time, "rejected capture keeps movement and timer paused")
	check(game.hud.buttons.size() > 0, "Resume remains available after a rejected capture")
	click(game.hud.buttons[0])
	game.locked = true
	await frames()
	check(game.state == "playing" and game.hud.buttons.is_empty(), "retrying Resume closes the menu after capture succeeds")
	check(root.gui_get_focus_owner() == null, "menu no longer owns keyboard focus")
	check(not Input.is_action_pressed("forward") and not Input.is_action_pressed("attack") and not Input.is_action_pressed("block"), "stale movement and menu clicks are cleared")
	check(game.player.attack_cooldown == 0 and not game.player.blocking, "Resume does not swing or raise the shield")
	Input.action_press("forward")
	await frames(12)
	Input.action_release("forward")
	check(game.player.position.distance_to(paused_position) > 0.2, "WASD works after returning from the menu")
	# Armory return has the same capture handshake and keeps inventory.
	game.coins = 6
	game._unhandled_input(key(KEY_B))
	check(game.state == "shop" and not game.locked, "B opens the armory with a usable pointer")
	click(game.hud.buttons[0])
	check(game.weapon_tier == 1 and game.coins == 0 and game.state == "shop", "mouse purchase works without resuming")
	click(game.hud.buttons.back())
	check(game.state == "shop" and game.capture_pending, "armory Return waits for capture")
	game.locked = true
	await frames()
	check(game.state == "playing" and game.weapon_tier == 1, "armory Return restores control and preserves gear")
	# Canceling or leaving the tab must invalidate an in-flight request.
	game.set_mode("paused")
	click(game.hud.buttons[0])
	game.set_mode("shop")
	game.locked = true
	await frames()
	check(game.state == "shop" and not game.locked and not game.capture_pending, "late grant cannot capture the pointer in another menu")
	game.set_mode("playing")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == "shop" and not game.capture_pending, "tab focus loss cancels a pending return")
	game.locked = true
	await frames()
	check(game.state == "shop" and not game.locked, "late grant after tab change is released")
	game.set_mode("playing")
	game.locked = true
	await frames()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == "paused" and not game.locked, "leaving the tab during gameplay pauses and releases input")
	# Restart must replace old result buttons even when capture is rejected.
	game.restart()
	check(game.state == "paused" and game.capture_pending and game.hud.buttons[0].text.begins_with("Resume"), "retry has a working Resume fallback while awaiting capture")
	game.free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d browser menu/input regression checks" % checks)
		quit(0)
	else:
		quit(1)
