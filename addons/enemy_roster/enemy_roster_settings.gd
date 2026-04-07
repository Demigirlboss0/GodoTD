@tool
extends Resource
class_name EnemyRosterSettings

enum ProjectMode { MODE_2D, MODE_3D }

@export var project_mode: ProjectMode = ProjectMode.MODE_2D
@export var output_directory: String = "res://enemies/"
@export var resource_types: Array[String] = ["money"]
@export var known_tags: Array[String] = []