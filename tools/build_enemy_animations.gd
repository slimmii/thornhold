extends SceneTree
## Run with Godot --headless --path . --script res://tools/build_enemy_animations.gd
const Factory = preload("res://scripts/enemy_animation_factory.gd")

func _initialize() -> void:
	var directory = "res://assets/enemies/animations"
	DirAccess.make_dir_recursive_absolute(directory)
	for kind in range(3):
		var slug: String = Factory.SLUGS[kind]
		var document = GLTFDocument.new()
		var state = GLTFState.new()
		var error = document.append_from_file(ProjectSettings.globalize_path("res://assets/enemies/%s-model/%s.glb" % [slug, slug]), state)
		if error != OK:
			push_error("Cannot load enemy rig: " + slug)
			quit(1)
			return
		var model = document.generate_scene(state)
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var library = Factory.build(kind, skeleton, NodePath("Model/" + str(model.get_path_to(skeleton))))
		error = ResourceSaver.save(library, directory + "/" + slug + ".res")
		model.free()
		if error != OK:
			push_error("Cannot save enemy animation library: " + slug)
			quit(1)
			return
		print("BAKED ", slug, " animations: ", library.get_animation_list())
	quit()
