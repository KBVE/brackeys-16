extends ECSComponent
class_name CViewer

## CViewer as one frame of viewer state. 
## Plain fields, not ECSDataComponent: this changes at 60Hz and set_data() fires a signal.

var world_x: float = 0.0
var aisle_yaw: float = 0.0
var daylight: float = 1.0
var carriage_index: int = 0

func write(x: float, yaw: float, day: float, carriage: int) -> void:
	world_x = x
	aisle_yaw = yaw
	daylight = day
	carriage_index = carriage
