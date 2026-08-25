extends Node

## Session : ECS state that outlives a scene swap.

## Where the Order's escort stands, and who stands there. Two sworn knights on a crate
## nobody is permitted to open, from the hour it is loaded to the hour it is unloaded.
##
## They are not passengers: no berth, no timeline, no alibi, and nothing in the content
## about them, because they are the image the guard's van is selling rather than anybody
## the mystery turns on. Dame Marchand is the one with a name, and she is content.
##
## The seeds are written down rather than derived so the two of them stay the two of
## them; the faces under the helmets are rolled, the plate is not.
const ESCORT_LOCATION := &"guard_van"
const ESCORT := [
	{"seed": 0x5eed_0001, "outfit": &"male_knight"},
	{"seed": 0x5eed_0002, "outfit": &"female_knight"},
]

## Departure, in minutes past midnight. Earliest authored timeline is Dupont boarding at Paris.
const DEPARTURE_MINUTES := 16 * 60 + 5

var time_of_day: CTimeOfDay
var run: CRun

var _scope := ECSScope.new()
var _clock: SClock

func _ready() -> void:
	time_of_day = CTimeOfDay.new()
	run = CRun.new()
	_scope.spawn().add(time_of_day).add(run)

	_clock = SClock.new()
	_clock.world_minutes_per_second = 1.0
	_scope.add_system(&"clock", _clock)
	var places := SPassengerPlace.new()
	places.departure_minutes = DEPARTURE_MINUTES
	_scope.add_system(&"passenger_place", places)

	# What they wear is decided here, once, rather than when a carriage comes into
	# view: the rig [SCastBody] builds is thrown away and rebuilt every time the player
	# walks back, and a passenger who changed coat on the way past would be a lie the
	# whole game is about telling deliberately.
	for passenger: Dictionary in GameContent.passengers():
		var identity := CIdentity.new()
		identity.content_id = passenger.get("id", "")
		_scope.spawn().add(CPassenger.new()).add(identity).add(CLocation.new()) \
			.add(Wardrobe.appearance_of(identity.content_id)).add(CCharacterRig.new())

	for sworn: Dictionary in ESCORT:
		var post := CLocation.new()
		post.location_id = ESCORT_LOCATION
		_scope.spawn().add(post).add(CCharacterRig.new()) \
			.add(Wardrobe.roll(sworn["seed"], sworn["outfit"]))

	begin()


## Resets the run in place. The component instances survive, so anything holding
## a reference to them keeps working across a restart.
func begin() -> void:
	run.level_index = 0
	run.score = 0
	run.outcome = &"start"
	time_of_day.running = true
	_clock.set_minutes(time_of_day, DEPARTURE_MINUTES)


func _exit_tree() -> void:
	_scope.dispose()
