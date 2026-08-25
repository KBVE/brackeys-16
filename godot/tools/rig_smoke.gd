extends SceneTree

func _initialize() -> void:
	var appearance := Wardrobe.appearance_of(&"beaumont")
	var rig := CharacterRig.from_appearance(appearance)
	root.add_child(rig)
	print("body_model=", rig.body_model, " pieces=", rig.outfit_pieces.size())
	print("skeleton=", rig.skeleton, " bones=", rig.skeleton.get_bone_count() if rig.skeleton else -1)
	if rig.skeleton:
		for child: Node in rig.skeleton.get_children():
			print("  child ", child.name, " ", child.get_class())
	quit()
