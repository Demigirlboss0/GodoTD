@tool
extends Resource
class_name RosterSchema

## Defines the schema for a roster system (towers, enemies, etc.)

@export var roster_name: String = "Roster"
@export var roster_icon: String = "res://icon.svg"
@export var output_directory: String = "res://"
@export var data_class_name: String = "RosterData"
@export var data_class_script_path: String = "res://RosterData.gd"

@export var base_properties: Array[RosterProperty] = []

@export var dynamic_properties_label: String = "Dynamic"
@export var dynamic_properties_key: String = "dynamic"

@export var project_mode: int = 0  ## 0 = 2D, 1 = 3D
@export var resource_types: Array[String] = []
@export var known_tags: Array[String] = []

func get_properties_by_category(category: String) -> Array[RosterProperty]:
	var result: Array[RosterProperty] = []
	for prop in base_properties:
		if prop.category == category:
			result.append(prop)
	return result

func get_categories() -> Array[String]:
	var cats: Array[String] = []
	for prop in base_properties:
		if prop.category != "" and not prop.category in cats:
			cats.append(prop.category)
	return cats

func get_property_by_name(name: String) -> RosterProperty:
	for prop in base_properties:
		if prop.property_name == name:
			return prop
	return null

func get_name_property() -> RosterProperty:
	if base_properties.size() > 0:
		return base_properties[0]
	return null
