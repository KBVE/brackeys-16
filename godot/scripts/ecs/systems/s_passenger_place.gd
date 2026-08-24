extends ECSSystem
class_name SPassengerPlace

## SPassengerPlace walks every passenger to where their authored timeline says
## they are. This is the truth; what they CLAIM is prose in their `alibi` section,
## and the two disagreeing is the game.
##
## &lane -> pure data, no nodes. The obvious first promotion to ECSParallel once
##          the cast is large enough to pay for the dispatch. Five is not.

const MINUTES_PER_DAY := 1440

## Journey start, so boarding times can be measured as an offset from it rather
## than compared against a wall clock that wraps past midnight.
var departure_minutes: int = 0

func _on_update(_delta: float) -> void:
	var clocks: Array = view(&"CTimeOfDay")
	if clocks.is_empty():
		return
	var minutes: int = clocks[0].minutes_past_midnight
	var elapsed := _since_departure(minutes)

	for entry: Dictionary in multi_view([CPassenger, CIdentity, CLocation]):
		var passenger := GameContent.by_id("passengers", entry[&"CIdentity"].content_id)
		if passenger.is_empty():
			continue
		entry[&"CLocation"].location_id = _where(passenger, minutes, elapsed)


## &aboard -> before their boarding time a passenger is not on the train at all.
##            Without this, where_was() reads a clock earlier than their first
##            timeline step as the FOLLOWING day and reports where they end up:
##            Lady Beaumont sat in her cabin two hours before she boarded.
func _where(passenger: Dictionary, minutes: int, elapsed: int) -> StringName:
	var boarded: Dictionary = passenger.get("boarded", {})
	if boarded.has("at") and elapsed < _since_departure(_minutes_of(boarded["at"])):
		return &""
	return StringName(GameContent.where_was(passenger, minutes))


## Minutes travelled since departure. The journey is linear even though the
## clock it is told in wraps.
func _since_departure(minutes: int) -> int:
	return posmod(minutes - departure_minutes, MINUTES_PER_DAY)


func _minutes_of(hhmm: String) -> int:
	var parts := hhmm.split(":")
	return int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)
