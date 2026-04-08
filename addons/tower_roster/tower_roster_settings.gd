@tool
extends Resource
class_name TowerRosterSettings

enum ProjectMode { MODE_2D, MODE_3D }

@export var project_mode: ProjectMode = ProjectMode.MODE_2D
@export var output_directory: String = "res://towers/"
@export var resource_types: Array[String] = []
@export var known_tags: Array[String] = []