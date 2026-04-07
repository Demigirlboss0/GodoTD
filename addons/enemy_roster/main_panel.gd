@tool
extends Control

var plugin: Object

var enemy_list: ItemList
var add_enemy_btn: Button
var settings_btn: Button

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

var current_enemy: Resource
var is_new_enemy: bool = false
var visual_entries: Dictionary = {}
var edit_form_panel: ScrollContainer
var settings_panel: Control
var settings_vbox: VBoxContainer
var tag_autocomplete: OptionButton

const DEFAULT_MAX_VALUE := 999999

func _ready() -> void:
	_build_ui()

func set_plugin(p: Object) -> void:
	plugin = p
	if plugin and "resource_types_changed" in plugin:
		plugin.resource_types_changed.connect(_on_resource_types_changed)
		plugin.settings_changed.connect(_on_settings_changed)
	plugin.settings_changed.emit()

func _on_resource_types_changed() -> void:
	_load_rewards(current_enemy)
	if settings_vbox:
		_refresh_settings_resource_types()

func _on_settings_changed() -> void:
	_refresh_enemy_list()
	if settings_vbox:
		_refresh_settings_tags()
		_update_settings_panel_error()

func _refresh_settings_resource_types() -> void:
	if not settings_vbox:
		return
	var list_container := settings_vbox.get_node("resource_types_list") as VBoxContainer
	if list_container:
		_populate_resource_types_list(list_container)

func _refresh_settings_tags() -> void:
	if not settings_vbox:
		return
	var tags_list := settings_vbox.get_node("tags_list") as VBoxContainer
	if tags_list:
		_populate_tags_list(tags_list)

func _exit_tree() -> void:
	if plugin and "resource_types_changed" in plugin:
		if plugin.resource_types_changed.is_connected(_on_resource_types_changed):
			plugin.resource_types_changed.disconnect(_on_resource_types_changed)
		if plugin.settings_changed.is_connected(_on_settings_changed):
			plugin.settings_changed.disconnect(_on_settings_changed)

func _build_ui() -> void:
	var hsplit := HSplitContainer.new() as HSplitContainer
	hsplit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hsplit.add_theme_constant_override("separation", 8)
	add_child(hsplit)

	var left_panel := VBoxContainer.new() as VBoxContainer
	left_panel.custom_minimum_size.x = 200
	hsplit.add_child(left_panel)

	var header := HBoxContainer.new() as HBoxContainer
	left_panel.add_child(header)

	add_enemy_btn = Button.new()
	add_enemy_btn.text = "+ Add Enemy"
	add_enemy_btn.pressed.connect(_on_add_enemy_pressed)
	header.add_child(add_enemy_btn)

	enemy_list = ItemList.new()
	enemy_list.custom_minimum_size.y = 200
	enemy_list.item_selected.connect(_on_enemy_selected)
	left_panel.add_child(enemy_list)
	
	var form_container: VBoxContainer
	edit_form_panel = ScrollContainer.new()
	edit_form_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	edit_form_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(edit_form_panel)
	
	form_container = VBoxContainer.new() as VBoxContainer
	form_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	form_container.add_theme_constant_override("separation", 8)
	edit_form_panel.add_child(form_container)
	
	var settings_sep := VSeparator.new() as VSeparator
	hsplit.add_child(settings_sep)
	
	var settings_panel := VBoxContainer.new() as VBoxContainer
	settings_panel.custom_minimum_size.x = 250
	hsplit.add_child(settings_panel)

	var name_label := Label.new() as Label
	name_label.text = "Enemy Name"
	form_container.add_child(name_label)

	enemy_name_input = LineEdit.new()
	enemy_name_input.placeholder_text = "Enter enemy name"
	enemy_name_input.text_changed.connect(_on_name_changed)
	form_container.add_child(enemy_name_input)

	var filename_label := Label.new() as Label
	filename_label.text = "Resource Filename"
	form_container.add_child(filename_label)

	filename_input = LineEdit.new()
	filename_input.placeholder_text = "Auto-derived filename"
	form_container.add_child(filename_input)

	var health_label := Label.new() as Label
	health_label.text = "Max Health"
	form_container.add_child(health_label)

	max_health_input = SpinBox.new()
	max_health_input.min_value = 0
	max_health_input.max_value = DEFAULT_MAX_VALUE
	max_health_input.value = 100
	form_container.add_child(max_health_input)

	var speed_label := Label.new() as Label
	speed_label.text = "Speed"
	form_container.add_child(speed_label)

	speed_input = SpinBox.new()
	speed_input.min_value = 0
	speed_input.max_value = DEFAULT_MAX_VALUE
	speed_input.value = 100
	form_container.add_child(speed_input)

	var damage_label := Label.new() as Label
	damage_label.text = "Damage"
	form_container.add_child(damage_label)

	damage_input = SpinBox.new()
	damage_input.min_value = 0
	damage_input.max_value = DEFAULT_MAX_VALUE
	damage_input.value = 1
	form_container.add_child(damage_input)

	var visuals_header := Label.new() as Label
	visuals_header.text = "Visuals"
	form_container.add_child(visuals_header)

	visuals_container = VBoxContainer.new()
	form_container.add_child(visuals_container)

	var add_visual_btn := Button.new() as Button
	add_visual_btn.text = "+ Add Visual"
	add_visual_btn.pressed.connect(_on_add_visual_pressed)
	form_container.add_child(add_visual_btn)

	var rewards_header := Label.new() as Label
	rewards_header.text = "Rewards"
	form_container.add_child(rewards_header)

	rewards_container = VBoxContainer.new()
	form_container.add_child(rewards_container)

	var tags_header := Label.new() as Label
	tags_header.text = "Tags"
	form_container.add_child(tags_header)

	tags_container = VBoxContainer.new()
	form_container.add_child(tags_container)

	var tag_input_container := HBoxContainer.new() as HBoxContainer
	form_container.add_child(tag_input_container)
	
	tag_input = LineEdit.new()
	tag_input.placeholder_text = "Add tag (press Enter)"
	tag_input.text_submitted.connect(_on_tag_submitted)
	tag_input_container.add_child(tag_input)
	
	tag_autocomplete = OptionButton.new()
	tag_autocomplete.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag_autocomplete.custom_minimum_size.x = 40
	tag_autocomplete.visible = false
	tag_autocomplete.item_selected.connect(_on_autocomplete_selected)
	tag_input_container.add_child(tag_autocomplete)
	
	tag_input.text_changed.connect(_on_tag_text_changed)

	save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	form_container.add_child(save_btn)
	
	_build_settings_ui(settings_panel)

	_refresh_enemy_list()

func _refresh_enemy_list() -> void:
	if not enemy_list:
		return
	enemy_list.clear()
	if not plugin or not plugin.settings:
		return
	
	var dir := DirAccess.open(plugin.settings.output_directory) as DirAccess
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and file_name != "EnemyData.tres":
			var path := (plugin.settings.output_directory + file_name) as String
			var res := load(path) as Resource
			if res and "enemy_name" in res:
				var idx := enemy_list.add_item(res.enemy_name) as int
				enemy_list.set_item_metadata(idx, path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_add_enemy_pressed() -> void:
	current_enemy = null
	is_new_enemy = true
	_clear_form()

func _on_enemy_selected(index: int) -> void:
	if not plugin or not plugin.settings:
		return
	
	var path: String = enemy_list.get_item_metadata(index) as String
	if path == "" or not FileAccess.file_exists(path):
		return
	
	current_enemy = load(path)
	is_new_enemy = false
	_load_enemy_to_form(current_enemy)

func _load_enemy_to_form(enemy: Resource) -> void:
	enemy_name_input.text = enemy.enemy_name if enemy else ""
	filename_input.text = _get_filename_from_path(current_enemy.resource_path) if current_enemy else ""
	max_health_input.value = enemy.max_health if enemy else 100.0
	speed_input.value = enemy.speed if enemy else 100.0
	damage_input.value = enemy.damage if enemy else 1.0
	
	_load_visuals(enemy.visuals if enemy else {})
	_load_tags(enemy.target_tags if enemy else [])
	_load_rewards(enemy)

func _get_filename_from_path(path: String) -> String:
	return path.get_file()

func _clear_form() -> void:
	enemy_name_input.text = ""
	filename_input.text = ""
	max_health_input.value = 100
	speed_input.value = 100
	damage_input.value = 1
	
	_clear_visuals()
	_clear_tags()
	_load_rewards(null)

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
	remove_btn.text = "×"
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
	
	if plugin.settings.project_mode == 0:
		dialog.filters = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.tres"]
	else:
		dialog.filters = ["*.tres", "*.obj", "*.gltf", "*.glb"]
	
	EditorInterface.get_base_control().add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var res := load(path) as Resource
		visual_entries[entry_id]["value"] = res
		btn.text = path.get_file()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2(800, 600))

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
	
	if not tag in plugin.settings.known_tags:
		plugin.settings.known_tags.append(tag)
		plugin.save_settings()
	
	_add_tag_entry(tag)
	tag_input.text = ""

func _add_tag_entry(tag: String) -> void:
	var container := HBoxContainer.new() as HBoxContainer
	tags_container.add_child(container)
	
	var label := Label.new() as Label
	label.text = tag
	container.add_child(label)
	
	var remove_btn := Button.new() as Button
	remove_btn.text = "×"
	remove_btn.pressed.connect(func():
		container.queue_free()
	)
	container.add_child(remove_btn)

func _on_tag_text_changed(text: String) -> void:
	if not plugin or not plugin.settings:
		return
	
	text = text.strip_edges()
	if text == "":
		tag_autocomplete.visible = false
		return
	
	var matches: Array[String] = []
	for known_tag in plugin.settings.known_tags:
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

func _load_rewards(enemy: Resource) -> void:
	for child in rewards_container.get_children():
		child.queue_free()
	
	for resource_type in plugin.settings.resource_types:
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

func _on_name_changed(new_name: String) -> void:
	filename_input.text = _derive_filename(new_name)

func _derive_filename(name: String) -> String:
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

func _on_output_directory_changed(text: String) -> void:
	var is_valid := _validate_output_directory(text)
	plugin.settings.output_directory = text
	plugin.save_settings()
	
	if settings_vbox:
		var error_label := settings_vbox.get_node("output_error") as Label
		if error_label:
			error_label.visible = not is_valid
			error_label.text = "Invalid path. Must start with 'res://'" if not is_valid else ""

func _validate_output_directory(path: String) -> bool:
	if path == "":
		return false
	if not path.begins_with("res://"):
		return false
	return true

func _on_save_pressed() -> void:
	if enemy_name_input.text.strip_edges() == "":
		_show_message_dialog("Please enter an enemy name.", "OK", func(): pass)
		return
	
	var filename := filename_input.text.strip_edges() as String
	if filename == "":
		filename = _derive_filename(enemy_name_input.text)
	
	if not filename.ends_with(".tres"):
		filename += ".tres"
	
	var output_path := plugin.settings.output_directory + filename as String
	
	if FileAccess.file_exists(output_path) and is_new_enemy:
		_show_overwrite_confirmation(output_path)
	else:
		_save_enemy(output_path)

func _show_overwrite_confirmation(path: String) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "A resource named %s already exists. Overwrite it?" % path.get_file()
	dialog.ok_button_text = "Overwrite"
	dialog.cancel_button_text = "Cancel"
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		_save_enemy(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

func _save_enemy(path: String) -> void:
	var class_path := plugin.settings.output_directory + "EnemyData.gd" as String
	var enemy_class := load(class_path) as Script
	var enemy := enemy_class.new() as Resource
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
		if child is HBoxContainer:
			var label := child.get_child(0) as Label
			if label:
				tags.append(label.text)
	enemy.set("target_tags", tags)
	
	for resource_type in plugin.settings.resource_types:
		for child in rewards_container.get_children():
			if child is HBoxContainer:
				var input: SpinBox = child.get_child(1) as SpinBox
				if input and input.name == "reward_" + resource_type:
					enemy.set("reward_" + resource_type, int(input.value))
	
	ResourceSaver.save(enemy, path)
	EditorInterface.get_resource_filesystem().scan()
	
	is_new_enemy = false
	current_enemy = enemy
	_refresh_enemy_list()
	_show_message_dialog("Enemy saved successfully!", "OK", func(): pass)

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

func _on_settings_pressed() -> void:
	pass

func _build_settings_ui(parent: Control) -> void:
	var settings_container := VBoxContainer.new() as VBoxContainer
	settings_container.add_theme_constant_override("separation", 4)
	parent.add_child(settings_container)
	settings_vbox = settings_container
	
	var settings_label := Label.new() as Label
	settings_label.text = "Settings"
	settings_container.add_child(settings_label)
	
	var project_mode_option := OptionButton.new() as OptionButton
	project_mode_option.add_item("2D", 0)
	project_mode_option.add_item("3D", 1)
	project_mode_option.selected = plugin.settings.project_mode
	project_mode_option.item_selected.connect(func(idx: int):
		plugin.settings.project_mode = idx
		plugin.save_settings()
	)
	project_mode_option.custom_minimum_size.y = 30
	settings_container.add_child(project_mode_option)
	
	var output_dir_input := LineEdit.new() as LineEdit
	output_dir_input.text = plugin.settings.output_directory
	output_dir_input.text_changed.connect(_on_output_directory_changed)
	output_dir_input.custom_minimum_size.y = 30
	settings_container.add_child(output_dir_input)
	
	var output_error_label := Label.new() as Label
	output_error_label.name = "output_error"
	output_error_label.modulate = Color(1, 0.3, 0.3)
	output_error_label.visible = false
	output_error_label.add_theme_font_size_override("font_size", 10)
	settings_container.add_child(output_error_label)
	_update_settings_panel_error()
	
	var resource_types_label := Label.new() as Label
	resource_types_label.text = "Resource Types"
	settings_container.add_child(resource_types_label)
	
	var resource_types_list := VBoxContainer.new() as VBoxContainer
	resource_types_list.name = "resource_types_list"
	settings_container.add_child(resource_types_list)
	_populate_resource_types_list(resource_types_list)
	
	var add_resource_type_btn := Button.new() as Button
	add_resource_type_btn.text = "+ Add"
	add_resource_type_btn.pressed.connect(_show_add_resource_type_dialog)
	add_resource_type_btn.custom_minimum_size.y = 24
	settings_container.add_child(add_resource_type_btn)
	
	var tags_label := Label.new() as Label
	tags_label.text = "Known Tags"
	settings_container.add_child(tags_label)
	
	var tags_list := VBoxContainer.new() as VBoxContainer
	tags_list.name = "tags_list"
	settings_container.add_child(tags_list)
	_populate_tags_list(tags_list)
	
	var add_tag_btn := Button.new() as Button
	add_tag_btn.text = "+ Add"
	add_tag_btn.pressed.connect(_show_add_tag_dialog)
	add_tag_btn.custom_minimum_size.y = 24
	settings_container.add_child(add_tag_btn)

func _build_settings_panel() -> void:
	if settings_panel and is_instance_valid(settings_panel):
		settings_panel.bring_to_front()
		return
	
	var container := PanelContainer.new() as PanelContainer
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.custom_minimum_size = Vector2i(320, 450)
	container.visible = true
	
	var overlay := Control.new() as Control
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	EditorInterface.get_base_control().add_child(overlay)
	overlay.add_child(container)
	
	var close_btn := Button.new() as Button
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): 
		overlay.queue_free()
	)
	var close_container := HBoxContainer.new() as HBoxContainer
	close_container.alignment = BoxContainer.ALIGNMENT_CENTER
	close_container.add_child(close_btn)
	
	var vbox := VBoxContainer.new() as VBoxContainer
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_theme_constant_override("margin_top", 12)
	vbox.add_theme_constant_override("margin_left", 12)
	vbox.add_theme_constant_override("margin_right", 12)
	vbox.add_theme_constant_override("margin_bottom", 12)
	vbox.custom_minimum_size.x = 296
	container.add_child(vbox)
	settings_vbox = vbox
	
	var project_mode_label := Label.new() as Label
	project_mode_label.text = "Project Mode"
	vbox.add_child(project_mode_label)
	
	var project_mode_option := OptionButton.new() as OptionButton
	project_mode_option.add_item("2D", 0)
	project_mode_option.add_item("3D", 1)
	project_mode_option.selected = plugin.settings.project_mode
	project_mode_option.item_selected.connect(func(idx: int):
		plugin.settings.project_mode = idx
		plugin.save_settings()
	)
	vbox.add_child(project_mode_option)
	
	var separator := HSeparator.new() as HSeparator
	vbox.add_child(separator)
	
	var output_dir_label := Label.new() as Label
	output_dir_label.text = "Output Directory"
	vbox.add_child(output_dir_label)
	
	var output_dir_input := LineEdit.new() as LineEdit
	output_dir_input.text = plugin.settings.output_directory
	output_dir_input.text_changed.connect(_on_output_directory_changed)
	vbox.add_child(output_dir_input)
	
	var output_error_label := Label.new() as Label
	output_error_label.name = "output_error"
	output_error_label.modulate = Color(1, 0.3, 0.3)
	output_error_label.visible = false
	vbox.add_child(output_error_label)
	
	var separator2 := HSeparator.new() as HSeparator
	vbox.add_child(separator2)
	
	var resource_types_label := Label.new() as Label
	resource_types_label.text = "Resource Types"
	vbox.add_child(resource_types_label)
	
	var resource_types_list := VBoxContainer.new() as VBoxContainer
	resource_types_list.name = "resource_types_list"
	vbox.add_child(resource_types_list)
	_populate_resource_types_list(resource_types_list)
	
	var add_resource_type_btn := Button.new() as Button
	add_resource_type_btn.text = "+ Add Resource Type"
	add_resource_type_btn.pressed.connect(_show_add_resource_type_dialog)
	vbox.add_child(add_resource_type_btn)
	
	var separator3 := HSeparator.new() as HSeparator
	vbox.add_child(separator3)
	
	var tags_label := Label.new() as Label
	tags_label.text = "Known Tags"
	vbox.add_child(tags_label)
	
	var tags_list := VBoxContainer.new() as VBoxContainer
	tags_list.name = "tags_list"
	vbox.add_child(tags_list)
	_populate_tags_list(tags_list)
	
	var add_tag_btn := Button.new() as Button
	add_tag_btn.text = "+ Add Tag"
	add_tag_btn.pressed.connect(_show_add_tag_dialog)
	vbox.add_child(add_tag_btn)
	
	var separator4 := HSeparator.new() as HSeparator
	vbox.add_child(separator4)
	
	vbox.add_child(close_container)
	
	settings_panel = container as Control
	_update_settings_panel_error()

func _populate_resource_types_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	for rt in plugin.settings.resource_types:
		var rt_container := HBoxContainer.new() as HBoxContainer
		container.add_child(rt_container)
		
		var rt_label := Label.new() as Label
		rt_label.text = rt
		rt_container.add_child(rt_label)
		
		var rt_val := rt as String
		var remove_btn := Button.new() as Button
		remove_btn.text = "×"
		remove_btn.pressed.connect(func():
			_show_confirm_dialog("Remove Resource Type", "Remove \"%s\"? This will also remove the reward field from all enemies." % rt_val, func():
				plugin.settings.resource_types.erase(rt_val)
				plugin.regenerate_enemy_data_class()
				plugin.save_settings()
			)
		)
		rt_container.add_child(remove_btn)

func _populate_tags_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	for tag in plugin.settings.known_tags:
		var tag_container := HBoxContainer.new() as HBoxContainer
		container.add_child(tag_container)
		
		var tag_label := Label.new() as Label
		tag_label.text = tag
		tag_container.add_child(tag_label)
		
		var tag_val := tag as String
		var remove_btn := Button.new() as Button
		remove_btn.text = "×"
		remove_btn.pressed.connect(func():
			_show_confirm_dialog("Remove Tag", "Remove \"%s\" from known tags?" % tag_val, func():
				plugin.settings.known_tags.erase(tag_val)
				plugin.save_settings()
			)
		)
		tag_container.add_child(remove_btn)

func _update_settings_panel_error() -> void:
	if not settings_vbox:
		return
	
	var error_label := settings_vbox.get_node("output_error") as Label
	if error_label:
		var is_valid := _validate_output_directory(plugin.settings.output_directory)
		error_label.visible = not is_valid
		error_label.text = "Invalid path. Must start with 'res://'" if not is_valid else ""

func _show_input_dialog(title: String, message: String, placeholder: String, on_confirm: Callable) -> void:
	var window := Window.new() as Window
	window.title = title
	window.size = Vector2i(350, 150)
	window.transient = true
	window.exclusive = true
	EditorInterface.get_base_control().add_child(window)
	var screen_size: Vector2 = EditorInterface.get_editor_main_screen().size as Vector2
	var window_size: Vector2 = window.size as Vector2
	window.position = (screen_size - window_size) / 2
	
	var vbox := VBoxContainer.new() as VBoxContainer
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_top", 16)
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
	cancel_btn.pressed.connect(func():
		window.queue_free()
	)
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

func _show_add_resource_type_dialog() -> void:
	var on_confirm := func(new_type: String):
		if new_type != "" and not new_type in plugin.settings.resource_types:
			plugin.settings.resource_types.append(new_type)
			plugin.regenerate_enemy_data_class()
			plugin.save_settings()
	_show_input_dialog("Add Resource Type", "Enter resource type name:", "e.g. gold, food, mana", on_confirm)

func _show_add_tag_dialog() -> void:
	var on_confirm := func(new_tag: String):
		if new_tag != "" and not new_tag in plugin.settings.known_tags:
			plugin.settings.known_tags.append(new_tag)
			plugin.save_settings()
	_show_input_dialog("Add Tag", "Enter tag name:", "e.g. camo, flying", on_confirm)
