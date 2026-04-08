@tool
extends EditorPlugin

## Enemy Roster Plugin
## Provides a bottom panel UI for managing enemy data resources for tower defense games.
##
## Features:
## - Create and edit enemy data resources
## - Manage visuals, tags, and rewards
## - Configure project settings (output directory, resource types, known tags)

const SETTINGS_PATH := "res://addons/enemy_roster/enemy_roster_settings.tres"

signal settings_changed
signal resource_types_changed

var main_panel: Control
var settings: EnemyRosterSettings

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_setup()
	elif what == NOTIFICATION_EXIT_TREE:
		_teardown()

func _setup() -> void:
	_load_settings()
	_ensure_output_directory()
	_create_enemy_data_class_if_needed()
	
	main_panel = preload("res://addons/enemy_roster/main_panel.tscn").instantiate()
	main_panel.set_plugin(self)
	add_control_to_bottom_panel(main_panel, "Enemy Roster")

func _teardown() -> void:
	if main_panel:
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()
		main_panel = null

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		settings = load(SETTINGS_PATH) as EnemyRosterSettings
		if not settings:
			settings = _create_default_settings()
	else:
		settings = _create_default_settings()
		ResourceSaver.save(settings, SETTINGS_PATH)

func _create_default_settings() -> EnemyRosterSettings:
	return EnemyRosterSettings.new()

func _ensure_output_directory() -> void:
	if not DirAccess.dir_exists_absolute(settings.output_directory):
		DirAccess.make_dir_recursive_absolute(settings.output_directory)

func _get_enemy_data_class_path() -> String:
	return settings.output_directory + "EnemyData.gd"

func _create_enemy_data_class_if_needed() -> void:
	if not FileAccess.file_exists(_get_enemy_data_class_path()):
		_generate_enemy_data_class()

func _generate_enemy_data_class() -> void:
	var code := "@tool\n"
	code += "extends Resource\n"
	code += "class_name EnemyData\n\n"
	code += "@export var enemy_name: String = \"\"\n"
	code += "@export var max_health: float = 0.0\n"
	code += "@export var speed: float = 0.0\n"
	code += "@export var damage: float = 0.0\n"
	code += "@export var target_tags: Array[String] = []\n"
	code += "@export var visuals: Dictionary = {}\n"
	
	for resource_type in settings.resource_types:
		code += "@export var reward_%s: int = 0\n" % resource_type
	
	var class_path := _get_enemy_data_class_path() as String
	var file := FileAccess.open(class_path, FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()
		EditorInterface.get_resource_filesystem().scan()

func regenerate_enemy_data_class() -> void:
	_generate_enemy_data_class()

func save_settings() -> void:
	ResourceSaver.save(settings, SETTINGS_PATH)
	EditorInterface.get_resource_filesystem().update_file(SETTINGS_PATH)
	settings_changed.emit()
	resource_types_changed.emit()