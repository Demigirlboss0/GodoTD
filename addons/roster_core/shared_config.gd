@tool
extends Resource
class_name SharedConfig

## Shared configuration across all roster plugins.
## Tags and resource types defined here are used by both Enemy and Tower rosters.

signal config_changed

@export var known_tags: Array[String] = []
@export var resource_types: Array[String] = []

const PATH := "res://addons/roster_core/shared_config.tres"
