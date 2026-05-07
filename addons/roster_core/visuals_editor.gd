@tool
extends VBoxContainer
class_name VisualsEditor

## Self-contained editor for dictionary-based visual resources.
## Used by BaseRosterPanel for TYPE_DICTIONARY properties.

signal visuals_changed

var _entries: Dictionary = {}  ## id -> { "key_edit": LineEdit, "value": Variant }
var _next_id: int = 0
var _project_mode: int = 0
var _scale: float = 1.0

var _list: VBoxContainer
var _add_btn: Button


func _ready() -> void:
	_list = VBoxContainer.new()
	_list.name = "VisualsList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)

	_add_btn = Button.new()
	_add_btn.text = "Add Visual"
	_add_btn.pressed.connect(_on_add_pressed)
	add_child(_add_btn)


func set_project_mode(mode: int) -> void:
	_project_mode = mode


func set_editor_scale(scale: float) -> void:
	_scale = scale


func load_visuals(visuals: Dictionary) -> void:
	clear_visuals()
	for key in visuals:
		_add_entry(key, visuals[key])


func clear_visuals() -> void:
	_entries.clear()
	_next_id = 0
	if _list:
		for child in _list.get_children():
			child.queue_free()


func gather_visuals() -> Dictionary:
	var result := {}
	for id in _entries:
		var data: Dictionary = _entries[id]
		var key := (data["key_edit"] as LineEdit).text.strip_edges()
		var value: Variant = data["value"]
		if key != "" and value:
			result[key] = value
	return result


func _on_add_pressed() -> void:
	_add_entry("", null)


func _add_entry(key: String, value: Variant) -> void:
	var container := HBoxContainer.new()
	_list.add_child(container)

	var key_edit := LineEdit.new()
	key_edit.placeholder_text = "Key (e.g. idle)"
	key_edit.text = key
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(key_edit)

	var id := _next_id
	_next_id += 1
	_entries[id] = {"key_edit": key_edit, "value": value}

	var select_btn := Button.new()
	select_btn.text = _get_resource_name(value)
	select_btn.pressed.connect(func(): _show_resource_picker(id, select_btn))
	container.add_child(select_btn)

	var remove_btn := Button.new()
	remove_btn.flat = true
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		_entries.erase(id)
		container.queue_free()
		visuals_changed.emit()
	)
	container.add_child(remove_btn)


func _get_resource_name(res: Variant) -> String:
	if res and typeof(res) == TYPE_OBJECT and "resource_path" in res:
		var path := res.resource_path as String
		if path:
			return path.get_file()
	return "Select..."


func _show_resource_picker(entry_id: int, btn: Button) -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	if _project_mode == 0:
		dialog.filters = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.tres"]
	else:
		dialog.filters = ["*.tres", "*.obj", "*.gltf", "*.glb"]

	EditorInterface.get_base_control().add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var res: Resource = load(path)
		_entries[entry_id]["value"] = res
		btn.text = path.get_file()
		dialog.queue_free()
		visuals_changed.emit()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(int(800 * _scale), int(600 * _scale)))
