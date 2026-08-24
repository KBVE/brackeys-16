extends Node3D
class_name Consist

## Consist : Node3D
## &why  -> cars share meshes, materials and textures, so length costs transforms
##          and draw calls only. VRAM does not move with carriage_count.
## &cull -> looking down the aisle points the camera along the train, so every
##          carriage ahead sits in the frustum and frustum culling saves nothing.
##          web has no occlusion culling either -> cull by carriage index, explicitly.
## &cost -> measured (tools/bench_consist.gd, native, 1080p, vsync off):
##          21 cars drawn 1.14ms | windowed 0.64ms. windowed is O(1) in length.
##          lights dominate: 0.85 -> 0.46ms by hiding lamps at equal geometry.

@export var carriage_scene: PackedScene
@export var detail_normal: Texture2D
@export_range(1, 32) var carriage_count: int = 5
## Car centre spacing. Mesh bounds are 20.88m, so 21.0 butts the end platforms.
@export var pitch: float = 21.0
## Cars either side of the viewer that draw. Lamps use the tighter window.
@export_range(0, 8) var mesh_window: int = 2
@export_range(0, 8) var lamp_window: int = 1
@export var lamps_per_car: int = 6

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
		add_child(carriage)
		_carriages.append(carriage)
		_lampsets.append(lamps)

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

## Discards carriage fragments with world Z above [param z]; use a huge value
## to disable. Replaces the camera near-plane trick, which also clipped terrain.
func set_clip_z(z: float) -> void:
	for key: String in _shared:
		var sm := _shared[key] as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("clip_z_above", z)

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
				continue # &glass -> window panes keep their own material
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
