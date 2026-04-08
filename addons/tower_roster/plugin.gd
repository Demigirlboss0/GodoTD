@tool
extends EditorPlugin

const SETTINGS_PATH := "res://addons/tower_roster/tower_roster_settings.tres"

signal settings_changed
signal resource_types_changed

var main_panel: Control
var settings: TowerRosterSettings

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_setup()
	elif what == NOTIFICATION_EXIT_TREE:
		_teardown()

func _setup() -> void:
	_load_settings()
	_ensure_output_directory()
	_data_manager().ensure_tower_data_class()
	
	main_panel = preload("res://addons/tower_roster/main_panel.tscn").instantiate()
	main_panel.set_plugin(self)
	add_control_to_bottom_panel(main_panel, "Tower Roster")

func _teardown() -> void:
	if main_panel:
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()
		main_panel = null

func _data_manager() -> TowerDataManager:
	return TowerDataManager.new(self)

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		settings = load(SETTINGS_PATH) as TowerRosterSettings
		if not settings:
			settings = _create_default_settings()
	else:
		settings = _create_default_settings()
		ResourceSaver.save(settings, SETTINGS_PATH)

func _create_default_settings() -> TowerRosterSettings:
	return TowerRosterSettings.new()

func _ensure_output_directory() -> void:
	if not DirAccess.dir_exists_absolute(settings.output_directory):
		DirAccess.make_dir_recursive_absolute(settings.output_directory)

func regenerate_tower_data_class() -> void:
	_data_manager().regenerate_tower_data_class()
	resource_types_changed.emit()

func save_settings() -> void:
	ResourceSaver.save(settings, SETTINGS_PATH)
	EditorInterface.get_resource_filesystem().update_file(SETTINGS_PATH)
	settings_changed.emit()