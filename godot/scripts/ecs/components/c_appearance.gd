extends ECSComponent
class_name CAppearance

## CAppearance is what a character looks like, as data. Nothing here is a node or a
## resource: [SCastBody] turns it into a [CharacterRig] when the carriage it belongs
## to comes into view, and throws the rig away again when it does not.
##
## Keys index [Wardrobe]. Authored for the cast, whose clothes are evidence, and
## rolled from [member character_seed] for everyone else.

## Key into [constant Wardrobe.BODIES].
var body: StringName = &"regular_male"

## Key into [constant Wardrobe.OUTFITS]. Carries all four covering slots at once.
var outfit: StringName = &"male_peasant"

## Key into [constant Wardrobe.HAIR], or empty for none.
var hair: StringName = &""

## Key into [constant Wardrobe.BEARDS], or empty for none.
var beard: StringName = &""

## Library-relative model paths worn over the outfit, from its own accessory list.
var accessories: PackedStringArray = PackedStringArray()

## Multiplied into the albedo of the cloth, the skin and the hair. White leaves the
## texture as it was authored.
var cloth_tint := Color.WHITE
var skin_tint := Color.WHITE
var hair_tint := Color.WHITE

## Crown to sole, in metres, handed to [member CharacterRig.stature_metres]. Rolled
## within a range the body allows, so a teen is not an adult who came out short.
var stature_metres: float = 1.75

## What [method Wardrobe.roll] was given, kept so a rig can be rebuilt or a placement
## jittered without a second source of randomness.
var character_seed: int = 0
