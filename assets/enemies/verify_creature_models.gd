extends SceneTree
## Import the generated GLBs directly without changing gameplay or saved progress.

func _initialize() -> void:
	for slug in ["ash-hound", "horned-sentinel"]:
		var folder = "res://assets/enemies/" + slug + "-model/"
		var info = JSON.parse_string(FileAccess.get_file_as_string(folder + "model-info.json"))
		var document = GLTFDocument.new()
		var state = GLTFState.new()
		var error = document.append_from_file(ProjectSettings.globalize_path(folder + slug + ".glb"), state)
		if error != OK:
			push_error(slug + " failed to load: " + str(error))
			quit(1)
			return
		var scene = document.generate_scene(state)
		var meshes = scene.find_children("*", "MeshInstance3D", true, false)
		var rigs = scene.find_children("*", "Skeleton3D", true, false)
		if meshes.size() != 1 or rigs.size() != 1 or rigs[0].get_bone_count() != int(info.bones):
			push_error(slug + " has unexpected mesh or skeleton structure")
			quit(1)
			return
		if meshes[0].skin == null or meshes[0].mesh.get_surface_count() != int(info.materials):
			push_error(slug + " is missing skin or materials")
			quit(1)
			return
		var result = {"godot_version": Engine.get_version_info().string, "glb_imported": true,
			"meshes": meshes.size(), "bones": rigs[0].get_bone_count(),
			"material_surfaces": meshes[0].mesh.get_surface_count(), "skin_present": true}
		var file = FileAccess.open(folder + "godot-verification.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  ") + "\n")
		file.close()
		print("MODEL_GODOT_VERIFIED ", slug, " ", JSON.stringify(result))
		scene.free()
	quit(0)
