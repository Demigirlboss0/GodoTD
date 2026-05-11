@tool
extends Control

## Base panel for any roster system. Reads a RosterSchema to build the UI dynamically.

signal request_refresh_list

var _plugin: EditorPlugin
var _schema: RosterSchema
var _shared_config: SharedConfig
var _manager: RosterDataManager
var _theme: Theme
var _scale: float = 1.0

## State
var current_entry: Resource = null
var current_entry_path: String = ""
var is_new_entry: bool = false
var _dirty: bool = false
var _loading_entry: bool = false

## Pending changes for reference-type properties (e.g. PackedScene).
## UI writes here instead of mutating current_entry, so Discard can revert.
var _pending_changes: Dictionary = {}

## Node references (unique names)
var entry_list: ItemList
var search_edit: LineEdit
var form_container: VBoxContainer
var add_button: Button
var delete_button: Button
var save_button: Button
var settings_button: Button

## Active settings container (null when modal is closed)
var _settings_container: VBoxContainer = null

## Property control mapping: property_name -> Control
var _prop_controls: Dictionary = {}



## Status label reference
var _status_label: Label = null
var _status_tween: Tween = null

## Deferred initialization flag
var _initialized: bool = false
var _pending_plugin: EditorPlugin = null

const DEFAULT_MAX_VALUE := 999999
const LABEL_WIDTH := 120


## ============================================================================
## INITIALIZATION
## ============================================================================

func set_plugin(plugin: EditorPlugin) -> void:
	_pending_plugin = plugin
	if is_inside_tree():
		_initialize()
	else:
		tree_entered.connect(_initialize, CONNECT_ONE_SHOT)

func _initialize() -> void:
	if _initialized:
		return
	if not _pending_plugin:
		return
	_initialized = true
	_plugin = _pending_plugin
	_pending_plugin = null
	
	_theme = EditorInterface.get_editor_theme()
	_scale = EditorInterface.get_editor_scale()
	
	## Grab unique named nodes
	entry_list = %EntryList
	search_edit = %SearchEdit
	form_container = %FormContainer
	add_button = %AddButton
	delete_button = %DeleteButton
	save_button = %SaveButton
	settings_button = %SettingsButton
	
	add_button.pressed.connect(_on_add_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	save_button.pressed.connect(_on_save_pressed)
	settings_button.pressed.connect(_show_settings_modal)
	entry_list.item_selected.connect(_on_entry_selected)
	entry_list.gui_input.connect(_on_list_input)
	search_edit.text_changed.connect(_on_search_changed)
	gui_input.connect(_on_gui_input)
	
	_schema = _plugin.schema
	_shared_config = SharedConfig.new()
	if FileAccess.file_exists(SharedConfig.PATH):
		var loaded := load(SharedConfig.PATH) as SharedConfig
		if loaded:
			_shared_config = loaded
	_manager = RosterDataManager.new(_schema, _shared_config)
	
	_shared_config.config_changed.connect(_on_shared_config_changed)
	_plugin.schema_changed.connect(_on_settings_changed)
	
	_apply_theme_to_tree(self)
	_build_form()
	_refresh_entry_list()
	
	add_button.tooltip_text = "Add new (Ctrl+N)"
	delete_button.tooltip_text = "Delete selected (Del)"
	save_button.tooltip_text = "Save"
	settings_button.tooltip_text = "Settings"
	
	## Icon-only toolbar buttons
	_add_button_icon(add_button, "Add")
	_add_button_icon(delete_button, "Remove")
	_add_button_icon(settings_button, "Tools")

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_teardown()

func teardown() -> void:
	_teardown()

func _teardown() -> void:
	if _plugin:
		if _plugin.schema_changed.is_connected(_on_settings_changed):
			_plugin.schema_changed.disconnect(_on_settings_changed)
	if _shared_config and _shared_config.config_changed.is_connected(_on_shared_config_changed):
		_shared_config.config_changed.disconnect(_on_shared_config_changed)
	_manager = null

func _add_button_icon(btn: Button, icon_name: String) -> void:
	if _theme:
		var icon = _theme.get_icon(icon_name, "EditorIcons")
		if icon:
			btn.icon = icon
			btn.text = ""

func _apply_theme_to_tree(node: Control) -> void:
	if _theme == null:
		return
	if node is Button:
		node.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))
	if node is LineEdit or node is SpinBox or node is OptionButton:
		node.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))
	if node is PanelContainer:
		var sb := StyleBoxFlat.new()
		sb.bg_color = _theme.get_color("base_color", "Editor")
		node.add_theme_stylebox_override("panel", sb)
	for child in node.get_children():
		if child is Control:
			_apply_theme_to_tree(child)


## ============================================================================
## FORM CONSTRUCTION
## ============================================================================

func _build_form() -> void:
	if not form_container:
		return
	for child in form_container.get_children():
		child.queue_free()
	_prop_controls.clear()
	
	var categories := _schema.get_categories()
	for cat in categories:
		_add_form_section(cat)
	
	## Dynamic properties section (Costs / Rewards)
	_add_dynamic_section()
	_refresh_dynamic_list()
	
	## Status label
	_status_label = Label.new()
	_status_label.visible = false
	_status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	form_container.add_child(_status_label)

func _add_form_section(category: String) -> void:
	if not form_container:
		return
	
	var section := VBoxContainer.new()
	section.name = "Section_" + category
	section.add_theme_constant_override("separation", 8)
	form_container.add_child(section)
	
	var header_btn := Button.new()
	header_btn.text = "▼ " + category
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _theme:
		header_btn.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
		header_btn.add_theme_color_override("font_color", _theme.get_color("accent_color", "Editor"))
	section.add_child(header_btn)
	
	var rows_container := VBoxContainer.new()
	rows_container.name = "Rows"
	rows_container.add_theme_constant_override("separation", 8)
	section.add_child(rows_container)
	
	for prop in _schema.get_properties_by_category(category):
		var row := _make_property_row(prop)
		rows_container.add_child(row)
	
	header_btn.pressed.connect(func():
		rows_container.visible = not rows_container.visible
		header_btn.text = ("▼ " if rows_container.visible else "▶ ") + category
	)

func _add_dynamic_section() -> void:
	if not form_container:
		return
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	form_container.add_child(spacer)
	
	var section := VBoxContainer.new()
	section.name = "Section_Dynamic"
	section.add_theme_constant_override("separation", 8)
	form_container.add_child(section)
	
	var header_btn := Button.new()
	header_btn.text = "▼ " + _schema.dynamic_properties_label
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _theme:
		header_btn.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
		header_btn.add_theme_color_override("font_color", _theme.get_color("accent_color", "Editor"))
	section.add_child(header_btn)
	
	var container := VBoxContainer.new()
	container.name = "DynamicPropertiesContainer"
	section.add_child(container)
	_prop_controls["__dynamic_container"] = container
	
	header_btn.pressed.connect(func():
		container.visible = not container.visible
		header_btn.text = ("▼ " if container.visible else "▶ ") + _schema.dynamic_properties_label
	)

func _make_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	if _theme:
		label.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
		label.add_theme_color_override("font_color", _theme.get_color("accent_color", "Editor"))
	return label

func _make_property_row(prop: RosterProperty) -> Control:
	var prop_name := prop.property_name
	var type := prop.type
	var label_text := prop.get_display_label()
	
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = int(LABEL_WIDTH * _scale)
	row.add_child(label)
	
	var input: Control
	match type:
		RosterProperty.PropertyType.TYPE_STRING:
			input = LineEdit.new()
			input.placeholder_text = "Enter " + prop_name
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			input.text_changed.connect(func(_text): _mark_dirty())
		RosterProperty.PropertyType.TYPE_FLOAT, RosterProperty.PropertyType.TYPE_INT:
			input = SpinBox.new()
			input.min_value = -DEFAULT_MAX_VALUE
			input.max_value = DEFAULT_MAX_VALUE
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if type == RosterProperty.PropertyType.TYPE_FLOAT:
				input.step = 0.1
			else:
				input.rounded = true
			input.value_changed.connect(func(_value): _mark_dirty())
		RosterProperty.PropertyType.TYPE_BOOL:
			input = CheckBox.new()
			input.toggled.connect(func(_pressed): _mark_dirty())
		RosterProperty.PropertyType.TYPE_ENUM:
			input = OptionButton.new()
			for val in prop.enum_values:
				input.add_item(str(val))
			input.item_selected.connect(func(_idx): _mark_dirty())
		RosterProperty.PropertyType.TYPE_PACKED_SCENE:
			input = Button.new()
			input.text = "Select..."
			input.pressed.connect(func(): _on_scene_picker_pressed(prop_name, input))
		RosterProperty.PropertyType.TYPE_DICTIONARY:
			input = preload("res://addons/roster_core/visuals_editor.tscn").instantiate()
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if input is VisualsEditor:
				input.set_project_mode(_schema.project_mode)
				input.set_editor_scale(_scale)
				input.visuals_changed.connect(_mark_dirty)
		RosterProperty.PropertyType.TYPE_TAG_ARRAY:
			input = preload("res://addons/roster_core/tags_editor.tscn").instantiate()
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if input is TagsEditor:
				input.set_editor_scale(_scale)
				input.set_known_tags(_shared_config.known_tags)
				input.tag_added.connect(_on_editor_tag_added)
				input.tag_added.connect(func(_tag): _mark_dirty())
				input.tag_removed.connect(func(_tag): _mark_dirty())
		_:
			input = LineEdit.new()
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if type != RosterProperty.PropertyType.TYPE_DICTIONARY and type != RosterProperty.PropertyType.TYPE_TAG_ARRAY:
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_prop_controls[prop_name] = input
	row.add_child(input)
	return row


## ============================================================================
## SETTINGS CONSTRUCTION
## ============================================================================

func _show_settings_modal() -> void:
	var window := Window.new()
	window.title = _schema.roster_name + " Settings"
	window.transient = true
	window.size = Vector2i(int(340 * _scale), int(380 * _scale))
	EditorInterface.get_base_control().add_child(window)
	window.popup()
	_center_window(window)
	
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.theme = _theme
	window.add_child(panel)
	
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)
	
	_settings_container = vbox
	_build_settings_into(vbox)
	_apply_theme_to_tree(panel)
	
	window.close_requested.connect(func():
		_settings_container = null
		window.queue_free()
	)

func _build_settings_into(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	var mode_option := OptionButton.new()
	mode_option.add_item("2D", 0)
	mode_option.add_item("3D", 1)
	mode_option.selected = _schema.project_mode
	mode_option.item_selected.connect(func(idx: int):
		_schema.project_mode = idx
		_plugin.save_schema()
	)
	container.add_child(_make_simple_row("Mode:", mode_option))
	
	var output_edit := LineEdit.new()
	output_edit.text = _schema.output_directory
	output_edit.text_changed.connect(_on_output_dir_changed)
	container.add_child(_make_simple_row("Output:", output_edit))
	
	var error_label := Label.new()
	error_label.name = "OutputError"
	error_label.modulate = Color(1, 0.3, 0.3)
	error_label.visible = false
	container.add_child(error_label)
	_update_output_error()
	
	container.add_child(_make_spacer_small())
	container.add_child(_make_section_header("Resource Types"))
	
	var rt_list := VBoxContainer.new()
	rt_list.name = "RTList"
	container.add_child(rt_list)
	_populate_resource_types(rt_list)
	
	var add_rt_btn := Button.new()
	add_rt_btn.text = "+ Add"
	add_rt_btn.pressed.connect(_show_add_resource_type_dialog)
	container.add_child(add_rt_btn)
	
	container.add_child(_make_spacer_small())
	container.add_child(_make_section_header("Known Tags"))
	
	var tags_list := VBoxContainer.new()
	tags_list.name = "TagsListSettings"
	container.add_child(tags_list)
	_populate_known_tags(tags_list)
	
	var add_tag_btn := Button.new()
	add_tag_btn.text = "+ Add"
	add_tag_btn.pressed.connect(_show_add_tag_dialog)
	container.add_child(add_tag_btn)

func _make_simple_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = int(LABEL_WIDTH * _scale)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _make_spacer_small() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	return spacer

func _update_output_error() -> void:
	if not _settings_container:
		return
	var error_label := _settings_container.get_node_or_null("OutputError") as Label
	if error_label:
		var valid := _validate_output_dir(_schema.output_directory)
		error_label.visible = not valid
		error_label.text = "Invalid path. Must start with 'res://'" if not valid else ""

func _validate_output_dir(path: String) -> bool:
	return path != "" and path.begins_with("res://")


## ============================================================================
## DATA BINDING: Load Resource -> UI
## ============================================================================

func _load_entry_to_form(entry: Resource) -> void:
	if not entry:
		_clear_form()
		return
	
	_loading_entry = true
	for prop in _schema.base_properties:
		var prop_name := prop.property_name
		var type := prop.type
		var control = _prop_controls.get(prop_name)
		if not control:
			continue
		
		var value = entry.get(prop_name) if prop_name in entry else prop.get_default_value_typed()
		_match_control_value(control, type, value)
	
	## Build dynamic controls first, then load values
	_refresh_dynamic_list()
	_load_dynamic_properties(entry)
	
	_loading_entry = false
	_dirty = false
	_pending_changes.clear()

func _match_control_value(control: Control, type: RosterProperty.PropertyType, value: Variant) -> void:
	match type:
		RosterProperty.PropertyType.TYPE_STRING:
			if control is LineEdit:
				control.text = str(value)
		RosterProperty.PropertyType.TYPE_FLOAT, RosterProperty.PropertyType.TYPE_INT:
			if control is SpinBox:
				control.value = float(value) if value != null else 0.0
		RosterProperty.PropertyType.TYPE_BOOL:
			if control is CheckBox:
				control.button_pressed = bool(value)
		RosterProperty.PropertyType.TYPE_ENUM:
			if control is OptionButton:
				control.selected = int(value)
		RosterProperty.PropertyType.TYPE_PACKED_SCENE:
			if control is Button:
				if value and value is PackedScene:
					control.text = value.resource_path.get_file()
				else:
					control.text = "Select..."
		RosterProperty.PropertyType.TYPE_DICTIONARY:
			if control is VisualsEditor:
				control.load_visuals(value as Dictionary)
		RosterProperty.PropertyType.TYPE_TAG_ARRAY:
			if control is TagsEditor:
				control.load_tags(value as Array)

func _clear_form() -> void:
	for prop in _schema.base_properties:
		var prop_name := prop.property_name
		var type := prop.type
		var control = _prop_controls.get(prop_name)
		if not control:
			continue
		_match_control_value(control, type, prop.get_default_value_typed())
	
	_clear_dynamic()
	_refresh_dynamic_list()
	_pending_changes.clear()


## ============================================================================
## DYNAMIC PROPERTIES (Costs / Rewards)
## ============================================================================

func _load_dynamic_properties(entry: Resource) -> void:
	var key := _schema.dynamic_properties_key
	var dict: Dictionary = entry.get(key) if entry and key in entry else {}
	for rt in _shared_config.resource_types:
		var val = dict.get(rt, 0)
		var control = _prop_controls.get("__dyn_" + rt)
		if control is SpinBox:
			control.value = int(val)

func _refresh_dynamic_list() -> void:
	var container = _prop_controls.get("__dynamic_container")
	if not container is VBoxContainer:
		return
	
	for child in container.get_children():
		child.queue_free()
	
	for key in _prop_controls.keys():
		if key is String and key.begins_with("__dyn_"):
			_prop_controls.erase(key)
	
	for rt in _shared_config.resource_types:
		var captured_rt := rt
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = rt.capitalize() + ":"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = DEFAULT_MAX_VALUE
		spin.rounded = true
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_value): _mark_dirty())
		row.add_child(spin)
		_prop_controls["__dyn_" + rt] = spin
		
		var remove_btn := Button.new()
		remove_btn.flat = true
		remove_btn.text = "X"
		remove_btn.pressed.connect(func(): _show_remove_resource_type_dialog(captured_rt))
		row.add_child(remove_btn)
		
		container.add_child(row)

func _clear_dynamic() -> void:
	var container = _prop_controls.get("__dynamic_container")
	if container is VBoxContainer:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for rt in _shared_config.resource_types:
		_prop_controls.erase("__dyn_" + rt)


## ============================================================================
## DIRTY STATE
## ============================================================================

func _mark_dirty() -> void:
	if _loading_entry:
		return
	_dirty = true

## ============================================================================
## TAG EDITOR CALLBACK
## ============================================================================

func _on_editor_tag_added(tag: String) -> void:
	if not tag in _shared_config.known_tags:
		_shared_config.known_tags.append(tag)
		save_shared_config()
		_rebuild_settings_tags()
	for control in _prop_controls.values():
		if control is TagsEditor:
			control.set_known_tags(_shared_config.known_tags)


## ============================================================================
## SCENE PICKER
## ============================================================================

func _on_scene_picker_pressed(prop_name: String, btn: Button) -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = ["*.tscn"]
	EditorInterface.get_base_control().add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		_pending_changes[prop_name] = load(path)
		btn.text = path.get_file()
		_mark_dirty()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(int(800 * _scale), int(600 * _scale)))


## ============================================================================
## SAVE: UI -> Resource
## ============================================================================

func _on_save_pressed() -> void:
	_save_current_entry()

func _save_current_entry() -> void:
	var name_prop := _schema.get_name_property()
	var name_control = _prop_controls.get(name_prop.property_name) if name_prop else null
	var display_name := ""
	if name_control is LineEdit:
		display_name = name_control.text.strip_edges()
	
	if display_name == "":
		_show_message("Please enter a name.")
		return
	
	var path := ""
	if not is_new_entry and current_entry_path != "":
		path = current_entry_path
	else:
		var filename := _manager.derive_filename(display_name)
		if not filename.ends_with(".tres"):
			filename += ".tres"
		path = _schema.output_directory.path_join(filename)
	
	if not _validate_output_dir(_schema.output_directory):
		_show_message("Invalid output directory.")
		return
	
	if FileAccess.file_exists(path) and is_new_entry:
		_show_overwrite_confirmation(path, display_name)
	else:
		_do_save(path, display_name)

func _do_save(path: String, display_name: String) -> void:
	var entry := _manager.create_instance()
	if not entry:
		_show_message("Failed to create instance. Check generated class.")
		return
	
	## Set base properties
	for prop in _schema.base_properties:
		var prop_name := prop.property_name
		var type := prop.type
		var control = _prop_controls.get(prop_name)
		if not control:
			continue
		
		match type:
			RosterProperty.PropertyType.TYPE_STRING:
				if control is LineEdit:
					entry.set(prop_name, control.text)
			RosterProperty.PropertyType.TYPE_FLOAT:
				if control is SpinBox:
					entry.set(prop_name, control.value)
			RosterProperty.PropertyType.TYPE_INT:
				if control is SpinBox:
					entry.set(prop_name, int(control.value))
			RosterProperty.PropertyType.TYPE_BOOL:
				if control is CheckBox:
					entry.set(prop_name, control.button_pressed)
			RosterProperty.PropertyType.TYPE_ENUM:
				if control is OptionButton:
					entry.set(prop_name, control.selected)
			RosterProperty.PropertyType.TYPE_PACKED_SCENE:
				if prop_name in _pending_changes:
					entry.set(prop_name, _pending_changes[prop_name])
				elif current_entry and prop_name in current_entry:
					entry.set(prop_name, current_entry.get(prop_name))
			RosterProperty.PropertyType.TYPE_DICTIONARY:
				if control is VisualsEditor:
					entry.set(prop_name, control.gather_visuals())
			RosterProperty.PropertyType.TYPE_TAG_ARRAY:
				if control is TagsEditor:
					entry.set(prop_name, control.gather_tags())
	
	## Set dynamic properties (Dictionary)
	var dynamic_dict := {}
	for rt in _shared_config.resource_types:
		var control = _prop_controls.get("__dyn_" + rt)
		if control is SpinBox:
			dynamic_dict[rt] = int(control.value)
	entry.set(_schema.dynamic_properties_key, dynamic_dict)
	
	if _manager.save_entry(entry, path):
		current_entry = entry
		current_entry_path = path
		is_new_entry = false
		_dirty = false
		_pending_changes.clear()
		_refresh_entry_list()
		_show_status("Saved successfully!")
	else:
		_show_message("Failed to save.")

## ============================================================================
## LIST & SELECTION
## ============================================================================

func _refresh_entry_list() -> void:
	if not entry_list:
		return
	entry_list.clear()
	var filter := ""
	if search_edit:
		filter = search_edit.text.strip_edges().to_lower()
	var entries := _manager.discover_entries()
	for e in entries:
		if filter == "" or e["name"].to_lower().contains(filter):
			var idx := entry_list.add_item(e["name"])
			entry_list.set_item_metadata(idx, e["path"])

func _on_entry_selected(index: int) -> void:
	var path: String = entry_list.get_item_metadata(index)
	if path == "":
		return
	
	var proceed := func():
		if not FileAccess.file_exists(path):
			_show_message("File not found. It may have been deleted.")
			_refresh_entry_list()
			return
		
		var entry := _manager.load_entry(path)
		if not entry:
			_show_message("Failed to load resource.")
			return
		
		current_entry = entry
		current_entry_path = path
		is_new_entry = false
		_load_entry_to_form(entry)
	
	if _dirty:
		_show_confirm_dialog(
			"Unsaved Changes",
			"You have unsaved changes. Discard them?",
			proceed
		)
	else:
		proceed.call()

func _on_add_pressed() -> void:
	if _dirty:
		_show_confirm_dialog(
			"Unsaved Changes",
			"You have unsaved changes. Discard them?",
			func():
				current_entry = null
				current_entry_path = ""
				is_new_entry = true
				_clear_form()
		)
		return
	current_entry = null
	current_entry_path = ""
	is_new_entry = true
	_clear_form()

func _on_delete_pressed() -> void:
	_attempt_delete_entry()

func _attempt_delete_entry() -> void:
	var selected := entry_list.get_selected_items()
	if selected.size() == 0:
		return
	var idx := selected[0]
	var path: String = entry_list.get_item_metadata(idx)
	var name_text := entry_list.get_item_text(idx)
	_show_confirm_dialog(
		"Delete " + _schema.roster_name,
		"Delete \"%s\"? This cannot be undone." % name_text,
		func():
			if _manager.delete_entry(path):
				_clear_form()
				current_entry = null
				is_new_entry = true
				_refresh_entry_list()
				_show_status("Deleted.")
			else:
				_show_message("Failed to delete.")
	)


## ============================================================================
## KEYBOARD SHORTCUTS
## ============================================================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.ctrl_or_meta:
			match key_event.keycode:
				KEY_S:
					_on_save_pressed()
					accept_event()
				KEY_N:
					_on_add_pressed()
					accept_event()

func _on_list_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_DELETE:
			_attempt_delete_entry()

func _on_search_changed(_text: String) -> void:
	_refresh_entry_list()


## ============================================================================
## SETTINGS EVENTS
## ============================================================================

func _on_settings_changed() -> void:
	_refresh_entry_list()
	_refresh_dynamic_list()
	_rebuild_settings_rt()
	_rebuild_settings_tags()
	_update_output_error()
	for control in _prop_controls.values():
		if control is VisualsEditor:
			control.set_project_mode(_schema.project_mode)
		if control is TagsEditor:
			control.set_known_tags(_shared_config.known_tags)

func _on_output_dir_changed(text: String) -> void:
	if _validate_output_dir(text):
		_schema.output_directory = text
		_plugin.save_schema()
		_manager._ensure_output_directory()
	_update_output_error()

func save_shared_config() -> void:
	ResourceSaver.save(_shared_config, SharedConfig.PATH)
	EditorInterface.get_resource_filesystem().update_file(SharedConfig.PATH)
	_shared_config.config_changed.emit()

func _on_shared_config_changed() -> void:
	_rebuild_settings_rt()
	_rebuild_settings_tags()
	_refresh_dynamic_list()
	for control in _prop_controls.values():
		if control is TagsEditor:
			control.set_known_tags(_shared_config.known_tags)


## ============================================================================
## SETTINGS UI POPULATORS
## ============================================================================

func _populate_resource_types(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for rt in _shared_config.resource_types:
		var captured_rt := rt
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = rt
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove_btn := Button.new()
		remove_btn.flat = true
		remove_btn.text = "X"
		remove_btn.pressed.connect(func(): _show_remove_resource_type_dialog(captured_rt))
		row.add_child(remove_btn)
		container.add_child(row)

func _populate_known_tags(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for tag in _shared_config.known_tags:
		var captured_tag := tag
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = tag
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove_btn := Button.new()
		remove_btn.flat = true
		remove_btn.text = "X"
		remove_btn.pressed.connect(func():
			_shared_config.known_tags.erase(captured_tag)
			save_shared_config()
		)
		row.add_child(remove_btn)
		container.add_child(row)

func _rebuild_settings_rt() -> void:
	if not _settings_container:
		return
	var list = _settings_container.get_node_or_null("RTList")
	if list is VBoxContainer:
		_populate_resource_types(list)

func _rebuild_settings_tags() -> void:
	if not _settings_container:
		return
	var list = _settings_container.get_node_or_null("TagsListSettings")
	if list is VBoxContainer:
		_populate_known_tags(list)


## ============================================================================
## STATUS & DIALOG HELPERS
## ============================================================================

func _show_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
		_status_label.visible = true
		if _status_tween and _status_tween.is_valid():
			_status_tween.kill()
		_status_tween = create_tween()
		_status_tween.tween_callback(func(): _status_label.visible = false).set_delay(2.0)

func _center_window(window: Window) -> void:
	var base_size := Vector2i(EditorInterface.get_base_control().size)
	window.position = (base_size - window.size) / 2

func _show_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_confirm_dialog(title: String, message: String, on_confirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(func():
		on_confirm.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _show_input_dialog(title: String, message: String, placeholder: String, on_confirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	EditorInterface.get_base_control().add_child(dialog)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)
	
	if message != "":
		var label := Label.new()
		label.text = message
		vbox.add_child(label)
	
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size.x = int(240 * _scale)
	vbox.add_child(input)
	
	dialog.register_text_enter(input)
	dialog.confirmed.connect(func():
		on_confirm.call(input.text.strip_edges())
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
	input.call_deferred("grab_focus")

func _show_add_resource_type_dialog() -> void:
	_show_input_dialog(
		"Add Resource Type",
		"Enter resource type name:",
		"e.g. gold, mana",
		func(new_type: String):
			if new_type != "" and not new_type in _shared_config.resource_types:
				_shared_config.resource_types.append(new_type)
				save_shared_config()
				_plugin.regenerate_data_class()
	)

func _show_add_tag_dialog() -> void:
	_show_input_dialog(
		"Add Tag",
		"Enter tag name:",
		"e.g. camo, flying",
		func(new_tag: String):
			if new_tag != "" and not new_tag in _shared_config.known_tags:
				_shared_config.known_tags.append(new_tag)
				save_shared_config()
	)

func _show_remove_resource_type_dialog(resource_type: String) -> void:
	var entries_with_value: Array[Resource] = []
	var key := _schema.dynamic_properties_key
	for entry in _manager.get_all_entries():
		if entry.get(key) is Dictionary:
			var dict: Dictionary = entry.get(key)
			if dict.get(resource_type, 0) != 0:
				entries_with_value.append(entry)
	
	if entries_with_value.size() > 0:
		_show_confirm_dialog(
			"Remove Resource Type",
			"%d %s(s) have non-zero \"%s\" value. These will be set to 0. Continue?" % [entries_with_value.size(), _schema.data_class_name, resource_type],
			func():
				for entry in entries_with_value:
					var dict: Dictionary = entry.get(key)
					dict[resource_type] = 0
					_manager.save_entry(entry, entry.resource_path)
				_shared_config.resource_types.erase(resource_type)
				save_shared_config()
				_plugin.regenerate_data_class()
				_refresh_dynamic_list()
		)
	else:
		_show_confirm_dialog(
			"Remove Resource Type",
			"Remove \"%s\" from the list?" % resource_type,
			func():
				_shared_config.resource_types.erase(resource_type)
				save_shared_config()
				_plugin.regenerate_data_class()
				_refresh_dynamic_list()
		)

func _show_overwrite_confirmation(path: String, display_name: String) -> void:
	_show_confirm_dialog(
		"Overwrite",
		"A resource named %s already exists. Overwrite it?" % path.get_file(),
		func(): _do_save(path, display_name)
	)
