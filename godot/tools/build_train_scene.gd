extends SceneTree

## &gen -> builds res://scenes/train/train.scn around the real carriage.
##         run: godot --headless --path godot -s res://tools/build_train_scene.gd
## &bin -> .scn, not .tscn. The text form parses in 212ms against 15ms binary,
##         and that parse runs on the main thread inside wasm

const OUT := "res://scenes/train/train.scn"

## &instance -> never set owner inside an instanced scene. doing so packs the
##              instance's own children into THIS scene, and because the node
##              keeps scene_file_path, loading then produces both copies.
func _own(n: Node, root: Node) -> void:
	if n != root:
		n.owner = root
	if n != root and n.scene_file_path != "":
		return
	for c: Node in n.get_children():
		_own(c, root)

## Detail-shader materials, built ONCE and shared by every carriage in the consist.
## Keyed by source material so N cars cost N transforms, not N material sets.
var _shared: Dictionary = {}

func _material_for(src: StandardMaterial3D) -> ShaderMaterial:
	var key := src.resource_name
	if _shared.has(key):
		return _shared[key]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/carriage_2sided.gdshader") \
		if src.cull_mode == BaseMaterial3D.CULL_DISABLED \
		else load("res://shaders/carriage.gdshader")
	sm.set_shader_parameter("tex_albedo", src.albedo_texture)
	sm.set_shader_parameter("tex_normal", src.normal_texture)
	sm.set_shader_parameter("tex_mr", src.roughness_texture)
	sm.set_shader_parameter("tex_detail", load("res://assets/train/detail_normal.png"))
	_shared[key] = sm
	return sm

func _apply_detail_shader(node: Node) -> int:
	var count := 0
	for mi: Node in _mesh_instances(node):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for i in range(m.get_surface_count()):
			var src := m.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			# &glass -> the window panes stay a normal transparent material
			if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			(mi as MeshInstance3D).set_surface_override_material(i, _material_for(src))
			count += 1
	# &glow -> one shared emissive material so night lighting is a single write
	var em := node.get_node_or_null("emissive") as MeshInstance3D
	if em != null and em.mesh.surface_get_material(0) != null:
		if not _shared.has("@glow"):
			var g: StandardMaterial3D = em.mesh.surface_get_material(0).duplicate()
			g.emission_enabled = true
			g.emission = Color(1.0, 0.82, 0.55)
			_shared["@glow"] = g
		em.set_surface_override_material(0, _shared["@glow"])
	return count

func _mesh_instances(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(_mesh_instances(c))
	return out


const BUTTON_SIZE := Vector3(1.32, 0.5, 0.08)

## One WIN / LOSE plate: pickable body, mesh, and its label.
func _button(label: String, won: bool, x: float) -> Area3D:
	var area := Area3D.new()
	area.name = label
	area.set_script(load("res://scripts/train/level_button.gd"))
	area.set("won", won)
	area.position = Vector3(x, 0.0, 0.0)

	var plate := MeshInstance3D.new(); plate.name = "Plate"
	var box := BoxMesh.new(); box.size = BUTTON_SIZE
	plate.mesh = box
	# &nolight -> the plates must not throw light back into the carriage
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.add_child(plate)

	var col := CollisionShape3D.new(); col.name = "Shape"
	var shape := BoxShape3D.new(); shape.size = BUTTON_SIZE
	col.shape = shape
	area.add_child(col)

	var text := Label3D.new(); text.name = "Text"
	text.text = label.to_upper()
	text.font_size = 96
	text.pixel_size = 0.0032
	text.position = Vector3(0.0, 0.0, BUTTON_SIZE.z * 0.5 + 0.01)
	text.modulate = Color(0.98, 0.97, 0.92)
	text.outline_size = 18
	text.outline_modulate = Color(0.05, 0.05, 0.06)
	text.no_depth_test = true
	area.add_child(text)
	return area

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "Train"
	root.set_script(load("res://scripts/train/train.gd"))

	# &consist -> ONE node. carriages are spawned at runtime by Consist, so none
	#             geometry is baked into this scene: the .scn stays small and the
	#             duplicated-instance bug cannot recur by construction.
	var consist := Node3D.new()
	consist.name = "Consist"
	consist.set_script(load("res://scripts/train/consist.gd"))
	consist.set("carriage_scene", load("res://assets/train/carriage.gltf"))
	consist.set("detail_normal", load("res://assets/train/detail_normal.png"))
	# &count -> the consist is as long as the content says. A location authored
	#           with a carriage index is a carriage that has to exist.
	consist.set("carriage_count", GameContent.carriage_locations().size())
	consist.set("pitch", 21.0)
	root.add_child(consist)
	print("consist node placed (cars spawn at runtime)")

	var rig := Node3D.new(); rig.name = "Rig"; root.add_child(rig)
	var cam := Camera3D.new(); cam.name = "Camera3D"
	cam.fov = 62.0
	cam.far = 1500.0
	rig.add_child(cam)

	# &loop -> WIN / LOSE are real meshes, parented to the camera so all three
	#          levels can see them. Train._place_buttons keeps them clear of
	#          the near plane, which SIDE pushes out past 10m
	var buttons := Node3D.new(); buttons.name = "Buttons"; cam.add_child(buttons)
	buttons.add_child(_button("Win", true, -0.78))
	buttons.add_child(_button("Lose", false, 0.78))

	var we := WorldEnvironment.new(); we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_horizon_color = Color(0.66, 0.68, 0.72)
	psm.ground_horizon_color = Color(0.36, 0.38, 0.34)
	psm.ground_bottom_color = Color(0.17, 0.19, 0.16)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	# &fog -> hides the terrain plane's far edge and does the mood work a murder
	#         mystery wants. cheaper than any geometry that would hide it
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.66, 0.71)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.4
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new(); sun.name = "Sun"
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)


	var backdrop := Node3D.new(); backdrop.name = "Backdrop"; root.add_child(backdrop)

	# &ground -> scrolls along X to sell motion while the carriage stays put
	var terrain := MeshInstance3D.new(); terrain.name = "Terrain"
	var pm := PlaneMesh.new(); pm.size = Vector2(2400.0, 2400.0)
	terrain.mesh = pm
	terrain.position = Vector3(0.0, -0.69, 0.0)
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = load("res://assets/train/terrain.png")
	tm.uv1_scale = Vector3(240.0, 240.0, 1.0)
	tm.roughness = 1.0
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	terrain.set_surface_override_material(0, tm)
	backdrop.add_child(terrain)

	# &night -> painted parallax forest, faded in by the day cycle. mirrored so
	#           both window rows have something sweeping past.
	var forest := Node3D.new()
	forest.name = "Forest"
	forest.set_script(load("res://scripts/world/parallax_backdrop.gd"))
	var tex: Array[Texture2D] = []
	for n: String in ["01_mist", "02_bushes", "03_particles", "04_forest", "05_particles",
			"06_forest", "07_forest", "08_forest", "09_forest"]:
		# &sky -> 10_sky dropped; the ProceduralSky already tracks the sun and the
		#         painted one would need depth-proportional size to cover the view
		tex.append(load("res://assets/backdrop/%s.png" % n))
	forest.set("layers", tex)
	backdrop.add_child(forest)


	var lighting := Node3D.new()
	lighting.name = "Lighting"
	lighting.set_script(load("res://scripts/world/world_lighting.gd"))
	root.add_child(lighting)
	lighting.set("sun_path", NodePath("../Sun"))
	lighting.set("environment_path", NodePath("../WorldEnvironment"))
	lighting.set("terrain_path", NodePath("../Backdrop/Terrain"))

	var dbg := CanvasLayer.new(); dbg.name = "Debug"; root.add_child(dbg)
	var label := Label.new(); label.name = "Label"
	label.position = Vector2(16, 16)
	label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	dbg.add_child(label)

	_own(root, root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK, "pack failed")
	# &guard -> this file is hand-edited in the editor. refuse to clobber it
	#           unless the caller explicitly opts in with OVERWRITE=1, and write
	#           somewhere harmless otherwise. a silent overwrite already cost a
	#           scene once.
	var target := OUT
	if FileAccess.file_exists(ProjectSettings.globalize_path(OUT)) \
			and not OS.has_environment("OVERWRITE"):
		target = OUT.get_basename() + "_generated." + OUT.get_extension()
		push_warning("%s exists; wrote %s instead. set OVERWRITE=1 to replace it." % [OUT, target])
		print("REFUSED to overwrite ", OUT)
	assert(ResourceSaver.save(packed, target) == OK, "save failed")
	print("SAVED ", target)
	root.free()
	quit()
