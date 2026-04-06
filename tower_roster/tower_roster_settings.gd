@tool
extends Resource
class_name TowerRosterSettings

enum ProjectMode {
	MODE_2D,
	MODE_3D
}

@export var project_mode: ProjectMode = ProjectMode.MODE_2D
@export var output_directory: String = "res://towers/"
@export var resource_types: Array[String] = []
@export var known_tags: Array[String] = []

func get_project_mode_string() -> String:
	return "2D" if project_mode == ProjectMode.MODE_2D else "3D"

func set_project_mode_from_string(mode: String) -> void:
	project_mode = ProjectMode.MODE_2D if mode == "2D" else ProjectMode.MODE_3D

func add_resource_type(type_name: String) -> void:
	if not type_name in resource_types:
		resource_types.append(type_name)

func remove_resource_type(type_name: String) -> int:
	var index = resource_types.find(type_name)
	if index != -1:
		resource_types.remove_at(index)
	return index

func rename_resource_type(old_name: String, new_name: String) -> void:
	var index = resource_types.find(old_name)
	if index != -1:
		resource_types[index] = new_name

func add_known_tag(tag: String) -> void:
	if not tag in known_tags:
		known_tags.append(tag)

func remove_known_tag(tag: String) -> int:
	var index = known_tags.find(tag)
	if index != -1:
		known_tags.remove_at(index)
	return index

func rename_known_tag(old_tag: String, new_tag: String) -> void:
	var index = known_tags.find(old_tag)
	if index != -1:
		known_tags[index] = new_tag