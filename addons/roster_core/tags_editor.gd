@tool
extends VBoxContainer
class_name TagsEditor

## Self-contained editor for tag arrays with autocomplete.
## Used by BaseRosterPanel for TYPE_TAG_ARRAY properties.

signal tag_added(tag: String)
signal tag_removed(tag: String)

var _known_tags: Array[String] = []
var _tag_chips: Dictionary = {}  ## tag -> HBoxContainer
var _scale: float = 1.0

var _list: VBoxContainer
var _input: LineEdit
var _autocomplete: OptionButton


func _ready() -> void:
	_list = VBoxContainer.new()
	_list.name = "TagsList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	_input = LineEdit.new()
	_input.placeholder_text = "Add tag (press Enter)"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(_on_tag_submitted)
	_input.text_changed.connect(_on_tag_text_changed)
	hbox.add_child(_input)

	_autocomplete = OptionButton.new()
	_autocomplete.visible = false
	_autocomplete.item_selected.connect(func(idx: int):
		_input.text = _autocomplete.get_item_text(idx)
		_autocomplete.visible = false
		_on_tag_submitted(_input.text)
	)
	hbox.add_child(_autocomplete)


func set_known_tags(tags: Array[String]) -> void:
	_known_tags = tags.duplicate()


func set_editor_scale(scale: float) -> void:
	_scale = scale


func load_tags(tags: Array) -> void:
	clear_tags()
	for tag in tags:
		add_tag_entry(str(tag))


func clear_tags() -> void:
	_tag_chips.clear()
	if _list:
		for child in _list.get_children():
			child.queue_free()


func gather_tags() -> Array[String]:
	var result: Array[String] = []
	for tag in _tag_chips.keys():
		result.append(tag)
	return result


func add_tag_entry(tag: String) -> void:
	if tag in _tag_chips:
		return

	var container := HBoxContainer.new()
	_list.add_child(container)

	var label := Label.new()
	label.text = tag
	container.add_child(label)

	if not tag in _known_tags:
		label.modulate = Color(1, 0.8, 0, 1)

	var remove_btn := Button.new()
	remove_btn.flat = true
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		_tag_chips.erase(tag)
		container.queue_free()
		tag_removed.emit(tag)
	)
	container.add_child(remove_btn)
	_tag_chips[tag] = container


func _on_tag_submitted(tag: String) -> void:
	tag = tag.strip_edges()
	if tag == "":
		return
	if not tag in _known_tags:
		tag_added.emit(tag)
	add_tag_entry(tag)
	_input.text = ""
	_autocomplete.visible = false


func _on_tag_text_changed(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		_autocomplete.visible = false
		return

	var matches: Array[String] = []
	for known_tag in _known_tags:
		if known_tag.to_lower().begins_with(text.to_lower()):
			matches.append(known_tag)
		if matches.size() >= 5:
			break

	if matches.size() > 0:
		_autocomplete.clear()
		for m in matches:
			_autocomplete.add_item(m)
		_autocomplete.visible = true
	else:
		_autocomplete.visible = false
