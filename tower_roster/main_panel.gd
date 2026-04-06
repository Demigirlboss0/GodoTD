@tool
extends Control

var plugin: EditorPlugin
var settings: TowerRosterSettings

var tower_list_container: VBoxContainer
var edit_form: VBoxContainer
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
var visuals_list: VBoxContainer
var costs_list: VBoxContainer
var target_mode_option: OptionButton
var target_tags_input: LineEdit
var target_tags_list: VBoxContainer
var save_button: Button

var current_tower: Resource
var is_new_tower: bool = false

func _ready() -> void:
	_setup_ui_references()
	_connect_signals()
	_refresh_tower_list()
	_populate_form_defaults()
	_form_visible(false)

func _setup_ui_references() -> void:
	tower_list_container = $HBoxContainer/LeftPanel/TowerList/ListContainer
	edit_form = $HBoxContainer/RightPanel/EditForm
	tower_name_input = $HBoxContainer/RightPanel/EditForm/TowerNameRow/TowerNameInput
	filename_input = $HBoxContainer/RightPanel/EditForm/FilenameRow/FilenameInput
	range_input = $HBoxContainer/RightPanel/EditForm/StatsContainer/RangeRow/RangeInput
	damage_input = $HBoxContainer/RightPanel/EditForm/StatsContainer/DamageRow/DamageInput
	fire_rate_input = $HBoxContainer/RightPanel/EditForm/StatsContainer/FireRateRow/FireRateInput
	pierce_input = $HBoxContainer/RightPanel/EditForm/StatsContainer/PierceRow/PierceInput
	multishot_input = $HBoxContainer/RightPanel/EditForm/StatsContainer/MultishotRow/MultishotInput
	traversal_time_input = $HBoxContainer/RightPanel/EditForm/StatsContainer/TraversalTimeRow/TraversalTimeInput
	attack_style_option = $HBoxContainer/RightPanel/EditForm/AttackStyleRow/AttackStyleOption
	projectile_picker = $HBoxContainer/RightPanel/EditForm/ProjectileRow/ProjectilePicker
	visuals_list = $HBoxContainer/RightPanel/EditForm/VisualsSection/VisualsList
	costs_list = $HBoxContainer/RightPanel/EditForm/CostsSection/CostsList
	target_mode_option = $HBoxContainer/RightPanel/EditForm/TargetModeRow/TargetModeOption
	target_tags_input = $HBoxContainer/RightPanel/EditForm/TargetTagsSection/TargetTagsInput
	target_tags_list = $HBoxContainer/RightPanel/EditForm/TargetTagsSection/TargetTagsList
	save_button = $HBoxContainer/RightPanel/EditForm/SaveButton

func _connect_signals() -> void:
	$HBoxContainer/LeftPanel/AddTowerButton.pressed.connect(_on_add_tower)
	$HBoxContainer/LeftPanel/Header/SettingsButton.pressed.connect(_on_settings)
	tower_name_input.text_changed.connect(_on_tower_name_changed)
	target_tags_input.text_submitted.connect(_on_tag_submitted)
	projectile_picker.pressed.connect(_on_projectile_picker_pressed)
	$HBoxContainer/RightPanel/EditForm/VisualsSection/AddVisualButton.pressed.connect(_on_add_visual)
	$HBoxContainer/RightPanel/EditForm/CostsSection/AddCostButton.pressed.connect(_on_add_resource_type)
	save_button.pressed.connect(_on_save)

func _populate_form_defaults() -> void:
	attack_style_option.clear()
	attack_style_option.add_item("LINEAR", 0)
	attack_style_option.add_item("RADIAL", 1)
	attack_style_option.selected = 0

	target_mode_option.clear()
	target_mode_option.add_item("WHITELIST", 0)
	target_mode_option.add_item("BLACKLIST", 1)
	target_mode_option.selected = 0

func _refresh_tower_list() -> void:
	for child in tower_list_container.get_children():
		child.queue_free()

	var towers = plugin.get_all_tower_resources()
	for tower in towers:
		_add_tower_list_item(tower)

func _add_tower_list_item(tower: Resource) -> void:
	var item = HBoxContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var click_area = Control.new()
	click_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	click_area.mouse_entered.connect(func(): click_area.modulate = Color(0.8, 0.8, 0.8))
	click_area.mouse_exited.connect(func(): click_area.modulate = Color(1, 1, 1))
	click_area.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_load_tower_into_form(tower)
	)
	item.add_child(click_area)
	
	var name_label = Label.new()
	name_label.text = tower.tower_name if not tower.tower_name.is_empty() else "Unnamed Tower"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	click_area.add_child(name_label)
	
	var delete_btn = Button.new()
	delete_btn.text = "X"
	delete_btn.pressed.connect(func(): _delete_tower(tower, item))
	item.add_child(delete_btn)
	
	tower_list_container.add_child(item)

func _form_visible(visible: bool) -> void:
	edit_form.visible = visible
	$HBoxContainer/RightPanel/EditForm/FormTitle.text = "New Tower" if is_new_tower else "Edit Tower"

func _load_tower_into_form(tower: Resource) -> void:
	current_tower = load(tower.resource_path)
	is_new_tower = false
	
	filename_input.text = current_tower.resource_path.get_file()
	range_input.value = current_tower.range
	damage_input.value = current_tower.damage
	fire_rate_input.value = current_tower.fire_rate
	pierce_input.value = current_tower.pierce
	multishot_input.value = current_tower.multishot
	traversal_time_input.value = current_tower.traversal_time
	attack_style_option.selected = current_tower.attack_style
	target_mode_option.selected = current_tower.target_mode
	
	if current_tower.projectile_scene:
		projectile_picker.text = current_tower.projectile_scene.resource_path.get_file()
	else:
		projectile_picker.text = "Select..."
	
	_refresh_visuals_list(current_tower.visuals)
	_refresh_costs_list(current_tower)
	_refresh_tags_list(current_tower.target_tags)
	
	_form_visible(true)

func _refresh_visuals_list(visuals: Dictionary) -> void:
	for child in visuals_list.get_children():
		child.queue_free()
	
	for key in visuals.keys():
		_add_visual_row(key, visuals[key])

func _add_visual_row(key: String = "", value: Variant = null) -> void:
	var row = HBoxContainer.new()
	
	var key_input = LineEdit.new()
	key_input.placeholder_text = "Key"
	key_input.text = key
	key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_input)
	
	var value_picker = Button.new()
	value_picker.text = "Select..." if value == null else value.resource_path.get_file() if value else "Select..."
	value_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_picker.set_meta("visual_value", value)
	
	value_picker.pressed.connect(func():
		_pick_resource(_get_visual_resource_type(), func(res):
			value_picker.set_meta("visual_value", res)
			value_picker.text = res.resource_path.get_file() if res else "Select..."
		)
	)
	row.add_child(value_picker)
	
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		row.queue_free()
	)
	row.add_child(remove_btn)
	
	visuals_list.add_child(row)

func _get_visual_resource_type() -> String:
	var project_mode = settings.project_mode
	return "Texture2D" if project_mode == 0 else "Mesh"

func _refresh_costs_list(tower: Resource) -> void:
	for child in costs_list.get_children():
		child.queue_free()
	
	if settings.resource_types.is_empty():
		return
	
	for rt in settings.resource_types:
		_add_cost_row(rt, tower)

func _add_cost_row(resource_type: String, tower: Resource) -> void:
	var row = HBoxContainer.new()
	
	var label = Label.new()
	label.text = resource_type + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	
	var input = SpinBox.new()
	input.min_value = 0
	input.max_value = 999999
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var field_name = "cost_" + resource_type.to_lower().replace(" ", "_")
	var existing_val = tower.get(field_name)
	if existing_val != null:
		input.value = float(existing_val)
	
	input.value_changed.connect(func(val):
		tower.set(field_name, int(val))
	)
	
	row.add_child(input)
	
	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.tooltip_text = "Remove this resource type from all towers"
	remove_btn.pressed.connect(func():
		_remove_resource_type(resource_type, null)
	)
	row.add_child(remove_btn)
	
	costs_list.add_child(row)

func _refresh_tags_list(tags: Array[String]) -> void:
	for child in target_tags_list.get_children():
		child.queue_free()
	
	for tag in tags:
		_add_tag_item(tag)

func _add_tag_item(tag: String) -> void:
	var row = HBoxContainer.new()
	
	var label = Label.new()
	label.text = tag
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var is_unknown = not tag in settings.known_tags
	if is_unknown:
		label.modulate = Color(1, 0.8, 0, 1)
	
	row.add_child(label)
	
	var warning = Label.new()
	warning.text = "⚠" if is_unknown else ""
	warning.tooltip_text = "Unknown tag - will be added to known tags" if is_unknown else ""
	row.add_child(warning)
	
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		row.queue_free()
	)
	row.add_child(remove_btn)
	
	target_tags_list.add_child(row)

func _on_add_tower() -> void:
	var output_dir = plugin.get_output_directory()
	var TowerData = load(output_dir.path_join("TowerData.gd"))
	if TowerData:
		current_tower = TowerData.new()
	else:
		current_tower = Resource.new()
	is_new_tower = true
	
	tower_name_input.text = ""
	filename_input.text = ""
	range_input.value = 10.0
	damage_input.value = 10.0
	fire_rate_input.value = 1.0
	pierce_input.value = 1
	multishot_input.value = 1
	traversal_time_input.value = 0.0
	attack_style_option.selected = 0
	projectile_picker.text = "Select..."
	
	_refresh_visuals_list({})
	_refresh_costs_list(current_tower)
	_refresh_tags_list([])
	
	_form_visible(true)

func _on_settings() -> void:
	_show_settings_popup()

func _show_settings_popup() -> void:
	var window = Window.new()
	window.title = "Tower Roster Settings"
	window.size = Vector2i(500, 550)
	window.close_requested.connect(func(): window.queue_free())
	EditorInterface.get_base_control().add_child(window)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	window.add_child(vbox)
	
	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var mode_row = HBoxContainer.new()
	vbox.add_child(mode_row)
	var mode_label = Label.new()
	mode_label.text = "Project Mode:"
	mode_row.add_child(mode_label)
	var mode_option = OptionButton.new()
	mode_option.add_item("2D", 0)
	mode_option.add_item("3D", 1)
	mode_option.selected = 0 if settings.project_mode == 0 else 1
	mode_row.add_child(mode_option)
	
	var output_row = HBoxContainer.new()
	vbox.add_child(output_row)
	var output_label = Label.new()
	output_label.text = "Output Directory:"
	output_row.add_child(output_label)
	var output_input = LineEdit.new()
	output_input.text = settings.output_directory
	output_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(output_input)
	
	var resource_types_label = Label.new()
	resource_types_label.text = "Resource Types"
	vbox.add_child(resource_types_label)
	
	var resource_types_scroll = ScrollContainer.new()
	resource_types_scroll.custom_minimum_size = Vector2(0, 80)
	resource_types_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(resource_types_scroll)
	var resource_types_list = VBoxContainer.new()
	resource_types_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_types_scroll.add_child(resource_types_list)
	
	for rt in settings.resource_types:
		var rt_row = HBoxContainer.new()
		var rt_label = Label.new()
		rt_label.text = rt
		rt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt_row.add_child(rt_label)
		var rt_remove = Button.new()
		rt_remove.text = "X"
		rt_remove.pressed.connect(func(): _remove_resource_type(rt, rt_row))
		rt_row.add_child(rt_remove)
		resource_types_list.add_child(rt_row)
	
	var add_resource_type_btn = Button.new()
	add_resource_type_btn.text = "+ Add Resource Type"
	add_resource_type_btn.pressed.connect(func(): _prompt_add_resource_type_inline())
	vbox.add_child(add_resource_type_btn)
	
	var known_tags_label = Label.new()
	known_tags_label.text = "Known Tags"
	vbox.add_child(known_tags_label)
	
	var tags_scroll = ScrollContainer.new()
	tags_scroll.custom_minimum_size = Vector2(0, 80)
	tags_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tags_scroll)
	var tags_list = VBoxContainer.new()
	tags_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tags_scroll.add_child(tags_list)
	
	for tag in settings.known_tags:
		var tag_row = HBoxContainer.new()
		var tag_label = Label.new()
		tag_label.text = tag
		tag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_row.add_child(tag_label)
		var tag_remove = Button.new()
		tag_remove.text = "X"
		tag_remove.pressed.connect(func(): _remove_known_tag(tag, tag_row))
		tag_row.add_child(tag_remove)
		tags_list.add_child(tag_row)
	
	var buttons_row = HBoxContainer.new()
	vbox.add_child(buttons_row)
	buttons_row.alignment = BoxContainer.ALIGNMENT_END
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): window.queue_free())
	buttons_row.add_child(cancel_btn)
	
	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func():
		settings.project_mode = mode_option.selected
		settings.output_directory = output_input.text
		plugin.save_settings()
		plugin.regenerate_tower_data_class()
		_refresh_tower_list()
		window.queue_free()
	)
	buttons_row.add_child(save_btn)

	window.popup_centered()

func _remove_resource_type(type_name: String, row: Control) -> void:
	var field_name = "cost_" + type_name.to_lower().replace(" ", "_")
	var towers_with_value: Array[Resource] = []
	
	for tower in plugin.get_all_tower_resources():
		if tower.get(field_name) != null and tower.get(field_name) != 0:
			towers_with_value.append(tower)
	
	var window = Window.new()
	window.title = "Remove Resource Type"
	window.size = Vector2i(400, 150)
	window.close_requested.connect(func(): window.queue_free())
	EditorInterface.get_base_control().add_child(window)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	window.add_child(vbox)
	
	if towers_with_value.size() > 0:
		var warn_label = Label.new()
		warn_label.text = str(towers_with_value.size()) + " tower(s) have non-zero \"" + type_name + "\" cost. These will be set to 0."
		warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(warn_label)
	
	var desc_label = Label.new()
	desc_label.text = "Remove \"" + type_name + "\" from the resource type list?"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	var buttons = HBoxContainer.new()
	vbox.add_child(buttons)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): window.queue_free())
	buttons.add_child(cancel)
	
	var remove = Button.new()
	remove.text = "Remove"
	remove.pressed.connect(func():
		var resource_types = settings.resource_types.duplicate()
		resource_types.erase(type_name)
		settings.resource_types = resource_types
		
		for tower in towers_with_value:
			tower.set(field_name, 0)
			plugin.save_tower(tower, tower.get("tower_name"))
		
		if row:
			row.queue_free()
		plugin.save_settings()
		plugin.regenerate_tower_data_class()
		window.queue_free()
	)
	buttons.add_child(remove)
	
	window.popup_centered()

func _on_tower_name_changed(text: String) -> void:
	if is_new_tower or filename_input.text.is_empty():
		var derived = _derive_filename(text)
		filename_input.text = derived + ".tres"

func _derive_filename(tower_name: String) -> String:
	var cleaned = ""
	for c in tower_name:
		if c.is_valid_identifier() or c == " ":
			cleaned += c
	
	var words = cleaned.split(" ")
	var title_cased = ""
	for word in words:
		if word.length() > 0:
			title_cased += word[0].to_upper() + word.substr(1).to_lower()
	
	if title_cased.is_empty():
		return "TowerData"
	
	return title_cased + "TowerData"

func _sanitize_filename(filename: String) -> String:
	var result = ""
	for c in filename:
		if c.is_valid_identifier() or c == "." or c == "-" or c == "_":
			result += c
	return result

func _on_tag_submitted(text: String) -> void:
	if text.is_empty():
		return
	
	var known_tags = settings.known_tags.duplicate()
	if not text in known_tags:
		known_tags.append(text)
		settings.known_tags = known_tags
		plugin.save_settings()
	
	_add_tag_item(text)
	target_tags_input.text = ""

func _on_projectile_picker_pressed() -> void:
	_pick_resource("PackedScene", func(res):
		if res:
			current_tower.projectile_scene = res
			projectile_picker.text = res.resource_path.get_file()
	)

func _on_add_visual() -> void:
	_add_visual_row()

func _on_add_resource_type() -> void:
	_prompt_add_resource_type_inline()

func _prompt_add_resource_type_inline() -> void:
	var window = Window.new()
	window.title = "Add Resource Type"
	window.size = Vector2i(300, 130)
	window.close_requested.connect(func(): window.queue_free())
	EditorInterface.get_base_control().add_child(window)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	window.add_child(vbox)
	
	var label = Label.new()
	label.text = "Enter resource type name:"
	vbox.add_child(label)
	
	var input = LineEdit.new()
	input.placeholder_text = "Resource type name"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(input)
	
	var buttons = HBoxContainer.new()
	vbox.add_child(buttons)
	
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): window.queue_free())
	buttons.add_child(cancel)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var add = Button.new()
	add.text = "Add"
	add.pressed.connect(func():
		if not input.text.is_empty():
			var resource_types = settings.resource_types.duplicate()
			resource_types.append(input.text)
			settings.resource_types = resource_types
			plugin.save_settings()
			plugin.regenerate_tower_data_class()
			window.queue_free()
			_refresh_costs_list(current_tower)
	)
	buttons.add_child(add)
	
	input.text_submitted.connect(func(_text):
		add.pressed.emit()
	)
	input.grab_focus()
	window.popup_centered()

func _remove_known_tag(tag: String, row: Control) -> void:
	var window = Window.new()
	window.title = "Remove Tag?"
	window.size = Vector2i(300, 120)
	window.close_requested.connect(func(): window.queue_free())
	EditorInterface.get_base_control().add_child(window)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	window.add_child(vbox)
	
	var label = Label.new()
	label.text = "Remove \"" + tag + "\" from known tags?"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label)
	
	var buttons = HBoxContainer.new()
	vbox.add_child(buttons)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): window.queue_free())
	buttons.add_child(cancel)
	
	var remove = Button.new()
	remove.text = "Remove"
	remove.pressed.connect(func():
		var known_tags = settings.known_tags.duplicate()
		known_tags.erase(tag)
		settings.known_tags = known_tags
		row.queue_free()
		plugin.save_settings()
		window.queue_free()
	)
	buttons.add_child(remove)
	
	window.popup_centered()

func _pick_resource(type_filter: String, callback: Callable) -> void:
	var dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	
	if type_filter == "Texture2D":
		dialog.filters = ["*.tres"]
	elif type_filter == "Mesh":
		dialog.filters = ["*.obj", "*.fbx", "*.gltf", "*.glb", "*.tres"]
	elif type_filter == "PackedScene":
		dialog.filters = ["*.tscn"]
	else:
		dialog.filters = ["*.tres", "*.tscn"]
	
	dialog.file_selected.connect(func(path):
		var res = load(path)
		callback.call(res)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))

func _on_save() -> void:
	var tower_name = tower_name_input.text
	if tower_name.is_empty():
		tower_name = "Unnamed Tower"
	
	current_tower.tower_name = tower_name
	current_tower.range = range_input.value
	current_tower.damage = damage_input.value
	current_tower.fire_rate = fire_rate_input.value
	current_tower.pierce = int(pierce_input.value)
	current_tower.multishot = int(multishot_input.value)
	current_tower.traversal_time = traversal_time_input.value
	current_tower.attack_style = attack_style_option.selected
	current_tower.target_mode = target_mode_option.selected
	
	var visuals_dict = {}
	for child in visuals_list.get_children():
		if child is HBoxContainer:
			var key_input = child.get_child(0) as LineEdit
			var value_btn = child.get_child(1) as Button
			if key_input and not key_input.text.is_empty():
				visuals_dict[key_input.text] = value_btn.get_meta("visual_value", null)
	current_tower.visuals = visuals_dict
	
	var tags: Array[String] = []
	for child in target_tags_list.get_children():
		if child is HBoxContainer:
			var label = child.get_child(0) as Label
			if label:
				tags.append(label.text)
	current_tower.target_tags = tags
	
	var filename = filename_input.text
	if filename.is_empty():
		filename = _derive_filename(tower_name) + ".tres"
	elif not filename.ends_with(".tres"):
		filename += ".tres"
	
	filename = _sanitize_filename(filename)
	if filename.is_empty():
		filename = _derive_filename(tower_name) + ".tres"
	
	plugin.save_tower(current_tower, filename)
	
	if is_new_tower:
		_refresh_tower_list()
		is_new_tower = false

func _delete_tower(tower: Resource, list_item: Control) -> void:
	var window = Window.new()
	window.title = "Delete Tower?"
	window.size = Vector2i(350, 130)
	window.close_requested.connect(func(): window.queue_free())
	EditorInterface.get_base_control().add_child(window)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	window.add_child(vbox)
	
	var label = Label.new()
	label.text = "Delete \"" + tower.tower_name + "\"? This cannot be undone."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label)
	
	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): window.queue_free())
	buttons.add_child(cancel)
	
	var confirm = Button.new()
	confirm.text = "Delete"
	confirm.pressed.connect(func():
		var file_name = tower.resource_path.get_file()
		plugin.delete_tower_file(file_name)
		list_item.queue_free()
		if current_tower == tower:
			_form_visible(false)
			current_tower = null
		window.queue_free()
	)
	buttons.add_child(confirm)
	
	window.popup_centered()