extends SceneTree

func _initialize() -> void:
	var train: Node = load("res://scenes/train/train.scn").instantiate()
	root.add_child(train)
	await process_frame
	await process_frame
	var world: SubViewport = train.get_node("Screen/Frame/World")
	var consist: Node = world.get_node("Consist")
	var player: Node3D = world.get_node("Player")
	var camera: Camera3D = player.get_node("Camera3D")

	var dining: int = GameContent.carriage_locations().find(&"dining")
	var centre: Vector3 = consist.global_position + Vector3(consist._offset(dining), 0.0, 0.0)
	# stand in the aisle a couple of bays back, looking down the row of tables
	player.global_position = centre + Vector3(-3.0, Consist.FLOOR_Y + 1.6, 0.0)
	camera.global_position = player.global_position
	camera.look_at(centre + Vector3(5.4, Consist.FLOOR_Y + 0.75, 1.10), Vector3.UP)

	for i in range(40):
		await process_frame
	var shot := world.get_texture().get_image()
	shot.save_png(OS.get_environment("SHOT"))
	print("WROTE ", OS.get_environment("SHOT"))
	quit()
