class_name Wardrobe

## Wardrobe is the catalogue of every piece a character can be assembled from, and
## the same table the kit builder ships from. Runtime and build step read one list,
## so an outfit cannot roll a piece the export left behind.
##
## The parts are named out by hand rather than derived from the file names, because
## the pack does not keep to one convention: the knight's boots are
## Male_Knight_Feet_Armor for him and Female_Knight_Feet for her, and his legs carry
## an _Armor suffix hers does not.
##
## Everything here is library-relative. [method kit_path] turns one into the path the
## game actually loads, under [constant KIT_DIR], because the Web preset excludes
## res://assets/characters wholesale.

## Where the shared Quaternius library lives. Only tools/build_cast_kit.gd reads from
## here; nothing at runtime does.
const LIBRARY_DIR := "res://assets/characters/quaternius_ubc"

## Where the built cast kit lands, and the only character assets the Web build has.
const KIT_DIR := "res://assets/cast"

## Bodies are heads and necks, not whole bodies. A full body under a full outfit is
## two skinned surfaces a millimetre apart and the skin wins often enough to look
## like a hole in the coat; the outfit's Arms piece reaches the fingertips anyway.
##
## [code]skin_material[/code] is the material the neck and face carry, which is what
## a skin tone is applied to. The mesh node it sits on is named differently in every
## body, so the material is the stable handle.
const BODIES := {
	&"regular_male": {
		"model": "models/Regular_Male_OnlyHead.glb",
		"sex": &"male",
		"skin_material": &"MI_Regular_Male",
		"stature_metres": Vector2(1.68, 1.86),
	},
	&"regular_female": {
		"model": "models/Regular_Female_OnlyHead.glb",
		"sex": &"female",
		"skin_material": &"MI_Regular_Female",
		"stature_metres": Vector2(1.58, 1.74),
	},
	&"teen_male": {
		"model": "models/Teen_Male_OnlyHead.glb",
		"sex": &"male",
		"skin_material": &"MI_Teen_Male",
		"stature_metres": Vector2(1.52, 1.66),
	},
	&"teen_female": {
		"model": "models/Teen_Female_OnlyHead.glb",
		"sex": &"female",
		"skin_material": &"MI_Teen_Female",
		"stature_metres": Vector2(1.48, 1.62),
	},
}

## Hair is one slot and a beard is another, so a bearded man can still have a parting.
const HAIR := {
	&"simple_parted": {"model": "models/hair/Hair_SimpleParted.glb", "sex": &"any"},
	&"bob": {"model": "models/hair/Hair_Bob.glb", "sex": &"any"},
	&"long": {"model": "models/hair/Hair_Long.glb", "sex": &"any"},
	&"ponytail": {"model": "models/hair/Hair_Ponytail.glb", "sex": &"any"},
}

const BEARDS := {
	&"beard": {"model": "models/hair/Hair_Beard.glb", "sex": &"male"},
}

## An outfit is the four covering slots plus whatever it can wear over them. Wear all
## four or the bare skin shows through where a piece is missing, which is why they are
## one entry rather than four rollable slots.
##
## Accessories are rolled over the top and are all optional, so an outfit with none is
## still a complete outfit.
const OUTFITS := {
	&"male_peasant": {
		"sex": &"male",
		"parts": [
			"models/outfits/Male_Peasant_Body.glb",
			"models/outfits/Male_Peasant_Arms.glb",
			"models/outfits/Male_Peasant_Legs.glb",
			"models/outfits/Male_Peasant_Feet.glb",
		],
		"accessories": [],
	},
	&"female_peasant": {
		"sex": &"female",
		"parts": [
			"models/outfits/Female_Peasant_Body.glb",
			"models/outfits/Female_Peasant_Arms.glb",
			"models/outfits/Female_Peasant_Legs.glb",
			"models/outfits/Female_Peasant_Feet.glb",
		],
		"accessories": [],
	},
	&"male_noble": {
		"sex": &"male",
		"parts": [
			"models/outfits/Male_Noble_Body.glb",
			"models/outfits/Male_Noble_Arms.glb",
			"models/outfits/Male_Noble_Legs.glb",
			"models/outfits/Male_Noble_Feet.glb",
		],
		"accessories": [
			"models/outfits/Male_Noble_Acc_Gorget.glb",
			"models/outfits/Male_Noble_Acc_Pauldron.glb",
		],
	},
	&"female_noble": {
		"sex": &"female",
		"parts": [
			"models/outfits/Female_Noble_Body.glb",
			"models/outfits/Female_Noble_Arms.glb",
			"models/outfits/Female_Noble_Legs.glb",
			"models/outfits/Female_Noble_Feet.glb",
		],
		"accessories": [
			"models/outfits/Female_Noble_Acc_Gorget.glb",
			"models/outfits/Female_Noble_Acc_Pauldron.glb",
		],
	},
	&"male_ranger": {
		"sex": &"male",
		"parts": [
			"models/outfits/Male_Ranger_Body.glb",
			"models/outfits/Male_Ranger_Arms.glb",
			"models/outfits/Male_Ranger_Legs.glb",
			"models/outfits/Male_Ranger_Feet_Boots.glb",
		],
		"accessories": [
			"models/outfits/Male_Ranger_Acc_Pauldron.glb",
		],
	},
	&"female_ranger": {
		"sex": &"female",
		"parts": [
			"models/outfits/Female_Ranger_Body.glb",
			"models/outfits/Female_Ranger_Arms.glb",
			"models/outfits/Female_Ranger_Legs.glb",
			"models/outfits/Female_Ranger_Feet.glb",
		],
		"accessories": [
			"models/outfits/Female_Ranger_Acc_Pauldrons.glb",
		],
	},
	&"male_wizard": {
		"sex": &"male",
		"parts": [
			"models/outfits/Male_Wizard_Body.glb",
			"models/outfits/Male_Wizard_Arms.glb",
			"models/outfits/Male_Wizard_Legs.glb",
			"models/outfits/Male_Wizard_Feet.glb",
		],
		"accessories": [],
	},
	&"female_wizard": {
		"sex": &"female",
		"parts": [
			"models/outfits/Female_Wizard_Body.glb",
			"models/outfits/Female_Wizard_Arms.glb",
			"models/outfits/Female_Wizard_Legs.glb",
			"models/outfits/Female_Wizard_Feet.glb",
		],
		"accessories": [],
	},
	&"male_knight": {
		"sex": &"male",
		"parts": [
			"models/outfits/Male_Knight_Body_Cloth.glb",
			"models/outfits/Male_Knight_Arms.glb",
			"models/outfits/Male_Knight_Legs_Armor.glb",
			"models/outfits/Male_Knight_Feet_Armor.glb",
		],
		"accessories": [
			"models/outfits/Male_Knight_Acc_Scarf.glb",
			"models/outfits/Male_Knight_Acc_Pauldron_Round.glb",
		],
	},
	&"female_knight": {
		"sex": &"female",
		"parts": [
			"models/outfits/Female_Knight_Body_Cloth.glb",
			"models/outfits/Female_Knight_Arms.glb",
			"models/outfits/Female_Knight_Legs.glb",
			"models/outfits/Female_Knight_Feet.glb",
		],
		"accessories": [
			"models/outfits/Female_Knight_Acc_Scarf.glb",
			"models/outfits/Female_Knight_Acc_Pauldrons_Round.glb",
		],
	},
}

## What the cast kit actually ships, which is not the whole catalogue. Every entry
## here is a few hundred KB of glb plus its share of a texture set in the Web build,
## so this is the line where variety is paid for. The catalogue above stays complete
## so widening the pool is a one-line edit rather than a research trip.
##
## Wizard and knight are catalogued and not shipped: this is a train in 1912.
const POOL := {
	"bodies": [&"regular_male", &"regular_female", &"teen_female"],
	"outfits": [&"male_peasant", &"female_peasant", &"male_noble", &"female_noble"],
	"hair": [&"simple_parted", &"bob", &"long", &"ponytail"],
	"beards": [&"beard"],
}

## Multiplied into the cloth albedo, so one outfit reads as several. Kept dull and
## desaturated: these are travelling clothes under gas lamps, and a saturated tint on
## a texture that already has colour in it turns to poster paint.
const CLOTH_TINTS: Array[Color] = [
	Color(1.00, 1.00, 1.00),
	Color(0.72, 0.74, 0.82),
	Color(0.85, 0.76, 0.66),
	Color(0.62, 0.66, 0.62),
	Color(0.80, 0.62, 0.60),
	Color(0.58, 0.56, 0.64),
]

## Only ever darkens. The base colour map is the lightest the skin should read, and a
## tint above 1.0 blows the shading out of it.
const SKIN_TINTS: Array[Color] = [
	Color(1.00, 1.00, 1.00),
	Color(0.92, 0.86, 0.80),
	Color(0.78, 0.68, 0.60),
	Color(0.62, 0.52, 0.45),
]

const HAIR_TINTS: Array[Color] = [
	Color(1.00, 1.00, 1.00),
	Color(0.45, 0.34, 0.26),
	Color(0.28, 0.24, 0.22),
	Color(0.72, 0.62, 0.46),
	Color(0.70, 0.70, 0.72),
]

## The five who are evidence. A named passenger has to be recognisable two carriages
## later, so their clothes are written down rather than rolled, and every piece here is
## one [constant POOL] ships.
##
## Anyone not listed rolls off their content id, which is what the crowd will do.
const CAST := {
	&"beaumont": {
		"stature_metres": 1.61,
		"body": &"regular_female",
		"outfit": &"female_noble",
		"hair": &"long",
		"accessories": ["models/outfits/Female_Noble_Acc_Gorget.glb"],
		"cloth_tint": Color(0.34, 0.32, 0.36),
		"skin_tint": Color(0.96, 0.92, 0.88),
		"hair_tint": Color(0.72, 0.72, 0.74),
	},
	&"carrow": {
		"stature_metres": 1.55,
		"body": &"teen_female",
		"outfit": &"female_peasant",
		"hair": &"bob",
		"cloth_tint": Color(0.62, 0.66, 0.62),
		"skin_tint": Color(0.92, 0.86, 0.80),
		"hair_tint": Color(0.45, 0.34, 0.26),
	},
	&"dupont": {
		"stature_metres": 1.71,
		"body": &"regular_male",
		"outfit": &"male_peasant",
		"hair": &"simple_parted",
		"beard": &"beard",
		"cloth_tint": Color(0.85, 0.76, 0.66),
		"skin_tint": Color(0.78, 0.68, 0.60),
		"hair_tint": Color(0.28, 0.24, 0.22),
	},
	&"thompson": {
		"stature_metres": 1.84,
		"body": &"regular_male",
		"outfit": &"male_noble",
		"hair": &"simple_parted",
		"cloth_tint": Color(0.58, 0.56, 0.64),
		"skin_tint": Color(1.00, 1.00, 1.00),
		"hair_tint": Color(0.72, 0.62, 0.46),
	},
	&"weiss": {
		"stature_metres": 1.69,
		"body": &"regular_male",
		"outfit": &"male_noble",
		"hair": &"simple_parted",
		"beard": &"beard",
		"accessories": ["models/outfits/Male_Noble_Acc_Gorget.glb"],
		"cloth_tint": Color(0.72, 0.74, 0.82),
		"skin_tint": Color(0.92, 0.86, 0.80),
		"hair_tint": Color(0.70, 0.70, 0.72),
	},
}

## Odds an accessory the outfit offers is actually worn, per accessory.
const ACCESSORY_CHANCE := 0.5

## Odds a man who could grow one has.
const BEARD_CHANCE := 0.35


## The path the game loads a catalogued piece from. Always the kit, never the library:
## a rig that reached into res://assets/characters would work in the editor and
## disappear in the Web build.
static func kit_path(relative: String) -> String:
	return "%s/%s" % [KIT_DIR, relative]


static func library_path(relative: String) -> String:
	return "%s/%s" % [LIBRARY_DIR, relative]


## A whole character, decided by [param character_seed] alone. The same seed is the
## same person on every machine and every reload, which is what lets a passenger be
## recognised as the woman in the grey coat two carriages later.
static func roll(character_seed: int) -> CAppearance:
	var rng := RandomNumberGenerator.new()
	rng.seed = character_seed

	var appearance := CAppearance.new()
	appearance.character_seed = character_seed
	appearance.body = _pick(rng, POOL["bodies"])

	var sex: StringName = BODIES[appearance.body]["sex"]
	appearance.outfit = _pick(rng, _matching(POOL["outfits"], OUTFITS, sex))
	appearance.hair = _pick(rng, _matching(POOL["hair"], HAIR, sex))

	var beards: Array = _matching(POOL["beards"], BEARDS, sex)
	if not beards.is_empty() and rng.randf() < BEARD_CHANCE:
		appearance.beard = _pick(rng, beards)

	for accessory: String in OUTFITS[appearance.outfit]["accessories"]:
		if rng.randf() < ACCESSORY_CHANCE:
			appearance.accessories.append(accessory)

	var stature: Vector2 = BODIES[appearance.body]["stature_metres"]
	appearance.stature_metres = rng.randf_range(stature.x, stature.y)

	appearance.cloth_tint = CLOTH_TINTS[rng.randi() % CLOTH_TINTS.size()]
	appearance.skin_tint = SKIN_TINTS[rng.randi() % SKIN_TINTS.size()]
	appearance.hair_tint = HAIR_TINTS[rng.randi() % HAIR_TINTS.size()]
	return appearance


## A seed for [method roll] from an authored id, so unnamed passengers are stable
## without anyone writing a number into the content.
static func seed_of(content_id: StringName) -> int:
	return int(String(content_id).hash())


## What the passenger with [param content_id] wears: what [constant CAST] says, or a
## roll off their id when nobody has written them down.
static func appearance_of(content_id: StringName) -> CAppearance:
	if not CAST.has(content_id):
		return roll(seed_of(content_id))

	var written: Dictionary = CAST[content_id]
	var appearance := CAppearance.new()
	appearance.character_seed = seed_of(content_id)
	appearance.body = written.get("body", &"regular_male")
	appearance.outfit = written.get("outfit", &"male_peasant")
	appearance.hair = written.get("hair", &"")
	appearance.beard = written.get("beard", &"")
	appearance.accessories = PackedStringArray(written.get("accessories", []))
	appearance.stature_metres = written.get("stature_metres",
		BODIES[appearance.body]["stature_metres"].y)
	appearance.cloth_tint = written.get("cloth_tint", Color.WHITE)
	appearance.skin_tint = written.get("skin_tint", Color.WHITE)
	appearance.hair_tint = written.get("hair_tint", Color.WHITE)
	return appearance


## Every glb the rig has to graft onto the body, in the order they go on: hair before
## the outfit, accessories last, because a pauldron sits over a sleeve.
static func pieces_of(appearance: CAppearance) -> PackedStringArray:
	var pieces := PackedStringArray()
	if HAIR.has(appearance.hair):
		pieces.append(HAIR[appearance.hair]["model"])
	if BEARDS.has(appearance.beard):
		pieces.append(BEARDS[appearance.beard]["model"])
	if OUTFITS.has(appearance.outfit):
		for part: String in OUTFITS[appearance.outfit]["parts"]:
			pieces.append(part)
	for accessory: String in appearance.accessories:
		pieces.append(accessory)
	return pieces


static func body_model_of(appearance: CAppearance) -> String:
	return BODIES[appearance.body]["model"] if BODIES.has(appearance.body) else ""


static func skin_material_of(appearance: CAppearance) -> StringName:
	return BODIES[appearance.body]["skin_material"] if BODIES.has(appearance.body) else &""


## Every model the pool can ask for, which is what tools/build_cast_kit.gd copies.
## Library-relative, deduplicated, order not meaningful.
static func pooled_models() -> PackedStringArray:
	var models := PackedStringArray()
	for key: StringName in POOL["bodies"]:
		_append_once(models, BODIES[key]["model"])
	for key: StringName in POOL["hair"]:
		_append_once(models, HAIR[key]["model"])
	for key: StringName in POOL["beards"]:
		_append_once(models, BEARDS[key]["model"])
	for key: StringName in POOL["outfits"]:
		for part: String in OUTFITS[key]["parts"]:
			_append_once(models, part)
		for accessory: String in OUTFITS[key]["accessories"]:
			_append_once(models, accessory)
	return models


## Catalogue entries from [param keys] that the given sex can wear. Anything marked
## `any` is in both lists.
static func _matching(keys: Array, catalogue: Dictionary, sex: StringName) -> Array:
	return keys.filter(func(key: StringName) -> bool:
		if not catalogue.has(key):
			return false
		var wearer: StringName = catalogue[key]["sex"]
		return wearer == sex or wearer == &"any")


static func _pick(rng: RandomNumberGenerator, from: Array) -> StringName:
	return from[rng.randi() % from.size()] if not from.is_empty() else &""


static func _append_once(into: PackedStringArray, path: String) -> void:
	if path != "" and into.find(path) < 0:
		into.append(path)
