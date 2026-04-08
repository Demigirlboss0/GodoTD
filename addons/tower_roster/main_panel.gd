@tool
extends Control

## Main panel for the Tower Roster plugin.
## Orchestrates layout, form editing, and settings management.

signal request_refresh_list

var _plugin: EditorPlugin
var _data_manager: TowerDataManager
var _theme: Theme
var _scale: float = 1.0

var tower_list: ItemList
var add_tower_btn: Button
var tower_name_input: LineEdit
var filename_input: LineEdit
var range_input: SpinBox
var damage_input: SpinBox
var fire_rate_input: SpinBox
var pierce_input: SpinBox
var multishot_input: SpinBox
var traversal_time_input: SpinBox
var attack_style_option: OptionButton
var projectile_picker: Button
var visuals_container: VBoxContainer
var costs_container: VBoxContainer
var target_mode_option: OptionButton
var target_tags_input: LineEdit
var tags_container: VBoxContainer
var save_btn: Button
var settings_vbox: VBoxContainer
var settings_container: VBoxContainer

var current_tower: Resource
var is_new_tower: bool = false
var visual_entries: Dictionary = {}

const DEFAULT_MAX_VALUE := 999999
const LABEL_WIDTH := 120


## =============================================================================
## INITIALIZATION
## =============================================================================

func _ready() -> void:
	pass

func set_plugin(p: EditorPlugin) -> void:
	_plugin = p
	_apply_theme()
	_build_ui()
	_data_manager = TowerDataManager.new(_plugin)
	_connect_signals()
	_refresh_settings()
	_refresh_costs_list(null)
	call_deferred("_refresh_tower_list")

func _apply_theme() -> void:
	_theme = EditorInterface.get_editor_theme()
	_scale = EditorInterface.get_editor_scale()
	_apply_theme_to_tree(self)

func _apply_theme_to_tree(node: Control) -> void:
	if node is Label:
		node.add_theme_color_override("font_color", _theme.get_color("property_color", "Editor"))
	if node is Button:
		node.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))
	if node is LineEdit or node is SpinBox:
		node.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))
	
	for child in node.get_children():
		if child is Control:
			_apply_theme_to_tree(child)

func _connect_signals() -> void:
	if _plugin and "settings_changed" in _plugin:
		_plugin.settings_changed.connect(_on_settings_changed)
	if _plugin and "resource_types_changed" in _plugin:
		_plugin.resource_types_changed.connect(_on_resource_types_changed)

func _on_settings_changed() -> void:
	_refresh_tower_list()
	_refresh_settings()

func _on_resource_types_changed() -> void:
	if current_tower:
		_refresh_costs_list(current_tower)

func _exit_tree() -> void:
	if _plugin:
		if _plugin.settings_changed.is_connected(_on_settings_changed):
			_plugin.settings_changed.disconnect(_on_settings_changed)
		if _plugin.resource_types_changed.is_connected(_on_resource_types_changed):
			_plugin.resource_types_changed.disconnect(_on_resource_types_changed)


## =============================================================================
## UI CONSTRUCTION
## =============================================================================

func _build_ui() -> void:
	var hsplit := HSplitContainer.new() as HSplitContainer
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.add_theme_constant_override("separation", int(8 * _scale))
	add_child(hsplit)
	
	_build_left_panel(hsplit)
	_build_form_panel(hsplit)
	_build_settings_panel(hsplit)

func _build_left_panel(parent: HSplitContainer) -> void:
	var left_panel := VBoxContainer.new() as VBoxContainer
	left_panel.custom_minimum_size.x = int(200 * _scale)
	parent.add_child(left_panel)
	
	var header := HBoxContainer.new() as HBoxContainer
	left_panel.add_child(header)
	
	var title := Label.new() as Label
	title.text = "Towers"
	title.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
	header.add_child(title)
	
	header.add_child(_make_spacer())
	
	add_tower_btn = Button.new()
	add_tower_btn.flat = true
	add_tower_btn.icon = _theme.get_icon("Add", "EditorIcons")
	add_tower_btn.text = "Add"
	add_tower_btn.tooltip_text = "Add new tower (Ctrl+N)"
	add_tower_btn.pressed.connect(_on_add_tower_pressed)
	header.add_child(add_tower_btn)
	
	tower_list = ItemList.new()
	tower_list.custom_minimum_size.y = int(200 * _scale)
	tower_list.item_selected.connect(_on_tower_selected)
	tower_list.gui_input.connect(_on_tower_list_input)
	left_panel.add_child(tower_list)

func _build_form_panel(parent: HSplitContainer) -> void:
	var form_scroll := ScrollContainer.new() as ScrollContainer
	form_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(form_scroll)
	
	var form_container := VBoxContainer.new() as VBoxContainer
	form_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	form_container.add_theme_constant_override("separation", int(8 * _scale))
	form_scroll.add_child(form_container)
	
	_build_form_fields(form_container)

func _build_form_fields(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_header("Basic Info"))
	
	parent.add_child(_make_property_row("Name:", _make_lineedit()))
	tower_name_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as LineEdit
	tower_name_input.placeholder_text = "Enter tower name"
	tower_name_input.text_changed.connect(_on_name_changed)
	
	parent.add_child(_make_property_row("Filename:", _make_lineedit()))
	filename_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as LineEdit
	filename_input.placeholder_text = "Auto-derived filename"
	
	parent.add_child(_make_section_header("Stats"))
	
	parent.add_child(_make_property_row("Range:", _make_spinbox()))
	range_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	range_input.min_value = 0
	range_input.max_value = DEFAULT_MAX_VALUE
	range_input.value = 10.0
	
	parent.add_child(_make_property_row("Damage:", _make_spinbox()))
	damage_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	damage_input.min_value = 0
	damage_input.max_value = DEFAULT_MAX_VALUE
	damage_input.value = 10.0
	
	parent.add_child(_make_property_row("Fire Rate:", _make_spinbox()))
	fire_rate_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	fire_rate_input.min_value = 0
	fire_rate_input.max_value = DEFAULT_MAX_VALUE
	fire_rate_input.step = 0.1
	fire_rate_input.value = 1.0
	
	parent.add_child(_make_property_row("Pierce:", _make_spinbox()))
	pierce_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	pierce_input.min_value = 1
	pierce_input.max_value = DEFAULT_MAX_VALUE
	pierce_input.value = 1
	
	parent.add_child(_make_property_row("Multishot:", _make_spinbox()))
	multishot_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	multishot_input.min_value = 1
	multishot_input.max_value = DEFAULT_MAX_VALUE
	multishot_input.value = 1
	
	parent.add_child(_make_property_row("Traversal Time:", _make_spinbox()))
	traversal_time_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	traversal_time_input.min_value = 0
	traversal_time_input.max_value = DEFAULT_MAX_VALUE
	traversal_time_input.step = 0.1
	traversal_time_input.value = 0.0
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Attack"))
	
	var attack_style_row := _make_property_row("Style:", OptionButton.new())
	attack_style_option = attack_style_row.get_child(1) as OptionButton
	attack_style_option.add_item("LINEAR", 0)
	attack_style_option.add_item("RADIAL", 1)
	attack_style_option.selected = 0
	parent.add_child(attack_style_row)
	
	var projectile_row := _make_property_row("Projectile:", _make_picker_button())
	projectile_picker = projectile_row.get_child(1) as Button
	projectile_picker.text = "Select..."
	projectile_picker.pressed.connect(_on_projectile_picker_pressed)
	parent.add_child(projectile_row)
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Targeting"))
	
	var target_mode_row := _make_property_row("Mode:", OptionButton.new())
	target_mode_option = target_mode_row.get_child(1) as OptionButton
	target_mode_option.add_item("WHITELIST", 0)
	target_mode_option.add_item("BLACKLIST", 1)
	target_mode_option.selected = 0
	parent.add_child(target_mode_row)
	
	tags_container = VBoxContainer.new()
	parent.add_child(tags_container)
	
	var tag_input_container := HBoxContainer.new() as HBoxContainer
	parent.add_child(tag_input_container)
	
	target_tags_input = LineEdit.new()
	target_tags_input.placeholder_text = "Add tag (press Enter)"
	target_tags_input.custom_minimum_size.x = int(120 * _scale)
	target_tags_input.text_submitted.connect(_on_tag_submitted)
	tag_input_container.add_child(target_tags_input)
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Visuals"))
	
	visuals_container = VBoxContainer.new()
	parent.add_child(visuals_container)
	
	var add_visual_btn := _make_flat_button("Add Visual", "Add")
	add_visual_btn.pressed.connect(_on_add_visual_pressed)
	parent.add_child(add_visual_btn)
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Costs"))
	
	costs_container = VBoxContainer.new()
	parent.add_child(costs_container)
	
	parent.add_child(_make_spacer_small())
	save_btn = _make_primary_button("Save")
	save_btn.pressed.connect(_on_save_pressed)
	parent.add_child(save_btn)

func _build_settings_panel(parent: HSplitContainer) -> void:
	settings_container = VBoxContainer.new() as VBoxContainer
	settings_container.custom_minimum_size.x = int(250 * _scale)
	parent.add_child(settings_container)
	
	settings_vbox = VBoxContainer.new() as VBoxContainer
	settings_vbox.add_theme_constant_override("separation", int(4 * _scale))
	settings_container.add_child(settings_vbox)
	
	_build_settings_content()

func _build_settings_content() -> void:
	settings_vbox.add_child(_make_section_header("Settings"))
	
	var project_mode_option := OptionButton.new() as OptionButton
	project_mode_option.add_item("2D", 0)
	project_mode_option.add_item("3D", 1)
	project_mode_option.selected = _plugin.settings.project_mode
	project_mode_option.custom_minimum_size.y = int(30 * _scale)
	project_mode_option.item_selected.connect(func(idx: int):
		_plugin.settings.project_mode = idx
		_plugin.save_settings()
	)
	settings_vbox.add_child(_make_property_row("Mode:", project_mode_option))
	
	var output_dir_input := LineEdit.new() as LineEdit
	output_dir_input.text = _plugin.settings.output_directory
	output_dir_input.custom_minimum_size.y = int(30 * _scale)
	output_dir_input.text_changed.connect(_on_output_directory_changed)
	settings_vbox.add_child(_make_property_row("Output:", output_dir_input))
	
	var output_error_label := Label.new() as Label
	output_error_label.name = "output_error"
	output_error_label.modulate = Color(1, 0.3, 0.3)
	output_error_label.visible = false
	output_error_label.add_theme_font_size_override("font_size", int(10 * _scale))
	settings_vbox.add_child(output_error_label)
	_update_settings_error()
	
	settings_vbox.add_child(_make_spacer_small())
	settings_vbox.add_child(_make_section_header("Resource Types"))
	
	var resource_types_list := VBoxContainer.new() as VBoxContainer
	resource_types_list.name = "resource_types_list"
	settings_vbox.add_child(resource_types_list)
	_populate_resource_types_list(resource_types_list)
	
	var add_resource_type_btn := _make_flat_button("+ Add", "Add")
	add_resource_type_btn.custom_minimum_size.y = int(24 * _scale)
	add_resource_type_btn.pressed.connect(_show_add_resource_type_dialog)
	settings_vbox.add_child(add_resource_type_btn)
	
	settings_vbox.add_child(_make_spacer_small())
	settings_vbox.add_child(_make_section_header("Known Tags"))
	
	var tags_list := VBoxContainer.new() as VBoxContainer
	tags_list.name = "tags_list"
	settings_vbox.add_child(tags_list)
	_populate_tags_list(tags_list)
	
	var add_tag_btn := _make_flat_button("+ Add", "Add")
	add_tag_btn.custom_minimum_size.y = int(24 * _scale)
	add_tag_btn.pressed.connect(_show_add_tag_dialog)
	settings_vbox.add_child(add_tag_btn)


## =============================================================================
## UI HELPERS
## =============================================================================

func _make_spacer() -> Control:
	var spacer := Control.new() as Control
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func _make_spacer_small() -> Control:
	var spacer := Control.new() as Control
	spacer.custom_minimum_size.y = int(4 * _scale)
	return spacer

func _make_section_header(text: String) -> Label:
	var label := Label.new() as Label
	label.text = text
	label.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
	label.add_theme_color_override("font_color", _theme.get_color("accent_color", "Editor"))
	return label

func _make_property_row(label_text: String, input: Control) -> HBoxContainer:
	var row := HBoxContainer.new() as HBoxContainer
	var label := Label.new() as Label
	label.text = label_text
	label.custom_minimum_size.x = int(LABEL_WIDTH * _scale)
	row.add_child(label)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	return row

func _make_lineedit() -> LineEdit:
	var edit := LineEdit.new() as LineEdit
	_apply_font_size_to_control(edit)
	return edit

func _make_spinbox() -> SpinBox:
	var spin := SpinBox.new() as SpinBox
	_apply_font_size_to_control(spin)
	return spin

func _apply_font_size_to_control(control: Control) -> void:
	control.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))

func _make_picker_button() -> Button:
	var btn := Button.new() as Button
	_apply_font_size_to_control(btn)
	return btn

func _make_flat_button(text: String, icon_name: String = "") -> Button:
	var btn := Button.new() as Button
	btn.flat = true
	btn.text = text
	if icon_name:
		btn.icon = _theme.get_icon(icon_name, "EditorIcons")
	_apply_font_size_to_control(btn)
	return btn

func _make_primary_button(text: String) -> Button:
	var btn := Button.new() as Button
	btn.text = text
	_apply_font_size_to_control(btn)
	return btn


## =============================================================================
## DATA MANAGEMENT
## =============================================================================

func _refresh_tower_list() -> void:
	if not tower_list:
		return
	tower_list.clear()
	if not _plugin or not _plugin.settings:
		return
	
	if not DirAccess.dir_exists_absolute(_plugin.settings.output_directory):
		return
	
	var dir := DirAccess.open(_plugin.settings.output_directory) as DirAccess
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "TowerData.tres":
			var path := (_plugin.settings.output_directory + file_name) as String
			var res: Resource = load(path) as Resource
			if res and "tower_name" in res:
				var idx := tower_list.add_item(res.tower_name) as int
				tower_list.set_item_metadata(idx, path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _refresh_settings() -> void:
	_refresh_resource_types_list()
	_refresh_tags_list()
	_update_settings_error()
	_refresh_costs_list(current_tower)

func _refresh_resource_types_list() -> void:
	if not settings_vbox:
		return
	var list_container := settings_vbox.get_node("resource_types_list") as VBoxContainer
	if list_container:
		_populate_resource_types_list(list_container)

func _refresh_tags_list() -> void:
	if not settings_vbox:
		return
	var tags_list := settings_vbox.get_node("tags_list") as VBoxContainer
	if tags_list:
		_populate_tags_list(tags_list)

func _update_settings_error() -> void:
	if not settings_vbox:
		return
	var error_label := settings_vbox.get_node("output_error") as Label
	if error_label:
		var is_valid := _validate_output_directory(_plugin.settings.output_directory)
		error_label.visible = not is_valid
		error_label.text = "Invalid path. Must start with 'res://'" if not is_valid else ""


## =============================================================================
## FORM HANDLING
## =============================================================================

func _on_add_tower_pressed() -> void:
	current_tower = null
	is_new_tower = true
	_clear_form()

func _on_tower_selected(index: int) -> void:
	if not _data_manager:
		return
	
	var path: String = tower_list.get_item_metadata(index) as String
	if path == "":
		return
	
	if not FileAccess.file_exists(path):
		_show_message_dialog("Tower file not found. It may have been deleted.", "OK", func(): pass)
		_refresh_tower_list()
		return
	
	var tower: Resource = load(path) as Resource
	if not tower:
		_show_message_dialog("Failed to load tower resource.", "OK", func(): pass)
		return
	
	current_tower = tower
	is_new_tower = false
	_load_tower_to_form(tower)

func _load_tower_to_form(tower: Resource) -> void:
	if not tower:
		_clear_form()
		return
	
	tower_name_input.text = tower.tower_name if "tower_name" in tower else ""
	if current_tower and "resource_path" in current_tower:
		filename_input.text = current_tower.resource_path.get_file()
	else:
		filename_input.text = ""
	range_input.value = tower.get("range") if "range" in tower else 10.0
	damage_input.value = tower.get("damage") if "damage" in tower else 10.0
	fire_rate_input.value = tower.get("fire_rate") if "fire_rate" in tower else 1.0
	pierce_input.value = tower.get("pierce") if "pierce" in tower else 1
	multishot_input.value = tower.get("multishot") if "multishot" in tower else 1
	traversal_time_input.value = tower.get("traversal_time") if "traversal_time" in tower else 0.0
	attack_style_option.selected = tower.get("attack_style") if "attack_style" in tower else 0
	target_mode_option.selected = tower.get("target_mode") if "target_mode" in tower else 0
	
	if tower.get("projectile_scene"):
		projectile_picker.text = tower.projectile_scene.resource_path.get_file()
	else:
		projectile_picker.text = "Select..."
	
	var visuals: Dictionary = tower.get("visuals") if "visuals" in tower else {}
	_load_visuals(visuals)
	
	var tags: Array[String] = []
	if tower.get("target_tags"):
		for t in tower.get("target_tags"):
			tags.append(t as String)
	_load_tags(tags)
	
	_on_resource_types_changed()

func _clear_form() -> void:
	tower_name_input.text = ""
	filename_input.text = ""
	range_input.value = 10.0
	damage_input.value = 10.0
	fire_rate_input.value = 1.0
	pierce_input.value = 1
	multishot_input.value = 1
	traversal_time_input.value = 0.0
	attack_style_option.selected = 0
	target_mode_option.selected = 0
	projectile_picker.text = "Select..."
	
	visual_entries.clear()
	_clear_visuals()
	_clear_tags()
	_on_resource_types_changed()

func _on_name_changed(new_name: String) -> void:
	filename_input.text = _data_manager.derive_filename(new_name)


## =============================================================================
## SETTINGS MANAGEMENT
## =============================================================================

func _on_output_directory_changed(text: String) -> void:
	var is_valid := _validate_output_directory(text)
	if is_valid:
		_plugin.settings.output_directory = text
		_plugin.save_settings()
	_update_settings_error()

func _validate_output_directory(path: String) -> bool:
	if path == "":
		return false
	if not path.begins_with("res://"):
		return false
	return true


## =============================================================================
## COSTS
## =============================================================================

func _refresh_costs_list(tower: Resource) -> void:
	for child in costs_container.get_children():
		child.queue_free()
	
	if not _plugin or not _plugin.settings:
		return
	
	if _plugin.settings.resource_types.is_empty():
		return
	
	for resource_type in _plugin.settings.resource_types:
		_add_cost_row(resource_type, tower)

func _add_cost_row(resource_type: String, tower: Resource) -> void:
	var container := HBoxContainer.new() as HBoxContainer
	costs_container.add_child(container)
	
	var label := Label.new() as Label
	label.text = resource_type + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)
	
	var input := SpinBox.new() as SpinBox
	input.min_value = 0
	input.max_value = DEFAULT_MAX_VALUE
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var field_name := "cost_" + resource_type.to_lower().replace(" ", "_") as String
	if tower and field_name in tower:
		input.value = tower.get(field_name) if tower.get(field_name) != null else 0
	
	container.add_child(input)
	
	var remove_btn := Button.new() as Button
	remove_btn.flat = true
	remove_btn.icon = _theme.get_icon("Close", "EditorIcons")
	remove_btn.tooltip_text = "Remove this resource type from all towers"
	remove_btn.pressed.connect(func():
		_show_remove_resource_type_dialog(resource_type)
	)
	container.add_child(remove_btn)


## =============================================================================
## VISUALS
## =============================================================================

func _clear_visuals() -> void:
	visual_entries.clear()
	for child in visuals_container.get_children():
		child.queue_free()

func _load_visuals(visuals: Dictionary) -> void:
	_clear_visuals()
	for key in visuals:
		_add_visual_entry(key, visuals[key])

func _on_add_visual_pressed() -> void:
	_add_visual_entry("", null)

func _add_visual_entry(key: String, value: Variant) -> void:
	var container := HBoxContainer.new() as HBoxContainer
	visuals_container.add_child(container)
	
	var key_edit := _make_lineedit()
	key_edit.placeholder_text = "Key (e.g. idle)"
	key_edit.text = key
	container.add_child(key_edit)
	
	var entry_id := visual_entries.size() as int
	visual_entries[entry_id] = {"key_edit": key_edit, "value": value}
	
	var select_btn := _make_picker_button()
	select_btn.text = _get_resource_name(value)
	select_btn.pressed.connect(func(): _show_resource_picker(entry_id, select_btn))
	container.add_child(select_btn)
	
	var remove_btn := Button.new() as Button
	remove_btn.flat = true
	remove_btn.icon = _theme.get_icon("Remove", "EditorIcons")
	remove_btn.pressed.connect(func():
		visual_entries.erase(entry_id)
		container.queue_free()
	)
	container.add_child(remove_btn)

func _get_resource_name(res: Variant) -> String:
	if res and typeof(res) == TYPE_OBJECT:
		if "resource_path" in res:
			var path := res.resource_path as String
			if path:
				return path.get_file()
	return "Select..."

func _show_resource_picker(entry_id: int, btn: Button) -> void:
	var dialog := EditorFileDialog.new() as EditorFileDialog
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	
	if _plugin.settings.project_mode == 0:
		dialog.filters = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.tres"]
	else:
		dialog.filters = ["*.tres", "*.obj", "*.gltf", "*.glb"]
	
	EditorInterface.get_base_control().add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var res: Resource = load(path) as Resource
		visual_entries[entry_id]["value"] = res
		btn.text = path.get_file()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(int(800 * _scale), int(600 * _scale)))


## =============================================================================
## TAGS
## =============================================================================

func _clear_tags() -> void:
	for child in tags_container.get_children():
		child.queue_free()

func _load_tags(tags: Array[String]) -> void:
	_clear_tags()
	for tag in tags:
		_add_tag_entry(tag)

func _on_tag_submitted(tag: String) -> void:
	tag = tag.strip_edges()
	if tag == "":
		return
	
	if not tag in _plugin.settings.known_tags:
		_plugin.settings.known_tags.append(tag)
		_plugin.save_settings()
	
	_add_tag_entry(tag)
	target_tags_input.text = ""

func _add_tag_entry(tag: String) -> void:
	var container := HBoxContainer.new() as HBoxContainer
	tags_container.add_child(container)
	
	var label := Label.new() as Label
	label.text = tag
	container.add_child(label)
	
	var is_unknown: bool = not tag in _plugin.settings.known_tags
	if is_unknown:
		label.modulate = Color(1, 0.8, 0, 1)
	
	var remove_btn := Button.new() as Button
	remove_btn.flat = true
	remove_btn.icon = _theme.get_icon("Remove", "EditorIcons")
	remove_btn.pressed.connect(func():
		container.queue_free()
	)
	container.add_child(remove_btn)


## =============================================================================
## SAVE
## =============================================================================

func _on_save_pressed() -> void:
	_save_current_tower()

func _save_current_tower() -> void:
	if not tower_name_input or tower_name_input.text.strip_edges() == "":
		_show_message_dialog("Please enter a tower name.", "OK", func(): pass)
		return
	
	var filename := filename_input.text.strip_edges() as String
	if filename == "":
		filename = _data_manager.derive_filename(tower_name_input.text)
	
	if not filename.ends_with(".tres"):
		filename += ".tres"
	
	if not _validate_output_directory(_plugin.settings.output_directory):
		_show_message_dialog("Invalid output directory. Please check settings.", "OK", func(): pass)
		return
	
	var output_path := _plugin.settings.output_directory + filename as String
	
	if FileAccess.file_exists(output_path) and is_new_tower:
		_show_overwrite_confirmation(output_path)
	else:
		_do_save(output_path)

func _show_overwrite_confirmation(path: String) -> void:
	var dialog := ConfirmationDialog.new() as ConfirmationDialog
	dialog.dialog_text = "A resource named %s already exists. Overwrite it?" % path.get_file()
	dialog.ok_button_text = "Overwrite"
	dialog.cancel_button_text = "Cancel"
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		_do_save(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

func _do_save(path: String) -> void:
	var tower: Resource = _data_manager.create_tower_instance()
	if not tower:
		_show_message_dialog("Failed to create tower resource. Ensure TowerData.gd exists.", "OK", func(): pass)
		return
	
	tower.tower_name = tower_name_input.text.strip_edges()
	tower.range = range_input.value
	tower.damage = damage_input.value
	tower.fire_rate = fire_rate_input.value
	tower.pierce = int(pierce_input.value)
	tower.multishot = int(multishot_input.value)
	tower.traversal_time = traversal_time_input.value
	tower.attack_style = attack_style_option.selected
	tower.target_mode = target_mode_option.selected
	
	var visuals := {} as Dictionary
	for entry_id in visual_entries:
		var data: Dictionary = visual_entries[entry_id]
		var key: String = (data["key_edit"] as LineEdit).text.strip_edges()
		var value: Variant = data["value"]
		if key != "" and value:
			visuals[key] = value
	tower.visuals = visuals
	
	var tags := [] as Array[String]
	for child in tags_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var label: Label = child.get_child(0) as Label
			if label:
				tags.append(label.text)
	tower.set("target_tags", tags)
	
	for resource_type in _plugin.settings.resource_types:
		for child in costs_container.get_children():
			if child is HBoxContainer and child.get_child_count() > 1:
				var input: SpinBox = child.get_child(1) as SpinBox
				if input:
					var field_name := "cost_" + resource_type.to_lower().replace(" ", "_") as String
					tower.set(field_name, int(input.value))
	
	var save_result := _data_manager.save_tower(tower, path)
	if save_result:
		is_new_tower = false
		current_tower = tower
		_refresh_tower_list()
		_show_message_dialog("Tower saved successfully!", "OK", func(): pass)
	else:
		_show_message_dialog("Failed to save tower. Check console for errors.", "OK", func(): pass)


## =============================================================================
## DIALOG HELPERS
## =============================================================================

func _show_message_dialog(message: String, button_text: String, on_confirm: Callable) -> void:
	var dialog := AcceptDialog.new() as AcceptDialog
	dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(dialog)
	dialog.ok_button_text = button_text
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		on_confirm.call()
		dialog.queue_free()
	)


## =============================================================================
## SETTINGS UI
## =============================================================================

func _populate_resource_types_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	if not _plugin or not _plugin.settings:
		return
	
	for rt in _plugin.settings.resource_types:
		var rt_container := HBoxContainer.new() as HBoxContainer
		container.add_child(rt_container)
		
		var rt_label := Label.new() as Label
		rt_label.text = rt
		rt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt_container.add_child(rt_label)
		
		var rt_val := rt as String
		var remove_btn := Button.new() as Button
		remove_btn.flat = true
		remove_btn.icon = _theme.get_icon("Remove", "EditorIcons")
		remove_btn.pressed.connect(func():
			_show_confirm_dialog(
				"Remove Resource Type",
				"Remove \"%s\"? This will also remove the cost field from all towers." % rt_val,
				func():
					_plugin.settings.resource_types.erase(rt_val)
					_plugin.regenerate_tower_data_class()
					_plugin.save_settings()
			)
		)
		rt_container.add_child(remove_btn)

func _populate_tags_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	if not _plugin or not _plugin.settings:
		return
	
	for tag in _plugin.settings.known_tags:
		var tag_container := HBoxContainer.new() as HBoxContainer
		container.add_child(tag_container)
		
		var tag_label := Label.new() as Label
		tag_label.text = tag
		tag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_container.add_child(tag_label)
		
		var tag_val := tag as String
		var remove_btn := Button.new() as Button
		remove_btn.flat = true
		remove_btn.icon = _theme.get_icon("Remove", "EditorIcons")
		remove_btn.pressed.connect(func():
			_show_confirm_dialog(
				"Remove Tag",
				"Remove \"%s\" from known tags?" % tag_val,
				func():
					_plugin.settings.known_tags.erase(tag_val)
					_plugin.save_settings()
			)
		)
		tag_container.add_child(remove_btn)

func _show_add_resource_type_dialog() -> void:
	var on_confirm := func(new_type: String):
		if new_type != "" and not new_type in _plugin.settings.resource_types:
			_plugin.settings.resource_types.append(new_type)
			_plugin.regenerate_tower_data_class()
			_plugin.save_settings()
	_show_input_dialog("Add Resource Type", "Enter resource type name:", "e.g. gold, food, mana", on_confirm)

func _show_add_tag_dialog() -> void:
	var on_confirm := func(new_tag: String):
		if new_tag != "" and not new_tag in _plugin.settings.known_tags:
			_plugin.settings.known_tags.append(new_tag)
			_plugin.save_settings()
	_show_input_dialog("Add Tag", "Enter tag name:", "e.g. camo, flying", on_confirm)

func _show_input_dialog(title: String, message: String, placeholder: String, on_confirm: Callable) -> void:
	var window := Window.new() as Window
	window.title = title
	window.size = Vector2i(int(350 * _scale), int(150 * _scale))
	window.transient = true
	window.exclusive = true
	EditorInterface.get_base_control().add_child(window)
	var screen_size: Vector2 = EditorInterface.get_editor_main_screen().size as Vector2
	var window_size: Vector2 = window.size as Vector2
	window.position = (screen_size - window_size) / 2
	
	var vbox := VBoxContainer.new() as VBoxContainer
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", int(16 * _scale))
	vbox.add_theme_constant_override("margin_top", int(16 * _scale))
	window.add_child(vbox)
	
	var label := Label.new() as Label
	label.text = message
	vbox.add_child(label)
	
	var input := _make_lineedit()
	input.placeholder_text = placeholder
	vbox.add_child(input)
	
	var hbox := HBoxContainer.new() as HBoxContainer
	hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hbox)
	
	var cancel_btn := _make_flat_button("Cancel")
	cancel_btn.pressed.connect(func(): window.queue_free())
	hbox.add_child(cancel_btn)
	
	var ok_btn := _make_primary_button("OK")
	ok_btn.pressed.connect(func():
		on_confirm.call(input.text.strip_edges())
		window.queue_free()
	)
	hbox.add_child(ok_btn)
	
	input.text_submitted.connect(func(_text: String):
		on_confirm.call(input.text.strip_edges())
		window.queue_free()
	)
	
	input.grab_focus()

func _show_confirm_dialog(title: String, message: String, on_confirm: Callable) -> void:
	var dialog := ConfirmationDialog.new() as ConfirmationDialog
	dialog.title = title
	dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(dialog)
	dialog.confirmed.connect(func():
		on_confirm.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _show_remove_resource_type_dialog(resource_type: String) -> void:
	var field_name := "cost_" + resource_type.to_lower().replace(" ", "_") as String
	var towers_with_value: Array[Resource] = []
	
	for tower in _data_manager.get_all_tower_resources():
		if field_name in tower:
			var val = tower.get(field_name) if tower.get(field_name) != null else 0
			if val != 0:
				towers_with_value.append(tower)
	
	if towers_with_value.size() > 0:
		_show_confirm_dialog(
			"Remove Resource Type",
			str(towers_with_value.size()) + " tower(s) have non-zero \"" + resource_type + "\" cost. These will be set to 0. Continue?",
			func():
				var resource_types: Array[String] = _plugin.settings.resource_types.duplicate()
				resource_types.erase(resource_type)
				_plugin.settings.resource_types = resource_types
				
				for tower in towers_with_value:
					tower.set(field_name, 0)
					_data_manager.save_tower(tower, tower.resource_path.get_file())
				
				_plugin.save_settings()
				_plugin.regenerate_tower_data_class()
				_refresh_costs_list(current_tower)
		)
	else:
		_show_confirm_dialog(
			"Remove Resource Type",
			"Remove \"" + resource_type + "\" from the resource type list?",
			func():
				var resource_types: Array[String] = _plugin.settings.resource_types.duplicate()
				resource_types.erase(resource_type)
				_plugin.settings.resource_types = resource_types
				_plugin.save_settings()
				_plugin.regenerate_tower_data_class()
				_refresh_costs_list(current_tower)
		)


## =============================================================================
## KEYBOARD SHORTCUTS
## =============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.ctrl_or_meta:
				match key_event.keycode:
					KEY_S:
						_on_save_pressed()
					KEY_N:
						_on_add_tower_pressed()

func _on_tower_list_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_DELETE:
			_attempt_delete_selected_tower()

func _attempt_delete_selected_tower() -> void:
	var selected_idx := tower_list.get_selected_items()[0] if tower_list.get_selected_items().size() > 0 else -1
	if selected_idx < 0:
		return
	
	var path: String = tower_list.get_item_metadata(selected_idx) as String
	if path == "":
		return
	
	var tower_name: String = tower_list.get_item_text(selected_idx)
	_show_confirm_dialog(
		"Delete Tower",
		"Delete \"%s\"? This action cannot be undone." % tower_name,
		func():
			_delete_tower_file(path)
	)

func _delete_tower_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		_show_message_dialog("File not found.", "OK", func(): pass)
		return
	
	var dir := DirAccess.open(path.get_base_dir()) as DirAccess
	if not dir:
		_show_message_dialog("Failed to access directory.", "OK", func(): pass)
		return
	
	var error := DirAccess.remove_absolute(path)
	if error == OK:
		_clear_form()
		current_tower = null
		is_new_tower = true
		_refresh_tower_list()
		_show_message_dialog("Tower deleted.", "OK", func(): pass)
	else:
		_show_message_dialog("Failed to delete tower. Error code: %d" % error, "OK", func(): pass)

func _on_projectile_picker_pressed() -> void:
	var dialog := EditorFileDialog.new() as EditorFileDialog
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = ["*.tscn"]
	EditorInterface.get_base_control().add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var res: Resource = load(path) as Resource
		if current_tower:
			current_tower.projectile_scene = res
			projectile_picker.text = path.get_file()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(int(800 * _scale), int(600 * _scale)))
