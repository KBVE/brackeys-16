extends Area3D
class_name LevelButton

## LevelButton : Area3D
## &world -> a real mesh in the carriage, not a Control. It rides the camera rig
##           so every shot can see it, but it is still a 3D object: lit, tweened
##           and picked like the rest of the scene
## &pick  -> Area3D picking needs Viewport.physics_object_picking, which TrainCar
##           turns on; without it input_event never fires

signal pressed(won: bool)

const WIN_TINT := Color(0.30, 0.72, 0.38)
const LOSE_TINT := Color(0.74, 0.22, 0.18)

@export var won: bool = true

var _mat: StandardMaterial3D
var _hover := false

@onready var _plate: MeshInstance3D = $Plate

func _ready() -> void:
	var tint := WIN_TINT if won else LOSE_TINT
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint
	_mat.emission_enabled = true
	_mat.emission = tint
	_mat.emission_energy_multiplier = 0.6
	# &readable -> the carriage goes fully dark at night; unshaded keeps the button legible
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plate.set_surface_override_material(0, _mat)

	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _on_hover(entering: bool) -> void:
	_hover = entering
	_mat.emission_energy_multiplier = 1.6 if entering else 0.6
	scale = Vector3.ONE * (1.08 if entering else 1.0)

func _on_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_flash()
	pressed.emit(won)

func _flash() -> void:
	_mat.emission_energy_multiplier = 3.0
	var tween := create_tween()
	tween.tween_property(_mat, "emission_energy_multiplier", 1.6 if _hover else 0.6, 0.25)
