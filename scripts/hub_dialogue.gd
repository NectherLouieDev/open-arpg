extends CanvasLayer
## Small controller-friendly dialogue panel for the Hub NPC test scenes.
class_name HubDialogue

var _panel: PanelContainer
var _title: Label
var _message: Label
var _hint: Label
var _was_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hub_dialogue")
	_build_ui()
	_panel.visible = false

func show_dialog(title_text: String, message_text: String) -> void:
	_title.text = title_text
	_message.text = message_text
	_was_paused = get_tree().paused
	get_tree().paused = true
	_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_panel.visible = false
		get_tree().paused = _was_paused
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.anchor_left = 0.16
	_panel.anchor_right = 0.84
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.96
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = -24.0
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_panel.add_child(layout)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color("d5b873"))
	_title.add_theme_font_size_override("font_size", 20)
	layout.add_child(_title)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color("e7e9df"))
	_message.add_theme_font_size_override("font_size", 16)
	layout.add_child(_message)
	_hint = Label.new()
	_hint.text = "A / ENTER / SPACE · CLOSE"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", Color("9eaea8"))
	layout.add_child(_hint)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.055, 0.96)
	style.border_color = Color("c5a55d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
