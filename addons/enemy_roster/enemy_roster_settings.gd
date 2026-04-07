@tool
extends Resource
class_name EnemyRosterSettings

## Settings resource for the Enemy Roster plugin.
## Stores project mode, output directory, resource types, and known tags.

enum ProjectMode {
	MODE_2D = 0,
	MODE_3D = 1
}

@export var project_mode: ProjectMode = ProjectMode.MODE_2D
@export var output_directory: String = "res://enemies/"
@export var resource_types: Array[String] = ["money"]
@export var known_tags: Array[String] = []