@tool
class_name EnemyDataManager
extends RefCounted

## Manages enemy data file I/O operations.
## Handles listing, loading, saving enemies and generating the EnemyData class.

var _plugin: EditorPlugin

const DEFAULT_MAX_VALUE := 999999
const SETTINGS_PATH := "res://addons/enemy_roster/enemy_roster_settings.tres"

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

## Returns the output directory from settings.
func get_output_directory() -> String:
	return _plugin.settings.output_directory if _plugin.settings else "res://enemies/"

## Validates that the output directory path is valid.
func validate_output_directory(path: String) -> bool:
	if path == "":
		return false
	if not path.begins_with("res://"):
		return false
	return true

## Refreshes the enemy list in the UI.
func refresh_enemy_list(enemy_list: ItemList) -> void:
	if not enemy_list:
		return
	
	enemy_list.clear()
	if not _plugin or not _plugin.settings:
		return
	
	var dir := DirAccess.open(_plugin.settings.output_directory) as DirAccess
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "EnemyData.tres":
			var path := (_plugin.settings.output_directory + file_name) as String
			var res := load(path) as Resource
			if res and "enemy_name" in res:
				var idx := enemy_list.add_item(res.enemy_name) as int
				enemy_list.set_item_metadata(idx, path)
		file_name = dir.get_next()
	dir.list_dir_end()

## Derives a filename from an enemy name.
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
	return "".join(title_cased) + "EnemyData.tres"

## Gets the filename from a resource path.
func get_filename_from_path(path: String) -> String:
	return path.get_file()

## Loads an enemy resource from a file path.
func load_enemy(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	return load(path)

## Saves an enemy resource to a file path.
func save_enemy(enemy: Resource, path: String) -> bool:
	if not enemy:
		return false
	
	var save_result := ResourceSaver.save(enemy, path, ResourceSaver.FLAG_SAVE_RUNTIME)
	if save_result == OK:
		EditorInterface.get_resource_filesystem().scan()
		return true
	return false

## Generates the EnemyData.gd class file if it doesn't exist.
func ensure_enemy_data_class() -> void:
	var class_path := get_output_directory() + "EnemyData.gd"
	if not FileAccess.file_exists(class_path):
		_generate_enemy_data_class()

## Regenerates the EnemyData.gd class file (call after resource type changes).
func regenerate_enemy_data_class() -> void:
	_generate_enemy_data_class()

func _generate_enemy_data_class() -> void:
	var code := "@tool\n"
	code += "extends Resource\n"
	code += "class_name EnemyData\n\n"
	code += "@export var enemy_name: String = \"\"\n"
	code += "@export var max_health: float = 100.0\n"
	code += "@export var speed: float = 100.0\n"
	code += "@export var damage: float = 1.0\n"
	code += "@export var target_tags: Array[String] = []\n"
	code += "@export var visuals: Dictionary = {}\n"
	
	for resource_type in _plugin.settings.resource_types:
		code += "@export var reward_%s: int = 0\n" % resource_type
	
	var class_path := get_output_directory() + "EnemyData.gd" as String
	var file := FileAccess.open(class_path, FileAccess.WRITE) as FileAccess
	if file:
		file.store_string(code)
		file.close()
		EditorInterface.get_resource_filesystem().scan()

## Creates a new enemy instance from the generated EnemyData class.
func create_enemy_instance() -> Resource:
	var class_path := get_output_directory() + "EnemyData.gd" as String
	var enemy_class := load(class_path) as Script
	if not enemy_class:
		return null
	
	var enemy := enemy_class.new() as Resource
	return enemy