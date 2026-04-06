@tool
extends EditorPlugin

var main_panel: Control
var plugin_path: String
var settings

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		plugin_path = get_script().resource_path.get_base_dir()
		settings = _load_settings()
		_ensure_output_directory()
		_ensure_tower_data_class()
		_add_main_panel()
	elif what == NOTIFICATION_EXIT_TREE:
		_remove_main_panel()

func _load_settings():
	var settings_path = plugin_path.path_join("tower_roster_settings.tres")
	
	if FileAccess.file_exists(settings_path):
		var loaded = load(settings_path)
		if loaded:
			return loaded
	
	var TowerRosterSettings = load(plugin_path.path_join("tower_roster_settings.gd"))
	var new_settings = TowerRosterSettings.new()
	
	var dir = DirAccess.open(plugin_path)
	if dir:
		if not dir.dir_exists(plugin_path):
			dir.make_dir(plugin_path)
		ResourceSaver.save(new_settings, settings_path)
	
	return new_settings

func _ensure_output_directory() -> void:
	var out_dir = settings.output_directory
	if not out_dir.begins_with("res://"):
		out_dir = "res://" + out_dir
	
	var dir = DirAccess.open("res://")
	if dir:
		var parts = out_dir.trim_prefix("res://").split("/")
		var current = "res://"
		for part in parts:
			if part.is_empty():
				continue
			current = current.path_join(part)
			if not dir.dir_exists(current):
				dir.make_dir(current)

func _ensure_tower_data_class() -> void:
	var output_dir = settings.output_directory
	if not output_dir.begins_with("res://"):
		output_dir = "res://" + output_dir
	
	var class_path = output_dir.path_join("TowerData.gd")
	
	if not FileAccess.file_exists(class_path):
		_generate_tower_data_class()

func _generate_tower_data_class() -> void:
	var output_dir = settings.output_directory
	if not output_dir.begins_with("res://"):
		output_dir = "res://" + output_dir
	
	var project_mode = settings.project_mode
	var project_mode_str = "2D" if project_mode == 0 else "3D"
	var resource_types = settings.resource_types
	_generate_tower_class(output_dir, resource_types, project_mode_str)

func _generate_tower_class(output_dir: String, resource_types: Array, project_mode: String) -> void:
	var script_path = output_dir.path_join("TowerData.gd")
	
	var cost_fields = ""
	for rt in resource_types:
		var field_name = "cost_" + rt.to_lower().replace(" ", "_")
		cost_fields += "@export var %s: int = 0\n" % field_name
	
	var script_content = """extends Resource
class_name TowerData

enum AttackStyle {
\tLINEAR,
\tRADIAL
}

enum TargetMode {
\tWHITELIST,
\tBLACKLIST
}

@export var tower_name: String = ""
@export var range: float = 10.0
@export var damage: float = 10.0
@export var fire_rate: float = 1.0
@export var pierce: int = 1
@export var multishot: int = 1
@export var projectile_scene: PackedScene
@export var traversal_time: float = 0.0
@export var attack_style: AttackStyle = AttackStyle.LINEAR
@export var target_tags: Array[String] = []
@export var target_mode: TargetMode = TargetMode.WHITELIST
@export var visuals: Dictionary = {}

%s
const ATTACK_STYLE_NAMES = {
\tAttackStyle.LINEAR: "LINEAR",
\tAttackStyle.RADIAL: "RADIAL"
}

const TARGET_MODE_NAMES = {
\tTargetMode.WHITELIST: "WHITELIST",
\tTargetMode.BLACKLIST: "BLACKLIST"
}
""" % cost_fields
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()

func _add_main_panel() -> void:
	main_panel = preload("res://addons/tower_roster/main_panel.tscn").instantiate()
	main_panel.set("plugin", self)
	main_panel.set("settings", settings)
	add_control_to_bottom_panel(main_panel, "Tower Roster")

func _remove_main_panel() -> void:
	if main_panel and is_instance_valid(main_panel):
		remove_control_from_bottom_panel(main_panel)
		main_panel.queue_free()
		main_panel = null

func save_settings() -> void:
	var settings_path = plugin_path.path_join("tower_roster_settings.tres")
	ResourceSaver.save(settings, settings_path)

func get_output_directory() -> String:
	var out_dir = settings.output_directory
	if not out_dir.begins_with("res://"):
		out_dir = "res://" + out_dir
	return out_dir

func get_all_tower_resources():
	var output_dir = get_output_directory()
	var towers = []
	var TowerData = load(output_dir.path_join("TowerData.gd"))
	
	var dir = DirAccess.open(output_dir)
	if dir == null:
		return towers
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not file_name.begins_with(".") and file_name.ends_with(".tres"):
			if file_name != "TowerData.gd" and file_name != "TowerData.tres":
				var full_path = output_dir.path_join(file_name)
				var res = load(full_path)
				if res and res is Resource:
					if TowerData and res.get_script() == TowerData:
						towers.append(res)
					elif res.get("tower_name") != null:
						towers.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return towers

func save_tower(tower, filename: String) -> bool:
	var output_dir = get_output_directory()
	var file_path = output_dir.path_join(filename)
	
	if not filename.ends_with(".tres"):
		file_path += ".tres"
	
	ResourceSaver.save(tower, file_path)
	return true

func delete_tower_file(filename: String) -> bool:
	var output_dir = get_output_directory()
	var file_path = output_dir.path_join(filename)
	
	if not file_path.ends_with(".tres"):
		file_path += ".tres"
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false

func regenerate_tower_data_class() -> void:
	_ensure_output_directory()
	_generate_tower_data_class()