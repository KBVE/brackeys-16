extends Node3D
class_name Consist

## Consist : Node3D
## Cars share meshes, materials and textures, so length costs transforms and draw
## calls only. VRAM does not move with [member carriage_count].
## Looking down the aisle points the camera along the train, so every carriage
## ahead sits in the frustum and frustum culling saves nothing. Web has no
## occlusion culling either, so cull by carriage index, explicitly.
## Measured (tools/bench_consist.gd, native, 1080p, vsync off): 21 cars drawn
## 1.14ms, windowed 0.64ms, O(1) in length. Lights dominate: 0.85 -> 0.46ms by
## hiding lamps at equal geometry.

@export var carriage_scene: PackedScene
@export var detail_normal: Texture2D
@export_range(1, 32) var carriage_count: int = 5
## Car centre spacing. Mesh bounds are 20.88m, so 21.0 butts the end platforms.
@export var pitch: float = 21.0
## Cars either side of the viewer that draw. Lamps use the tighter window.
@export_range(0, 8) var mesh_window: int = 2
@export_range(0, 8) var lamp_window: int = 1
@export var lamps_per_car: int = 6

## The walkable interior, as a box. The carriage mesh is 32k triangles and a
## trimesh of it would be that much physics geometry per car, for a corridor
## that is in the end a box. Z is inside the 1.69 shell, leaving the panelling
## thickness the player never reaches through.
const FLOOR_Y := 0.0

## Where the floorboards are actually drawn, found by casting a ray down the aisle
## against a trimesh of the carriage. It is not the model's lowest vertex, which is a
## bogie a metre under the rails, and it is not the busiest run of vertices either:
## the car body has an underside at 0.04 and an underframe between, and both look
## like floors to anything counting vertices. The deck is a metre and a quarter up.
##
## [constant FLOOR_Y] is a metre and a quarter below it and stays there. The player's
## capsule is sized against it, and moving it lifts him off his own collider; nothing
## stands on the collision floor anyway, because the walk pins Y rather than falling.
## What needed the real number was the body, which was buried to the ankles without it.
const DRAWN_FLOOR_Y := 1.2735
const INTERIOR_HALF_Z := 1.5
const WALL_HEIGHT := 3.5
const SHELL_THICKNESS := 0.4

var _carriages: Array[Node3D] = []
var _lampsets: Array[Node3D] = []
var _shared: Dictionary = {}

func _ready() -> void:
	if carriage_scene == null:
		push_error("Consist: carriage_scene not set")
		return
	for i in range(carriage_count):
		var carriage: Node3D = carriage_scene.instantiate()
		carriage.name = "Carriage_%02d" % i
		carriage.position = Vector3(_offset(i), 0.0, 0.0)
		_reskin(carriage)
		var lamps := Node3D.new()
		lamps.name = "Lamps"
		for j in range(lamps_per_car):
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(-6.2 + j * 2.48, 4.05, 0.0)
			lamp.omni_range = 7.0
			lamp.omni_attenuation = 1.4
			lamp.light_color = Color(1.0, 0.84, 0.6)
			lamp.light_energy = 4.0
			lamps.add_child(lamp)
		carriage.add_child(lamps)
		_add_shell(carriage)
		add_child(carriage)
		_carriages.append(carriage)
		_lampsets.append(lamps)
	_add_end_caps()

## Floor and side walls, so the player is inside something rather than beside it.
## Culling hides a carriage but leaves its bodies live, which is what stops the
## player walking out through a car they cannot currently see.
func _add_shell(carriage: Node3D) -> void:
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	_add_box(shell, Vector3(pitch, SHELL_THICKNESS, INTERIOR_HALF_Z * 2.0),
		Vector3(0.0, FLOOR_Y - SHELL_THICKNESS * 0.5, 0.0))
	for side: float in [1.0, -1.0]:
		_add_box(shell, Vector3(pitch, WALL_HEIGHT, SHELL_THICKNESS),
			Vector3(0.0, WALL_HEIGHT * 0.5, side * (INTERIOR_HALF_Z + SHELL_THICKNESS * 0.5)))
	carriage.add_child(shell)


func _add_box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


## Caps the open ends of the consist, so the corridor stops where the train does.
func _add_end_caps() -> void:
	var caps := StaticBody3D.new()
	caps.name = "EndCaps"
	var reach := carriage_count * pitch * 0.5
	for side: float in [1.0, -1.0]:
		_add_box(caps, Vector3(SHELL_THICKNESS, WALL_HEIGHT, INTERIOR_HALF_Z * 2.0),
			Vector3(side * (reach + SHELL_THICKNESS * 0.5), WALL_HEIGHT * 0.5, 0.0))
	add_child(caps)


## Centre of carriage [param i] in local X. Consist is centred on its own origin.
func _offset(i: int) -> float:
	return (i - (carriage_count - 1) / 2.0) * pitch

## Index of the carriage containing local X [param x], clamped to the consist.
func carriage_index_at(x: float) -> int:
	return clampi(int(round(x / pitch + (carriage_count - 1) / 2.0)), 0, carriage_count - 1)

## Show only the carriages near [param x]; hiding one hides its lamps with it.
func cull_around(x: float) -> void:
	for i in range(_carriages.size()):
		var d: float = absf(_carriages[i].position.x - x) / pitch
		_carriages[i].visible = d <= float(mesh_window)
		_lampsets[i].visible = d <= float(lamp_window)

## The lamp holder for carriage [param index]. Hidden while it is culled.
func lamps_for(index: int) -> Node3D:
	return _lampsets[index] if index >= 0 and index < _lampsets.size() else null

## The shared emissive material, or null. Drive its energy for the lamp glass.
func glow_material() -> StandardMaterial3D:
	return _shared.get("@glow")

func tune_detail(tiling: float, strength: float, albedo: float) -> void:
	for key: String in _shared:
		var sm := _shared[key] as ShaderMaterial
		if sm == null:
			continue
		sm.set_shader_parameter("detail_tiling", tiling)
		sm.set_shader_parameter("detail_strength", strength)
		sm.set_shader_parameter("detail_albedo", albedo)

func _reskin(carriage: Node3D) -> void:
	for mi: MeshInstance3D in _mesh_instances(carriage):
		var m: Mesh = mi.mesh
		for i in range(m.get_surface_count()):
			var src := m.surface_get_material(i) as StandardMaterial3D
			if src == null or src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue # window panes keep their own material
			mi.set_surface_override_material(i, _material_for(src))
	var em := carriage.get_node_or_null("emissive") as MeshInstance3D
	if em != null and em.mesh.surface_get_material(0) != null:
		if not _shared.has("@glow"):
			var g: StandardMaterial3D = em.mesh.surface_get_material(0).duplicate()
			g.emission_enabled = true
			g.emission = Color(1.0, 0.82, 0.55)
			_shared["@glow"] = g
		em.set_surface_override_material(0, _shared["@glow"])

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
	sm.set_shader_parameter("tex_detail", detail_normal)
	_shared[key] = sm
	return sm

func _mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(_mesh_instances(c))
	return out
