@tool
class_name TowerDataManager
extends RefCounted

## Manages tower data file I/O operations.
## Handles listing, loading, saving towers and generating the TowerData class.

var _plugin: EditorPlugin

const DEFAULT_MAX_VALUE := 999999
const SETTINGS_PATH := "res://addons/tower_roster/tower_roster_settings.tres"

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

## Returns the output directory from settings.
func get_output_directory() -> String:
	return _plugin.settings.output_directory if _plugin.settings else "res://towers/"

## Derives a filename from a tower name.
func derive_filename(name: String) -> String:
	var cleaned := "" as String
	for ch in name:
		if ch.is_valid_identifier() or ch == " ":
			cleaned += ch
	var words := cleaned.split(" ") as PackedStringArray
	var title_cased := [] as PackedStringArray
	for word in words:
		if word.length() > 0:
			title_cased.append(word[0].to_upper() + word.substr(1).to_lower())
	return "".join(title_cased) + "TowerData.tres"

## Gets the filename from a resource path.
func get_filename_from_path(path: String) -> String:
	return path.get_file()

## Loads a tower resource from a file path.
func load_tower(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	return load(path)

## Saves a tower resource to a file path.
func save_tower(tower: Resource, path: String) -> bool:
	if not tower:
		return false
	
	var save_result := ResourceSaver.save(tower, path, ResourceSaver.FLAG_SAVE_RUNTIME)
	if save_result == OK:
		EditorInterface.get_resource_filesystem().scan()
		return true
	return false

## Generates the TowerData.gd class file if it doesn't exist.
func ensure_tower_data_class() -> void:
	var class_path := get_output_directory() + "TowerData.gd"
	if not FileAccess.file_exists(class_path):
		_generate_tower_data_class()

## Regenerates the TowerData.gd class file (call after resource type changes).
func regenerate_tower_data_class() -> void:
	_generate_tower_data_class()

func _generate_tower_data_class() -> void:
	var code := "extends Resource\n"
	code += "class_name TowerData\n\n"
	code += "enum AttackStyle { LINEAR, RADIAL }\n"
	code += "enum TargetMode { WHITELIST, BLACKLIST }\n\n"
	code += "@export var tower_name: String = \"\"\n"
	code += "@export var range: float = 10.0\n"
	code += "@export var damage: float = 10.0\n"
	code += "@export var fire_rate: float = 1.0\n"
	code += "@export var pierce: int = 1\n"
	code += "@export var multishot: int = 1\n"
	code += "@export var projectile_scene: PackedScene\n"
	code += "@export var traversal_time: float = 0.0\n"
	code += "@export var attack_style: AttackStyle = AttackStyle.LINEAR\n"
	code += "@export var target_tags: Array[String] = []\n"
	code += "@export var target_mode: TargetMode = TargetMode.WHITELIST\n"
	code += "@export var visuals: Dictionary = {}\n"
	
	for resource_type in _plugin.settings.resource_types:
		var field_name: String = "cost_" + resource_type.to_lower().replace(" ", "_")
		code += "@export var %s: int = 0\n" % field_name
	
	code += "\nconst ATTACK_STYLE_NAMES = {\n"
	code += "\tAttackStyle.LINEAR: \"LINEAR\",\n"
	code += "\tAttackStyle.RADIAL: \"RADIAL\"\n"
	code += "}\n\n"
	code += "const TARGET_MODE_NAMES = {\n"
	code += "\tTargetMode.WHITELIST: \"WHITELIST\",\n"
	code += "\tTargetMode.BLACKLIST: \"BLACKLIST\"\n"
	code += "}\n"
	
	var class_path := get_output_directory() + "TowerData.gd" as String
	var file := FileAccess.open(class_path, FileAccess.WRITE) as FileAccess
	if file:
		file.store_string(code)
		file.close()
		EditorInterface.get_resource_filesystem().scan()

## Creates a new tower instance from the generated TowerData class.
func create_tower_instance() -> Resource:
	var class_path := get_output_directory() + "TowerData.gd" as String
	var tower_class := load(class_path) as Script
	if not tower_class:
		return null
	
	var tower := tower_class.new() as Resource
	return tower

## Returns all tower resources in the output directory.
func get_all_tower_resources() -> Array[Resource]:
	var output_dir := get_output_directory()
	var towers: Array[Resource] = []
	
	var TowerData: Script
	if FileAccess.file_exists(output_dir.path_join("TowerData.gd")):
		TowerData = load(output_dir.path_join("TowerData.gd")) as Script
	
	var dir := DirAccess.open(output_dir) as DirAccess
	if not dir:
		return towers
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "TowerData.tres":
			var full_path := output_dir.path_join(file_name) as String
			var res: Resource = load(full_path) as Resource
			if res:
				if TowerData and res.get_script() == TowerData:
					towers.append(res)
				elif res.get("tower_name"):
					towers.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return towers

## Deletes a tower file by filename.
func delete_tower_file(filename: String) -> bool:
	var output_dir := get_output_directory()
	var file_path := output_dir.path_join(filename)
	
	if not file_path.ends_with(".tres"):
		file_path += ".tres"
	
	if FileAccess.file_exists(file_path):
		var err := DirAccess.remove_absolute(file_path)
		return err == OK
	return false