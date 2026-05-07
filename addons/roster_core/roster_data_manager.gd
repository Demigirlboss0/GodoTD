@tool
extends Node
class_name RosterDataManager

## Unified data manager for roster systems.
## Handles file I/O, class generation, and efficient discovery.

var _schema: RosterSchema

func _init(schema: RosterSchema) -> void:
	_schema = schema
	_ensure_output_directory()
	_ensure_data_class()

## ---------------------------------------------------------------------------
## Directory & File Helpers
## ---------------------------------------------------------------------------

func _ensure_output_directory() -> void:
	if not DirAccess.dir_exists_absolute(_schema.output_directory):
		DirAccess.make_dir_recursive_absolute(_schema.output_directory)

func get_output_directory() -> String:
	return _schema.output_directory

func derive_filename(name: String) -> String:
	var cleaned := ""
	for ch in name:
		if ch.is_valid_identifier() or ch == " ":
			cleaned += ch
	var words := cleaned.split(" ")
	var title_cased: Array[String] = []
	for word in words:
		if word.length() > 0:
			title_cased.append(word[0].to_upper() + word.substr(1).to_lower())
	return "".join(title_cased) + _schema.data_class_name + ".tres"

## Returns just the display names without loading full resources.
func discover_entries() -> Array[Dictionary]:
	## Returns array of { "name": String, "path": String }
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(_schema.output_directory):
		return result
	
	var dir := DirAccess.open(_schema.output_directory)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != _schema.data_class_name + ".tres":
			var full_path := _schema.output_directory.path_join(file_name)
			var display_name := _peek_resource_name(full_path)
			if display_name.is_empty():
				display_name = file_name.get_basename()
			result.append({"name": display_name, "path": full_path})
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

## Reads the first line containing the name field from a .tres file.
func _peek_resource_name(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var name_prop := ""
	if _schema.get_name_property():
		name_prop = _schema.get_name_property().property_name
	else:
		file.close()
		return ""
	
	var search := name_prop + " = "
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with(search):
			file.close()
			return line.substr(search.length()).strip_edges().trim_prefix("\"").trim_suffix("\"")
		## Stop after we've passed the [resource] block and hit the next block or end
		if line.begins_with("[") and not line.begins_with("[resource"):
			break
	file.close()
	return ""

func load_entry(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	return load(path)

func save_entry(entry: Resource, path: String) -> bool:
	if not entry:
		return false
	
	if not _validate_entry(entry):
		return false
	
	var save_result := ResourceSaver.save(entry, path)
	if save_result == OK:
		EditorInterface.get_resource_filesystem().update_file(path)
		return true
	return false

func _validate_entry(entry: Resource) -> bool:
	## Validate base properties against schema types
	for prop in _schema.base_properties:
		var prop_name := prop.property_name
		if not prop_name in entry:
			continue
		var value = entry.get(prop_name)
		if not _is_value_valid_for_type(value, prop.type):
			push_error("Validation failed: property '%s' expected type %s, got %s" % [prop_name, prop.get_gdscript_type(), typeof(value)])
			return false
	
	## Validate dynamic dictionary types
	var key := _schema.dynamic_properties_key
	if key in entry:
		var dict = entry.get(key)
		if dict is Dictionary:
			for rt in _schema.resource_types:
				if dict.has(rt):
					if not (dict[rt] is int or dict[rt] is float):
						push_error("Validation failed: dynamic property '%s' expected numeric, got %s" % [rt, typeof(dict[rt])])
						return false
		else:
			push_error("Validation failed: dynamic properties key '%s' must be a Dictionary" % key)
			return false
	
	return true

func _is_value_valid_for_type(value: Variant, type: RosterProperty.PropertyType) -> bool:
	match type:
		RosterProperty.PropertyType.TYPE_STRING:
			return value is String
		RosterProperty.PropertyType.TYPE_INT:
			return value is int
		RosterProperty.PropertyType.TYPE_FLOAT:
			return value is float or value is int
		RosterProperty.PropertyType.TYPE_BOOL:
			return value is bool
		RosterProperty.PropertyType.TYPE_ENUM:
			return value is int
		RosterProperty.PropertyType.TYPE_PACKED_SCENE:
			return value == null or value is PackedScene
		RosterProperty.PropertyType.TYPE_TAG_ARRAY:
			return value is Array
		RosterProperty.PropertyType.TYPE_DICTIONARY:
			return value is Dictionary
	return true

func delete_entry(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK

## ---------------------------------------------------------------------------
## Data Class Generation
## ---------------------------------------------------------------------------

func _ensure_data_class() -> void:
	if not FileAccess.file_exists(_schema.data_class_script_path):
		_generate_data_class()

func regenerate_data_class() -> void:
	_generate_data_class()

func _generate_data_class() -> void:
	var template_path := "res://addons/roster_core/data_class_template.txt"
	var template := FileAccess.get_file_as_string(template_path)
	
	var result := template.replace("{CLASS_NAME}", _schema.data_class_name)
	result = result.replace("{ENUMS}", _build_enums_string())
	result = result.replace("{BASE_PROPERTIES}", _build_base_properties_string())
	result = result.replace("{DYNAMIC_KEY}", _schema.dynamic_properties_key)
	result = result.replace("{ENUM_NAMES}", _build_enum_names_string())
	
	var file := FileAccess.open(_schema.data_class_script_path, FileAccess.WRITE)
	if file:
		file.store_string(result)
		file.close()

func _build_enums_string() -> String:
	var enums := _collect_enums()
	if enums.is_empty():
		return ""
	var code := ""
	for enum_name in enums.keys():
		code += "enum %s { " % enum_name
		var values: Array[String] = enums[enum_name]
		var i := 0
		for val in values:
			code += "%s = %d" % [val, i]
			if i < values.size() - 1:
				code += ", "
			i += 1
		code += " }\n"
	code += "\n"
	return code

func _build_base_properties_string() -> String:
	var code := ""
	for prop in _schema.base_properties:
		var prop_name := prop.property_name
		var gd_type := prop.get_gdscript_type()
		var default_str := _default_value_string(prop)
		code += "@export var %s: %s = %s\n" % [prop_name, gd_type, default_str]
	return code

func _build_enum_names_string() -> String:
	var enums := _collect_enums()
	if enums.is_empty():
		return ""
	var code := ""
	for enum_name in enums.keys():
		code += "\nconst %s_NAMES = {\n" % enum_name
		var values: Array[String] = enums[enum_name]
		var j := 0
		for val in values:
			code += "\t%s.%s: \"%s\"" % [enum_name, val, val]
			if j < values.size() - 1:
				code += ","
			code += "\n"
			j += 1
		code += "}\n"
	return code

func _collect_enums() -> Dictionary:
	var enums := {}
	for prop in _schema.base_properties:
		if prop.type == RosterProperty.PropertyType.TYPE_ENUM:
			var values: Array[String] = []
			for v in prop.enum_values:
				values.append(str(v))
			enums[prop.enum_name] = values
	return enums

func _default_value_string(prop: RosterProperty) -> String:
	var val = prop.get_default_value_typed()
	match prop.type:
		RosterProperty.PropertyType.TYPE_STRING:
			return "\"" + str(val) + "\""
		RosterProperty.PropertyType.TYPE_PACKED_SCENE:
			return "null"
		RosterProperty.PropertyType.TYPE_TAG_ARRAY, RosterProperty.PropertyType.TYPE_DICTIONARY:
			if val is Array:
				return "[]"
			if val is Dictionary:
				return "{}"
			return str(val)
		_:
			return str(val)

## ---------------------------------------------------------------------------
## Instance Creation
## ---------------------------------------------------------------------------

func create_instance() -> Resource:
	var script := load(_schema.data_class_script_path) as Script
	if not script:
		return null
	return script.new()

## ---------------------------------------------------------------------------
## All Entries (for batch operations like removing resource types)
## ---------------------------------------------------------------------------

func get_all_entries() -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(_schema.output_directory)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != _schema.data_class_name + ".tres":
			var full_path := _schema.output_directory.path_join(file_name)
			var res := load(full_path) as Resource
			if res:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
