@tool
extends EditorPlugin
class_name BaseRosterPlugin

## Base EditorPlugin for any roster system.
## Extend this and override get_schema_path() to create TowerRosterPlugin, EnemyRosterPlugin, etc.

signal schema_changed
## Emitted whenever the schema or its dependent data (resource types, output dir, etc.) changes.
## A single unified signal replaces the previous dual-signal noise.

var main_panel: Control
var schema: RosterSchema

func get_schema_path() -> String:
	## Override in subclass
	return ""

func get_panel_title() -> String:
	## Override in subclass
	return "Roster"

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_setup()
	elif what == NOTIFICATION_EXIT_TREE:
		_teardown()

func _setup() -> void:
	_load_schema()
	
	main_panel = preload("res://addons/roster_core/base_roster_panel.tscn").instantiate()
	main_panel.set_plugin(self)
	add_control_to_bottom_panel(main_panel, get_panel_title())

func _teardown() -> void:
	if main_panel:
		if main_panel.has_method("teardown"):
			main_panel.teardown()
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()
		main_panel = null

func _load_schema() -> void:
	var path := get_schema_path()
	if path == "":
		push_error("BaseRosterPlugin: get_schema_path() returned empty string.")
		return
	if FileAccess.file_exists(path):
		schema = load(path) as RosterSchema
	if not schema:
		schema = RosterSchema.new()

func save_schema() -> void:
	var path := get_schema_path()
	if path == "" or not schema:
		return
	var err := ResourceSaver.save(schema, path)
	if err == OK:
		EditorInterface.get_resource_filesystem().update_file(path)
	schema_changed.emit()

func regenerate_data_class() -> void:
	if not schema:
		push_error("BaseRosterPlugin: No schema loaded.")
		return
	var shared := SharedConfig.new()
	if FileAccess.file_exists(SharedConfig.PATH):
		var loaded := load(SharedConfig.PATH) as SharedConfig
		if loaded:
			shared = loaded
	var manager := RosterDataManager.new(schema, shared)
	manager.regenerate_data_class()
	schema_changed.emit()
