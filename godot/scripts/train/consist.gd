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
## The bench seating, added per carriage rather than modelled into the shell.
## tools/build_carriage_variants.sh splits the original into the two, so a car
## can be dressed as something other than a seating saloon.
@export var seating_scene: PackedScene
## Carriages that stay bare, by index. Everything else gets the seating back, so
## adding a room here is what changes, not the look of the rest of the train.
@export var undressed_carriages: Array[int] = []
## The two end-wall door leaves, hinged at their own origins. Split out of the shell
## so they can swing; every carriage gets them.
@export var doors_scene: PackedScene
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
## The deck, found by casting a ray down the aisle against a trimesh of the carriage.
## It is not the model's lowest vertex, which is a bogie a metre under the rails, and
## it is not the busiest run of vertices either: the car body has an underside at 0.04
## and an underframe between, and both look like floors to anything counting them.
##
## Collision and drawing were two numbers until the seating was split out of the shell.
## They are one now, so a ray cast at the floor hits the floor the player can see, and
## the capsule stands on the deck rather than a plane a metre and a quarter beneath it.
const FLOOR_Y := 1.2735
## Where the cushions are, measured by dropping rays over the benches: the seating tops
## out 0.589 above the deck from z 0.55 to the wall, and the bays repeat every 2.4m,
## five to a car. Anchors rather than geometry, because what sits in them is an entity
## and entities need a place to be told about, not a surface to discover.
const CUSHION_ABOVE_FLOOR := 0.5891
const SEAT_CENTRE_Z := 0.95

## Rows every 2.4m out to 7.2 either side of the carriage centre. The seating mesh runs
## to 8.659, and the last row is held back from that so a seat is never half inside the
## bulkhead at the end of the car.
const SEAT_ROW_PITCH := 2.4
const SEAT_ROWS_EITHER_SIDE := 3

const INTERIOR_HALF_Z := 1.5

## The end wall and the hole in it. Without this a shut door is decoration: the
## player simply walks through the wall beside it, because the shell is a floor and
## two sides and has never had ends.
##
## Taken from the door leaf: the opening is exactly as wide and as tall as the thing
## that fills it, so a reshaped door does not leave a gap around its frame.
const END_WALL_X := 8.615
const END_WALL_THICKNESS := 0.1
const DOORWAY_HALF_Z := 0.52
const DOORWAY_HEIGHT := 2.44
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
		_dress(carriage, i)
		_hang_doors(carriage)
		# after the seating goes in, so its surfaces take the same shared materials
		# as the shell instead of keeping the ones the glb shipped with
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

## Puts the bench seating back into carriage [param index], unless it is meant to
## be a bare room. The seating is a child rather than part of the shell, so it is
## hidden and culled with the carriage and costs nothing when it is not there.
func _dress(carriage: Node3D, index: int) -> void:
	if seating_scene == null or undressed_carriages.has(index):
		return
	var seating := seating_scene.instantiate()
	seating.name = "Seating"
	carriage.add_child(seating)
	_add_seat_collision(seating)


## Collision for the benches, which the shell box cannot describe: it is a room, and a
## room with seats in it is not a box. Trimesh rather than a box per bench because the
## seating is its own mesh now and small enough to afford -- roughly two thousand
## triangles a car against the thirty-two thousand the whole shell would have cost,
## which is the reason the shell is still a box.
##
## What it buys is a floor a ray can find: the foot planting and anything that asks
## what is underfoot now get the seat top rather than the deck under it.
func _add_seat_collision(seating: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "SeatingCollision"
	for mesh: MeshInstance3D in _mesh_instances(seating):
		if mesh.mesh == null:
			continue
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		shape.transform = mesh.transform
		body.add_child(shape)
	if body.get_child_count() > 0:
		seating.add_child(body)
	else:
		body.free()


## Hangs both end doors. They keep the transform the glTF gave them, so each leaf
## already stands in its own doorway with its origin on the hinge; nothing here has
## to know where the ends of a carriage are.
func _hang_doors(carriage: Node3D) -> void:
	if doors_scene == null:
		return
	var doors := doors_scene.instantiate()
	doors.name = "Doors"
	carriage.add_child(doors)
	for leaf: Node in doors.get_children():
		if leaf is VisualInstance3D:
			_add_door_collision(leaf)


## A box the shape of the leaf, parented to it. Being a child is the whole trick:
## the collider turns with the door, so a shut leaf blocks the doorway and an open
## one has taken its collision out of the way along with its geometry.
##
## Measured off the mesh rather than written down, so a door reshaped in Blender
## does not need a number changed here to match.
func _add_door_collision(leaf: VisualInstance3D) -> void:
	var box := leaf.get_aabb()
	var body := StaticBody3D.new()
	body.name = "Collision"
	_add_box(body, box.size, box.position + box.size * 0.5)
	leaf.add_child(body)


## Every door leaf in the consist, in the order the carriages were built.
func door_leaves() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for carriage: Node3D in _carriages:
		var doors := carriage.get_node_or_null("Doors")
		if doors == null:
			continue
		for leaf: Node in doors.get_children():
			if leaf is Node3D:
				out.append(leaf)
	return out


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
	for end: float in [1.0, -1.0]:
		_add_end_wall(shell, end)
	carriage.add_child(shell)


## One end wall as three boxes around the doorway: a panel either side and a lintel
## over the top. Three boxes rather than a hole in one, because a BoxShape3D has no
## hole and a trimesh of the end wall would cost more than the whole shell does.
func _add_end_wall(shell: StaticBody3D, end: float) -> void:
	var x := end * END_WALL_X
	var panel_z := (INTERIOR_HALF_Z - DOORWAY_HALF_Z) * 0.5
	for side: float in [1.0, -1.0]:
		_add_box(shell,
			Vector3(END_WALL_THICKNESS, DOORWAY_HEIGHT, INTERIOR_HALF_Z - DOORWAY_HALF_Z),
			Vector3(x, FLOOR_Y + DOORWAY_HEIGHT * 0.5, side * (DOORWAY_HALF_Z + panel_z)))
	var lintel := WALL_HEIGHT - DOORWAY_HEIGHT
	_add_box(shell,
		Vector3(END_WALL_THICKNESS, lintel, INTERIOR_HALF_Z * 2.0),
		Vector3(x, FLOOR_Y + DOORWAY_HEIGHT + lintel * 0.5, 0.0))


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


## Every seat in the consist, in world space. Undressed carriages have no benches in
## them and so contribute none, which is what keeps a bare room bare.
func seat_anchors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(carriage_count):
		if seating_scene == null or undressed_carriages.has(i):
			continue
		for row in range(-SEAT_ROWS_EITHER_SIDE, SEAT_ROWS_EITHER_SIDE + 1):
			var bay := row * SEAT_ROW_PITCH
			for side: float in [1.0, -1.0]:
				out.append({
					"at": global_position + Vector3(_offset(i) + bay,
						FLOOR_Y + CUSHION_ABOVE_FLOOR, side * SEAT_CENTRE_Z),
					# the rows face down the train, so sitting squares him to it
					"facing": 0.0,
					"carriage": i,
				})
	return out
