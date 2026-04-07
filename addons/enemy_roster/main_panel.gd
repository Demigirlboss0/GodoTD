@tool
extends Control

## Main panel for the Enemy Roster plugin.
## Orchestrates layout, form editing, and settings management.

signal request_refresh_list

var _plugin: EditorPlugin
var _data_manager: EnemyDataManager
var _theme: Theme
var _scale: float = 1.0

var enemy_list: ItemList
var add_enemy_btn: Button
var enemy_name_input: LineEdit
var filename_input: LineEdit
var max_health_input: SpinBox
var speed_input: SpinBox
var damage_input: SpinBox
var visuals_container: VBoxContainer
var rewards_container: VBoxContainer
var tags_container: VBoxContainer
var tag_input: LineEdit
var save_btn: Button
var tag_autocomplete: OptionButton
var settings_vbox: VBoxContainer
var settings_container: VBoxContainer

var current_enemy: Resource
var is_new_enemy: bool = false
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
	_data_manager = EnemyDataManager.new(_plugin)
	_connect_signals()
	_refresh_settings()
	_load_rewards(null)
	call_deferred("_refresh_enemy_list")

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
	_refresh_enemy_list()
	_refresh_settings()

func _on_resource_types_changed() -> void:
	_load_rewards(current_enemy)

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
	title.text = "Enemies"
	title.add_theme_font_override("font", _theme.get_font("bold", "EditorFonts"))
	header.add_child(title)
	
	header.add_child(_make_spacer())
	
	add_enemy_btn = Button.new()
	add_enemy_btn.flat = true
	add_enemy_btn.icon = _theme.get_icon("Add", "EditorIcons")
	add_enemy_btn.text = "Add"
	add_enemy_btn.tooltip_text = "Add new enemy (Ctrl+N)"
	add_enemy_btn.pressed.connect(_on_add_enemy_pressed)
	header.add_child(add_enemy_btn)
	
	enemy_list = ItemList.new()
	enemy_list.custom_minimum_size.y = int(200 * _scale)
	enemy_list.item_selected.connect(_on_enemy_selected)
	enemy_list.gui_input.connect(_on_enemy_list_input)
	left_panel.add_child(enemy_list)

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
	enemy_name_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as LineEdit
	enemy_name_input.placeholder_text = "Enter enemy name"
	enemy_name_input.text_changed.connect(_on_name_changed)
	
	parent.add_child(_make_property_row("Filename:", _make_lineedit()))
	filename_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as LineEdit
	filename_input.placeholder_text = "Auto-derived filename"
	
	parent.add_child(_make_property_row("Max Health:", _make_spinbox()))
	max_health_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	max_health_input.min_value = 0
	max_health_input.max_value = DEFAULT_MAX_VALUE
	max_health_input.value = 100
	
	parent.add_child(_make_property_row("Speed:", _make_spinbox()))
	speed_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	speed_input.min_value = 0
	speed_input.max_value = DEFAULT_MAX_VALUE
	speed_input.value = 100
	
	parent.add_child(_make_property_row("Damage:", _make_spinbox()))
	damage_input = parent.get_child(parent.get_child_count() - 1).get_child(1) as SpinBox
	damage_input.min_value = 0
	damage_input.max_value = DEFAULT_MAX_VALUE
	damage_input.value = 1
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Visuals"))
	
	visuals_container = VBoxContainer.new()
	parent.add_child(visuals_container)
	
	var add_visual_btn := _make_flat_button("Add Visual", "Add")
	add_visual_btn.pressed.connect(_on_add_visual_pressed)
	parent.add_child(add_visual_btn)
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Rewards"))
	
	rewards_container = VBoxContainer.new()
	parent.add_child(rewards_container)
	
	parent.add_child(_make_spacer_small())
	parent.add_child(_make_section_header("Tags"))
	
	tags_container = VBoxContainer.new()
	parent.add_child(tags_container)
	
	var tag_input_container := HBoxContainer.new() as HBoxContainer
	parent.add_child(tag_input_container)
	
	tag_input = LineEdit.new()
	tag_input.placeholder_text = "Add tag (press Enter)"
	tag_input.custom_minimum_size.x = int(120 * _scale)
	tag_input.text_submitted.connect(_on_tag_submitted)
	tag_input.text_changed.connect(_on_tag_text_changed)
	tag_input_container.add_child(tag_input)
	
	tag_autocomplete = OptionButton.new()
	tag_autocomplete.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag_autocomplete.custom_minimum_size.x = int(40 * _scale)
	tag_autocomplete.visible = false
	tag_autocomplete.item_selected.connect(_on_autocomplete_selected)
	tag_input_container.add_child(tag_autocomplete)
	
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

func _make_flat_button(text: String, icon_name: String = "") -> Button:
	var btn := Button.new() as Button
	btn.flat = true
	btn.text = text
	if icon_name:
		btn.icon = _theme.get_icon(icon_name, "EditorIcons")
	btn.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))
	return btn

func _make_primary_button(text: String) -> Button:
	var btn := Button.new() as Button
	btn.text = text
	btn.add_theme_font_size_override("font_size", _theme.get_font_size("main_size", "EditorFonts"))
	return btn


## =============================================================================
## DATA MANAGEMENT
## =============================================================================

func _refresh_enemy_list() -> void:
	if not enemy_list:
		return
	enemy_list.clear()
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
		if file_name.ends_with(".tres") and file_name != "EnemyData.tres":
			var path := (_plugin.settings.output_directory + file_name) as String
			var res: Resource = load(path) as Resource
			if res and "enemy_name" in res:
				var idx := enemy_list.add_item(res.enemy_name) as int
				enemy_list.set_item_metadata(idx, path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _refresh_settings() -> void:
	_refresh_resource_types_list()
	_refresh_tags_list()
	_update_settings_error()
	_refresh_rewards()

func _refresh_rewards() -> void:
	if not current_enemy:
		return
	_load_rewards(current_enemy)

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

func _on_add_enemy_pressed() -> void:
	current_enemy = null
	is_new_enemy = true
	_clear_form()

func _on_enemy_selected(index: int) -> void:
	if not _data_manager:
		return
	
	var path: String = enemy_list.get_item_metadata(index) as String
	if path == "":
		return
	
	if not FileAccess.file_exists(path):
		_show_message_dialog("Enemy file not found. It may have been deleted.", "OK", func(): pass)
		_refresh_enemy_list()
		return
	
	var enemy: Resource = load(path) as Resource
	if not enemy:
		_show_message_dialog("Failed to load enemy resource.", "OK", func(): pass)
		return
	
	current_enemy = enemy
	is_new_enemy = false
	_load_enemy_to_form(enemy)

func _load_enemy_to_form(enemy: Resource) -> void:
	if not enemy:
		_clear_form()
		return
	
	enemy_name_input.text = enemy.enemy_name if "enemy_name" in enemy else ""
	if current_enemy and "resource_path" in current_enemy:
		filename_input.text = current_enemy.resource_path.get_file()
	else:
		filename_input.text = ""
	max_health_input.value = enemy.max_health if "max_health" in enemy else 100.0
	speed_input.value = enemy.speed if "speed" in enemy else 100.0
	damage_input.value = enemy.damage if "damage" in enemy else 1.0
	
	var visuals: Dictionary = enemy.visuals if enemy.visuals else {}
	_load_visuals(visuals)
	
	var tags: Array[String] = enemy.target_tags if enemy.target_tags else []
	_load_tags(tags)
	
	_on_resource_types_changed()

func _clear_form() -> void:
	enemy_name_input.text = ""
	filename_input.text = ""
	max_health_input.value = 100
	speed_input.value = 100
	damage_input.value = 1
	
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
## REWARDS
## =============================================================================

func _load_rewards(enemy: Resource) -> void:
	for child in rewards_container.get_children():
		child.queue_free()
	
	if not _plugin or not _plugin.settings:
		return
	
	for resource_type in _plugin.settings.resource_types:
		var container := HBoxContainer.new() as HBoxContainer
		rewards_container.add_child(container)
		
		var label := Label.new() as Label
		label.text = resource_type.capitalize()
		container.add_child(label)
		
		var input := SpinBox.new() as SpinBox
		input.min_value = 0
		input.max_value = DEFAULT_MAX_VALUE
		input.name = "reward_" + resource_type
		
		if enemy and "reward_" + resource_type in enemy:
			input.value = enemy.get("reward_" + resource_type)
		
		container.add_child(input)


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
	
	var key_edit := LineEdit.new() as LineEdit
	key_edit.placeholder_text = "Key (e.g. idle)"
	key_edit.text = key
	container.add_child(key_edit)
	
	var entry_id := visual_entries.size() as int
	visual_entries[entry_id] = {"key_edit": key_edit, "value": value}
	
	var select_btn := Button.new() as Button
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
	tag_input.text = ""
	tag_autocomplete.visible = false

func _add_tag_entry(tag: String) -> void:
	var container := HBoxContainer.new() as HBoxContainer
	tags_container.add_child(container)
	
	var label := Label.new() as Label
	label.text = tag
	container.add_child(label)
	
	var remove_btn := Button.new() as Button
	remove_btn.flat = true
	remove_btn.icon = _theme.get_icon("Remove", "EditorIcons")
	remove_btn.pressed.connect(func():
		container.queue_free()
	)
	container.add_child(remove_btn)

func _on_tag_text_changed(text: String) -> void:
	if not _plugin or not _plugin.settings:
		return
	
	text = text.strip_edges()
	if text == "":
		tag_autocomplete.visible = false
		return
	
	var matches: Array[String] = []
	for known_tag in _plugin.settings.known_tags:
		if known_tag.to_lower().begins_with(text.to_lower()):
			matches.append(known_tag)
		if matches.size() >= 5:
			break
	
	if matches.size() > 0:
		tag_autocomplete.clear()
		for match_tag in matches:
			tag_autocomplete.add_item(match_tag)
		tag_autocomplete.visible = true
	else:
		tag_autocomplete.visible = false

func _on_autocomplete_selected(index: int) -> void:
	var selected := tag_autocomplete.get_item_text(index) as String
	tag_input.text = selected
	tag_autocomplete.visible = false
	_on_tag_submitted(selected)


## =============================================================================
## SAVE
## =============================================================================

func _on_save_pressed() -> void:
	_save_current_enemy()

func _save_current_enemy() -> void:
	if not enemy_name_input or enemy_name_input.text.strip_edges() == "":
		_show_message_dialog("Please enter an enemy name.", "OK", func(): pass)
		return
	
	var filename := filename_input.text.strip_edges() as String
	if filename == "":
		filename = _data_manager.derive_filename(enemy_name_input.text)
	
	if not filename.ends_with(".tres"):
		filename += ".tres"
	
	if not _validate_output_directory(_plugin.settings.output_directory):
		_show_message_dialog("Invalid output directory. Please check settings.", "OK", func(): pass)
		return
	
	var output_path := _plugin.settings.output_directory + filename as String
	
	if FileAccess.file_exists(output_path) and is_new_enemy:
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
	var enemy: Resource = _data_manager.create_enemy_instance()
	if not enemy:
		_show_message_dialog("Failed to create enemy resource. Ensure EnemyData.gd exists.", "OK", func(): pass)
		return
	
	enemy.enemy_name = enemy_name_input.text.strip_edges()
	enemy.max_health = max_health_input.value
	enemy.speed = speed_input.value
	enemy.damage = damage_input.value
	
	var visuals := {} as Dictionary
	for entry_id in visual_entries:
		var data: Dictionary = visual_entries[entry_id]
		var key: String = (data["key_edit"] as LineEdit).text.strip_edges()
		var value: Variant = data["value"]
		if key != "" and value:
			visuals[key] = value
	enemy.visuals = visuals
	
	var tags := [] as Array[String]
	for child in tags_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var label: Label = child.get_child(0) as Label
			if label:
				tags.append(label.text)
	enemy.set("target_tags", tags)
	
	for resource_type in _plugin.settings.resource_types:
		for child in rewards_container.get_children():
			if child is HBoxContainer and child.get_child_count() > 1:
				var input: SpinBox = child.get_child(1) as SpinBox
				if input and input.name == "reward_" + resource_type:
					enemy.set("reward_" + resource_type, int(input.value))
	
	var save_result := _data_manager.save_enemy(enemy, path)
	if save_result:
		is_new_enemy = false
		current_enemy = enemy
		_refresh_enemy_list()
		_show_message_dialog("Enemy saved successfully!", "OK", func(): pass)
	else:
		_show_message_dialog("Failed to save enemy. Check console for errors.", "OK", func(): pass)


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
				"Remove \"%s\"? This will also remove the reward field from all enemies." % rt_val,
				func():
					_plugin.settings.resource_types.erase(rt_val)
					_plugin.regenerate_enemy_data_class()
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
			_plugin.regenerate_enemy_data_class()
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
	
	var input := LineEdit.new() as LineEdit
	input.placeholder_text = placeholder
	vbox.add_child(input)
	
	var hbox := HBoxContainer.new() as HBoxContainer
	hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hbox)
	
	var cancel_btn := Button.new() as Button
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): window.queue_free())
	hbox.add_child(cancel_btn)
	
	var ok_btn := Button.new() as Button
	ok_btn.text = "OK"
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
						_on_add_enemy_pressed()

func _on_enemy_list_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_DELETE:
			_attempt_delete_selected_enemy()

func _attempt_delete_selected_enemy() -> void:
	var selected_idx := enemy_list.get_selected_items()[0] if enemy_list.get_selected_items().size() > 0 else -1
	if selected_idx < 0:
		return
	
	var path: String = enemy_list.get_item_metadata(selected_idx) as String
	if path == "":
		return
	
	var enemy_name: String = enemy_list.get_item_text(selected_idx)
	_show_confirm_dialog(
		"Delete Enemy",
		"Delete \"%s\"? This action cannot be undone." % enemy_name,
		func():
			_delete_enemy_file(path)
	)

func _delete_enemy_file(path: String) -> void:
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
		current_enemy = null
		is_new_enemy = true
		_refresh_enemy_list()
		_show_message_dialog("Enemy deleted.", "OK", func(): pass)
	else:
		_show_message_dialog("Failed to delete enemy. Error code: %d" % error, "OK", func(): pass)
