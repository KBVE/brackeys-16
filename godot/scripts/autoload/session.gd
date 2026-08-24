extends Node

## Session ecs state that holds time.

const DEPARTURE_MINUTES := 16 * 60 + 5

var time_of_day: CTimeOfDay

var _scope := ECSScope.new()

func _ready() -> void:
	begin()


## Drops the previous run's state and starts a fresh one.
func begin() -> void:
	_scope.dispose()
	time_of_day = CTimeOfDay.new()
	_scope.spawn().add(time_of_day)
	var clock := SClock.new()
	clock.world_minutes_per_second = 1.0
	_scope.add_system(&"clock", clock)
	clock.set_minutes(time_of_day, DEPARTURE_MINUTES)


func _exit_tree() -> void:
	_scope.dispose()
