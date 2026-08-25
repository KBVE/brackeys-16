extends ECSSystem
class_name SSeatedIdle

## SSeatedIdle moves a seated character between the sitting clips.
##
## Runs before [SPosture], which is what actually asks the rig for a state: this only
## decides which of the seated ones it should be. Standing characters are left alone --
## their variation is the gait, which already answers to how fast they are walking.

func _on_update(delta: float) -> void:
	for entry: Dictionary in multi_view([CSeating, CSeatedIdle]):
		var idle: CSeatedIdle = entry[&"CSeatedIdle"]
		if not entry[&"CSeating"].seated:
			# back to the plain sit, so the next time they sit down it does not start
			# halfway through a nod
			idle.state = CPosture.SEATED
			idle.seconds_until_change = 0.0
			continue
		idle.seconds_until_change -= delta
		if idle.seconds_until_change <= 0.0:
			idle.state = _another(idle)
			idle.seconds_until_change = idle.rng.randf_range(
				idle.shortest_seconds, idle.longest_seconds)


## A seated state that is not the one already playing. Asking the transition for the
## state it is in restarts the crossfade, which reads as a stutter rather than a change.
func _another(idle: CSeatedIdle) -> StringName:
	var choices := CPosture.SEATED_STATES.filter(
		func(state: StringName) -> bool: return state != idle.state)
	return choices[idle.rng.randi_range(0, choices.size() - 1)]
