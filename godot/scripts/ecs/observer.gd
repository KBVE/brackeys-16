extends Node
class_name ECSObserver

## ECSObserver : query-driven reactive node
##
## &gap -> godot-ecs has ECSSystem (polls) and GameEventCenter (flat bus), no observer
## &use -> override query() + each(), or sub_observers() for several axes
## &tuple -> [query, callable] ; callable takes (event, entity, payload)
##
## [codeblock]
## func query() -> ECSObserverQuery:
##     return q.with([CHealth]).on_added().on_removed()
##
## func each(event: int, entity: ECSEntity, payload: Variant) -> void:
##     match event:
##         Event.ADDED:   print("gained ", payload)
##         Event.REMOVED: print("lost on ", entity)
## [/codeblock]


enum Event {
	ADDED = 0,    ## watched component added
	REMOVED = 1,  ## watched component removed
	CHANGED = 2,  ## watched [ECSDataComponent] value changed
	MATCH = 3,    ## entity newly satisfies the query
	UNMATCH = 4,  ## entity no longer satisfies the query
	EVENT = 5,    ## named event on the world bus
}


@export var active: bool = true

var _world: ECSWorld = null

## &fresh -> new query per access; tuples never share state
var q: ECSObserverQuery:
	get:
		return ECSObserverQuery.new(_world) if _world else null


func world() -> ECSWorld:
	return _world

# ---- &overrides ----

## &override -> null when using sub_observers()
func query() -> ECSObserverQuery:
	return null

## &override -> several [query, callable] pairs
func sub_observers() -> Array[Array]:
	return []

## &payload -> component on ADDED/REMOVED | value on CHANGED
##             | dispatched value on EVENT | null on MATCH/UNMATCH
func each(_event: int, _entity: ECSEntity, _payload: Variant) -> void:
	pass

# ---- &internals ----

func _set_world(w: ECSWorld) -> void:
	_world = w


func _collect_bindings() -> Array[Array]:
	var subs := sub_observers()
	if not subs.is_empty():
		return subs
	var single := query()
	if single == null:
		push_warning("%s declares neither query() nor sub_observers()." % self)
		return []
	return [[single, each]] as Array[Array]
