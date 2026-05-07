@tool
extends Resource
class_name RosterProperty

## Typed definition of a single property in a roster schema.
## Replaces the previous pseudo-typed Dictionary approach.

enum PropertyType {
	TYPE_STRING,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_BOOL,
	TYPE_ENUM,
	TYPE_PACKED_SCENE,
	TYPE_TAG_ARRAY,
	TYPE_DICTIONARY
}

@export var property_name: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export var type: PropertyType = PropertyType.TYPE_STRING
@export var default_value: Variant = ""

## Only used when type == TYPE_ENUM
@export var enum_name: String = ""
@export var enum_values: Array[String] = []

func get_gdscript_type() -> String:
	match type:
		PropertyType.TYPE_STRING: return "String"
		PropertyType.TYPE_INT: return "int"
		PropertyType.TYPE_FLOAT: return "float"
		PropertyType.TYPE_BOOL: return "bool"
		PropertyType.TYPE_ENUM: return enum_name if enum_name != "" else "int"
		PropertyType.TYPE_PACKED_SCENE: return "PackedScene"
		PropertyType.TYPE_TAG_ARRAY: return "Array[String]"
		PropertyType.TYPE_DICTIONARY: return "Dictionary"
	return "Variant"

func get_default_value_typed() -> Variant:
	if default_value != null and typeof(default_value) != TYPE_NIL:
		return default_value
	match type:
		PropertyType.TYPE_STRING: return ""
		PropertyType.TYPE_INT: return 0
		PropertyType.TYPE_FLOAT: return 0.0
		PropertyType.TYPE_BOOL: return false
		PropertyType.TYPE_ENUM: return 0
		PropertyType.TYPE_PACKED_SCENE: return null
		PropertyType.TYPE_TAG_ARRAY: return [] as Array[String]
		PropertyType.TYPE_DICTIONARY: return {}
	return null

func get_display_label() -> String:
	if display_name != "":
		return display_name
	return property_name.capitalize().replace("_", " ") + ":"
