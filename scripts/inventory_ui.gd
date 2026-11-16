extends CanvasLayer
## Pausing, keyboard/gamepad-focusable inventory and equipment screen.
class_name InventoryUI

signal opened_changed(is_open: bool)

const GEAR_NAMES := ["HEAD", "BODY", "LEGS", "FEET", "HANDS", "WEAPON"]
const SKILL_BINDINGS := ["Q / X", "W / Y", "E / RB", "R / LB", "T / RT", "Y / LT"]
const RARITY_COLORS := [Color("d8ddd8"), Color("62d88c"), Color("64a9ff"), Color("d18aff"), Color("ffd36b")]
const CELL_MIN_WIDTH := 128.0
const ACTIVE_INVENTORY_SLOTS := 16
const DISPLAYED_INVENTORY_SLOTS := 32

var player: Player
var _is_open := false
var _was_paused := false
var _selected_item: ItemDefinition
var _selected_item_quantity := 1
var _selected_gear_slot := -1
var _selected_talisman_slot := -1
var _selection_from_gear := false
var _last_input_was_mouse := false
var _tooltip_action := ""
var _is_selecting_quick_slot := false
var _selected_cell: Button
var _selected_gear_button: Button

var _overlay: Control
var _content: MarginContainer
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _inventory_grid: GridContainer
var _inventory_cells: Array[Button] = []
var _capacity_label: Label
var _gear_buttons: Array[Button] = []
var _talisman_buttons: Array[Button] = []
var _status_label: Label
var _attribute_summary_label: Label
var _tooltip_panel: PanelContainer
var _tooltip_text: RichTextLabel
var _tooltip_action_button: Button
var _tooltip_slot_picker: HBoxContainer
var _tooltip_slot_buttons: Array[Button] = []
var _tooltip_anchor: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 127
	_build_ui()
	visible = false
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_update_responsive_layout")

func bind_player(value: Player) -> void:
	player = value
	if not is_instance_valid(player):
		return
	if not player.inventory.inventory_changed.is_connected(_refresh_ui):
		player.inventory.inventory_changed.connect(_refresh_ui)
	if not player.equipment.equipment_set_changed.is_connected(_refresh_ui):
		player.equipment.equipment_set_changed.connect(_refresh_ui)
	if not player.talismans.talismans_changed.is_connected(_refresh_ui):
		player.talismans.talismans_changed.connect(_refresh_ui)
	if not player.attributes.attributes_changed.is_connected(_refresh_ui):
		player.attributes.attributes_changed.connect(_refresh_ui)
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("ui_cancel"):
		if _is_selecting_quick_slot:
			_cancel_quick_slot_picker()
		elif _tooltip_panel.visible:
			_hide_tooltip()
		else:
			_close()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_input_was_mouse = true
		if event is InputEventMouseMotion and _tooltip_panel.visible:
			_schedule_tooltip_hide()
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_was_mouse = false
func _toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()

func _open() -> void:
	if not is_instance_valid(player):
		return
	_is_open = true
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	opened_changed.emit(true)
	_refresh_ui()
	if is_instance_valid(_selected_cell):
		_selected_cell.grab_focus()
	else:
		var first_cell := _first_inventory_cell()
		if is_instance_valid(first_cell):
			first_cell.grab_focus()
			_on_inventory_item_selected(first_cell.get_meta("item_definition"), first_cell)
		elif not _gear_buttons.is_empty():
			_gear_buttons[0].grab_focus()
			_on_gear_slot_selected(0, _gear_buttons[0])

func _close() -> void:
	_is_open = false
	visible = false
	_tooltip_panel.visible = false
	get_tree().paused = _was_paused
	opened_changed.emit(false)

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.025, 0.03, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_content)
	var panels := HBoxContainer.new()
	panels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_theme_constant_override("separation", 16)
	_content.add_child(panels)

	_left_panel = PanelContainer.new()
	_left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_panel.size_flags_stretch_ratio = 1.22
	_left_panel.add_theme_stylebox_override("panel", _make_panel_style())
	panels.add_child(_left_panel)
	_build_inventory_panel()

	_right_panel = PanelContainer.new()
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_panel.size_flags_stretch_ratio = 0.98
	_right_panel.add_theme_stylebox_override("panel", _make_panel_style())
	panels.add_child(_right_panel)
	_build_equipment_panel()

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.z_index = 20
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style())
	_overlay.add_child(_tooltip_panel)
	var tooltip_layout := VBoxContainer.new()
	tooltip_layout.add_theme_constant_override("separation", 8)
	_tooltip_panel.add_child(tooltip_layout)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.scroll_active = true
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.custom_minimum_size = Vector2(280.0, 90.0)
	_tooltip_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_text.add_theme_color_override("default_color", Color("e4e8df"))
	tooltip_layout.add_child(_tooltip_text)
	_tooltip_action_button = Button.new()
	_tooltip_action_button.focus_mode = Control.FOCUS_NONE
	_tooltip_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_action_button.visible = false
	_tooltip_action_button.pressed.connect(_on_tooltip_action_pressed)
	tooltip_layout.add_child(_tooltip_action_button)
	_tooltip_slot_picker = HBoxContainer.new()
	_tooltip_slot_picker.add_theme_constant_override("separation", 4)
	_tooltip_slot_picker.visible = false
	tooltip_layout.add_child(_tooltip_slot_picker)
	var quick_slot_labels := ["↑ / 1", "→ / 2", "↓ / 3", "← / 4"]
	for slot_index in range(InventoryComponent.QUICK_ITEM_SLOT_COUNT):
		var slot_button := Button.new()
		slot_button.text = quick_slot_labels[slot_index]
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.focus_mode = Control.FOCUS_ALL
		slot_button.pressed.connect(_bind_selected_consumable_to_slot.bind(slot_index))
		_tooltip_slot_picker.add_child(slot_button)
		_tooltip_slot_buttons.append(slot_button)
	_tooltip_panel.mouse_exited.connect(_schedule_tooltip_hide)

func _build_inventory_panel() -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_left_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _make_heading("INVENTORY")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_capacity_label = Label.new()
	_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_capacity_label.add_theme_color_override("font_color", Color("a8c5bd"))
	header.add_child(_capacity_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 4
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_grid.add_theme_constant_override("h_separation", 8)
	_inventory_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_inventory_grid)
	var hint := Label.new()
	hint.text = "Select or hover an item for details · Confirm to equip or swap gear"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("9eaea8"))
	hint.add_theme_font_size_override("font_size", 11)
	layout.add_child(hint)

func _build_equipment_panel() -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_right_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _make_heading("EQUIPMENT")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "CLOSE  [I / START]"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var gear_heading := _make_heading("GEAR SKILLS · SLOT BINDINGS")
	gear_heading.add_theme_font_size_override("font_size", 12)
	content.add_child(gear_heading)
	var gear_grid := GridContainer.new()
	gear_grid.columns = 2
	gear_grid.add_theme_constant_override("h_separation", 8)
	gear_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(gear_grid)
	for gear_slot in range(6):
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(0.0, 72.0)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.focus_mode = Control.FOCUS_ALL
		slot_button.pressed.connect(_on_gear_slot_activated.bind(gear_slot, slot_button))
		slot_button.focus_entered.connect(_on_gear_slot_selected.bind(gear_slot, slot_button))
		slot_button.mouse_entered.connect(_on_gear_slot_selected.bind(gear_slot, slot_button))
		slot_button.mouse_exited.connect(_schedule_tooltip_hide)
		gear_grid.add_child(slot_button)
		_gear_buttons.append(slot_button)

	var talisman_heading := _make_heading("TALISMANS · EQUIP IN HUB")
	talisman_heading.add_theme_font_size_override("font_size", 12)
	content.add_child(talisman_heading)
	var talisman_row := HBoxContainer.new()
	talisman_row.add_theme_constant_override("separation", 8)
	content.add_child(talisman_row)
	for slot_index in range(3):
		var talisman := Button.new()
		talisman.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		talisman.custom_minimum_size = Vector2(0.0, 62.0)
		talisman.focus_mode = Control.FOCUS_ALL
		talisman.add_theme_stylebox_override("normal", _make_talisman_style())
		talisman.add_theme_stylebox_override("hover", _make_talisman_style())
		talisman.add_theme_stylebox_override("pressed", _make_talisman_style())
		talisman.pressed.connect(_on_talisman_slot_activated.bind(slot_index, talisman))
		talisman.focus_entered.connect(_on_talisman_slot_selected.bind(slot_index, talisman))
		talisman.mouse_entered.connect(_on_talisman_slot_selected.bind(slot_index, talisman))
		talisman.mouse_exited.connect(_schedule_tooltip_hide)
		talisman_row.add_child(talisman)
		_talisman_buttons.append(talisman)
	_attribute_summary_label = Label.new()
	_attribute_summary_label.add_theme_color_override("font_color", Color("c5ad75"))
	content.add_child(_attribute_summary_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color("f2c77b"))
	content.add_child(_status_label)

func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("86d0b7"))
	label.add_theme_font_size_override("font_size", 17)
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.07, 0.98)
	style.border_color = Color("769a8e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style

func _make_tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.045, 0.99)
	style.border_color = Color("d1b66e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _make_talisman_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.075, 0.06, 0.95)
	style.border_color = Color("83734d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _make_inventory_cell_style(locked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252d2c") if locked else Color("0d1818")
	style.border_color = Color("343c3a") if locked else Color("52665f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _refresh_ui() -> void:
	if not is_instance_valid(player) or not is_instance_valid(_inventory_grid):
		return
	var selected_id := _selected_item.item_id if is_instance_valid(_selected_item) else ""
	for child in _inventory_grid.get_children():
		child.queue_free()
	_inventory_cells.clear()
	_selected_cell = null
	var selected_quantity := 1
	for slot_index in range(DISPLAYED_INVENTORY_SLOTS):
		var button := Button.new()
		button.custom_minimum_size = Vector2(CELL_MIN_WIDTH, 76.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		if slot_index < ACTIVE_INVENTORY_SLOTS:
			var active_style := _make_inventory_cell_style(false)
			button.add_theme_stylebox_override("normal", active_style)
			button.add_theme_stylebox_override("hover", active_style)
			button.add_theme_stylebox_override("pressed", active_style)
			button.add_theme_stylebox_override("disabled", active_style)
			if slot_index < player.inventory.entries.size():
				var entry: Dictionary = player.inventory.entries[slot_index]
				var item: ItemDefinition = entry.item
				var quantity: int = entry.quantity
				button.focus_mode = Control.FOCUS_ALL
				var quick_slot := player.inventory.get_quick_item_slot(item.item_id)
				var slot_marker := "\n%s / %d" % [["↑", "→", "↓", "←"][quick_slot], quick_slot + 1] if quick_slot >= 0 else ""
				button.text = "%s\nx%d%s" % [item.display_name, quantity, slot_marker] if item.stackable else "%s%s" % [item.display_name, slot_marker]
				button.add_theme_color_override("font_color", _get_item_color(item))
				button.set_meta("item_definition", item)
				button.pressed.connect(_on_inventory_item_activated.bind(item, button))
				button.focus_entered.connect(_on_inventory_item_selected.bind(item, button))
				button.mouse_entered.connect(_on_inventory_item_selected.bind(item, button))
				button.mouse_exited.connect(_schedule_tooltip_hide)
				_inventory_cells.append(button)
				if item.item_id == selected_id:
					_selected_cell = button
					selected_quantity = quantity
			else:
				button.disabled = true
				button.focus_mode = Control.FOCUS_NONE
				button.add_theme_color_override("font_color", Color("71807b"))
		else:
			button.text = "LOCKED"
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			var locked_style := _make_inventory_cell_style(true)
			button.add_theme_stylebox_override("normal", locked_style)
			button.add_theme_stylebox_override("disabled", locked_style)
			button.add_theme_color_override("font_color", Color("68716e"))
		_inventory_grid.add_child(button)
	_capacity_label.text = "%d / %d SLOTS" % [player.inventory.entries.size(), player.inventory.slot_capacity]
	for gear_slot in range(6):
		var equipment := player.equipment.get_equipped(gear_slot)
		var gear_name := equipment.equipment_name if is_instance_valid(equipment) else "Empty"
		var skill_name := equipment.granted_skill.skill_name if is_instance_valid(equipment) and is_instance_valid(equipment.granted_skill) else "No skill"
		_gear_buttons[gear_slot].text = "%s\n%s\n%s · %s" % [GEAR_NAMES[gear_slot], gear_name, SKILL_BINDINGS[gear_slot], skill_name]
	for slot_index in range(TalismanComponent.SLOT_COUNT):
		var talisman := player.talismans.get_equipped(slot_index)
		_talisman_buttons[slot_index].text = "TALISMAN %d\n%s" % [slot_index + 1, talisman.display_name if is_instance_valid(talisman) else "◇ EMPTY"]
	_attribute_summary_label.text = "STR %.1f   FIN %.1f   ARK %.1f" % [player.attributes.get_attribute(AttributeComponent.Attribute.STR), player.attributes.get_attribute(AttributeComponent.Attribute.FIN), player.attributes.get_attribute(AttributeComponent.Attribute.ARK)]
	if selected_id != "" and not is_instance_valid(_selected_cell):
		_selected_item = null
		_selected_gear_slot = -1
	elif is_instance_valid(_selected_item):
		_selected_item_quantity = selected_quantity
	if _selected_gear_slot >= 0:
		_selected_gear_button = _gear_buttons[_selected_gear_slot]
	_update_selection()
	call_deferred("_update_responsive_layout")

func _get_item_color(item: ItemDefinition) -> Color:
	if item.item_kind == ItemDefinition.ItemKind.EQUIPMENT and is_instance_valid(item.equipment):
		return RARITY_COLORS[clampi(item.equipment.rarity, 0, RARITY_COLORS.size() - 1)]
	if item.item_kind == ItemDefinition.ItemKind.TALISMAN and is_instance_valid(item.talisman):
		return RARITY_COLORS[clampi(item.talisman.rarity, 0, RARITY_COLORS.size() - 1)]
	match item.item_kind:
		ItemDefinition.ItemKind.CURRENCY:
			return Color("f5c84b")
		ItemDefinition.ItemKind.SHARD:
			return [Color("e36c55"), Color("55d8a5"), Color("8f75f5")][clampi(item.attribute, 0, 2)]
		ItemDefinition.ItemKind.CONSUMABLE:
			return Color("61d0c4")
	return Color("d8ddd8")

func _on_inventory_item_selected(item: ItemDefinition, cell: Button) -> void:
	_selected_item = item
	_selected_item_quantity = player.inventory.get_item_quantity(item.item_id)
	_selected_cell = cell
	_selection_from_gear = false
	_selected_gear_slot = item.equipment.gear_slot if item.item_kind == ItemDefinition.ItemKind.EQUIPMENT and is_instance_valid(item.equipment) else -1
	_selected_gear_button = _gear_buttons[_selected_gear_slot] if _selected_gear_slot >= 0 else null
	_status_label.text = ""
	_update_selection()

func _on_inventory_item_activated(item: ItemDefinition, cell: Button) -> void:
	if _last_input_was_mouse:
		_on_inventory_item_selected(item, cell)
		return
	_on_inventory_item_selected(item, cell)
	if item.item_kind == ItemDefinition.ItemKind.EQUIPMENT and is_instance_valid(item.equipment):
		_equip_selected()
	elif item.item_kind == ItemDefinition.ItemKind.TALISMAN and is_instance_valid(item.talisman):
		_equip_selected_talisman()
	elif item.item_kind == ItemDefinition.ItemKind.CONSUMABLE:
		_open_quick_slot_picker()

func _on_gear_slot_selected(gear_slot: int, button: Button) -> void:
	_selected_gear_slot = gear_slot
	_selected_gear_button = button
	_selection_from_gear = true
	if is_instance_valid(_selected_item) and (not is_instance_valid(_selected_item.equipment) or _selected_item.equipment.gear_slot != gear_slot):
		_selected_item = null
		_selected_cell = null
	_status_label.text = ""
	_update_selection()

func _on_gear_slot_activated(gear_slot: int, button: Button) -> void:
	_on_gear_slot_selected(gear_slot, button)
	if _last_input_was_mouse:
		return
	if _has_equip_candidate_for_slot(gear_slot):
		_equip_selected()
	else:
		_unequip_selected()

func _on_talisman_slot_selected(slot_index: int, button: Button) -> void:
	_selected_gear_slot = -1
	_selected_gear_button = null
	_selected_talisman_slot = slot_index
	if is_instance_valid(_selected_item) and _selected_item.item_kind == ItemDefinition.ItemKind.TALISMAN:
		_show_item_tooltip(_selected_cell, _selected_item, _selected_item_quantity)
		return
	var talisman := player.talismans.get_equipped(slot_index)
	if is_instance_valid(talisman):
		_set_tooltip_action("talisman_unequip")
		_tooltip_action_button.text = "UNEQUIP TALISMAN  ·  A / ENTER / CLICK"
		_show_tooltip(button, "[b]TALISMAN SLOT %d[/b]\n%s" % [slot_index + 1, talisman.get_description()])
	else:
		_tooltip_panel.visible = false

func _on_talisman_slot_activated(slot_index: int, button: Button) -> void:
	_on_talisman_slot_selected(slot_index, button)
	if is_instance_valid(_selected_item) and _selected_item.item_kind == ItemDefinition.ItemKind.TALISMAN:
		_equip_selected_talisman(slot_index)
	elif not _last_input_was_mouse:
		_unequip_selected_talisman(slot_index)

func _equip_selected_talisman(slot_index: int = -1) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_selected_item) or not is_instance_valid(_selected_item.talisman):
		return
	if slot_index < 0:
		for candidate in range(TalismanComponent.SLOT_COUNT):
			if not is_instance_valid(player.talismans.get_equipped(candidate)):
				slot_index = candidate
				break
	if slot_index < 0 or slot_index >= TalismanComponent.SLOT_COUNT:
		_status_label.text = "Choose a Talisman slot."
		return
	var item := _selected_item
	if not player.inventory.remove_item(item.item_id, 1):
		_status_label.text = "That Talisman is no longer available."
		return
	var previous := player.talismans.get_equipped(slot_index)
	if not player.talismans.equip(slot_index, item.talisman):
		player.inventory.try_add_item(item)
		return
	if is_instance_valid(previous):
		var previous_item := player.inventory.get_item_definition_for_talisman(previous)
		if is_instance_valid(previous_item):
			player.inventory.try_add_item(previous_item)
	_selected_item = null
	_selected_cell = null
	_selected_talisman_slot = slot_index
	_status_label.text = "%s equipped in Talisman slot %d." % [item.display_name, slot_index + 1]
	_refresh_ui()

func _unequip_selected_talisman(slot_index: int) -> void:
	var current := player.talismans.get_equipped(slot_index)
	var item := player.inventory.get_item_definition_for_talisman(current)
	if not is_instance_valid(item) or player.inventory.try_add_item(item) != 1:
		_status_label.text = "Cannot unequip: item definition is missing or inventory is full."
		return
	player.talismans.unequip(slot_index)
	_status_label.text = "%s unequipped." % current.display_name
	_refresh_ui()

func _update_selection() -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(_selected_item):
		if _selection_from_gear:
			_show_equipment_tooltip(_selected_gear_button, _selected_gear_slot)
		else:
			_show_item_tooltip(_selected_cell, _selected_item, _selected_item_quantity)
	elif _selected_gear_slot >= 0:
		_show_equipment_tooltip(_selected_gear_button, _selected_gear_slot)
	else:
		_tooltip_panel.visible = false

func _show_item_tooltip(anchor: Control, item: ItemDefinition, quantity: int) -> void:
	if not is_instance_valid(item):
		_hide_tooltip()
		return
	_set_tooltip_action("")
	var text := "[b]%s[/b]\n%s" % [item.display_name, item.get_pickup_description(quantity)]
	if item.item_kind == ItemDefinition.ItemKind.CONSUMABLE:
		var bound_slot := player.inventory.get_quick_item_slot(item.item_id)
		_set_tooltip_action("bind")
		text += "\n\n[b]QUICK SLOT[/b]\n%s" % ("Bound to %s / %d" % [["D-pad ↑", "D-pad →", "D-pad ↓", "D-pad ←"][bound_slot], bound_slot + 1] if bound_slot >= 0 else "Not bound")
	if item.item_kind == ItemDefinition.ItemKind.EQUIPMENT and is_instance_valid(item.equipment):
		var gear_slot := item.equipment.gear_slot
		_set_tooltip_action("equip")
		var current := player.equipment.get_equipped(gear_slot)
		text += "\n\n[b]COMPARISON · %s[/b]\n" % GEAR_NAMES[gear_slot]
		text += "[color=#e8d49b]Current:[/color] %s\n" % (current.equipment_name if is_instance_valid(current) else "Empty")
		text += "[color=#a8e4c7]Selected:[/color] %s\n\n" % item.equipment.equipment_name
		text += _format_stat_delta(item.equipment, current)
	elif item.item_kind == ItemDefinition.ItemKind.TALISMAN and is_instance_valid(item.talisman):
		_set_tooltip_action("talisman_equip")
		_tooltip_action_button.text = "EQUIP TALISMAN  ·  A / ENTER / CLICK"
		text += "\n\nSelect a Talisman slot to choose where it goes."
	_show_tooltip(anchor, text)

func _show_equipment_tooltip(anchor: Control, gear_slot: int) -> void:
	var equipment := player.equipment.get_equipped(gear_slot)
	if not is_instance_valid(equipment):
		_set_tooltip_action("equip" if _has_equip_candidate_for_slot(gear_slot) else "")
		_show_tooltip(anchor, "[b]%s[/b]\nEmpty equipment slot." % GEAR_NAMES[gear_slot])
		return
	var item := player.inventory.get_item_definition_for_equipment(equipment)
	if _has_equip_candidate_for_slot(gear_slot):
		_set_tooltip_action("equip")
	else:
		_set_tooltip_action("unequip" if is_instance_valid(item) else "")
	var text := "[b]%s · %s[/b]\n%s" % [GEAR_NAMES[gear_slot], equipment.equipment_name, item.get_pickup_description(1) if is_instance_valid(item) else "Equipment line: %s" % equipment.equipment_line]
	if is_instance_valid(_selected_item) and is_instance_valid(_selected_item.equipment) and _selected_item.equipment.gear_slot == gear_slot:
		text += "\n\n[b]SELECTED PACK ITEM[/b]\n%s\n\n" % _selected_item.equipment.equipment_name
		text += _format_stat_delta(_selected_item.equipment, equipment)
	_show_tooltip(anchor, text)

func _show_tooltip(anchor: Control, text: String) -> void:
	_tooltip_text.text = text
	_tooltip_panel.visible = true
	_tooltip_anchor = anchor
	call_deferred("_position_tooltip")

func _set_tooltip_action(action: String) -> void:
	_tooltip_action = action
	_is_selecting_quick_slot = false
	_tooltip_slot_picker.visible = false
	_tooltip_action_button.visible = not action.is_empty()
	if action == "equip":
		_tooltip_action_button.text = "EQUIP / SWAP  ·  A / ENTER / CLICK"
	elif action == "unequip":
		_tooltip_action_button.text = "UNEQUIP  ·  A / ENTER / CLICK"
	elif action == "bind":
		_tooltip_action_button.text = "BIND TO QUICK SLOT  ·  A / ENTER / CLICK"

func _on_tooltip_action_pressed() -> void:
	if _tooltip_action == "equip":
		_equip_selected()
	elif _tooltip_action == "unequip":
		_unequip_selected()
	elif _tooltip_action == "bind":
		_open_quick_slot_picker()
	elif _tooltip_action == "talisman_equip":
		_equip_selected_talisman()
	elif _tooltip_action == "talisman_unequip":
		_unequip_selected_talisman(_selected_talisman_slot)

func _open_quick_slot_picker() -> void:
	if not is_instance_valid(_selected_item) or _selected_item.item_kind != ItemDefinition.ItemKind.CONSUMABLE:
		return
	_is_selecting_quick_slot = true
	_tooltip_action_button.visible = false
	_tooltip_slot_picker.visible = true
	if not _last_input_was_mouse and not _tooltip_slot_buttons.is_empty():
		_tooltip_slot_buttons[0].grab_focus()
	call_deferred("_position_tooltip")

func _bind_selected_consumable_to_slot(slot_index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_selected_item):
		return
	if not player.inventory.bind_quick_item(_selected_item.item_id, slot_index):
		_status_label.text = "Could not bind that consumable."
		return
	_status_label.text = "%s bound to quick slot %d." % [_selected_item.display_name, slot_index + 1]
	_is_selecting_quick_slot = false
	_tooltip_slot_picker.visible = false
	_tooltip_action_button.visible = true
	_refresh_ui()
	call_deferred("_focus_selected_inventory_cell")

func _cancel_quick_slot_picker() -> void:
	_is_selecting_quick_slot = false
	_tooltip_slot_picker.visible = false
	_tooltip_action_button.visible = true
	call_deferred("_focus_selected_inventory_cell")

func _focus_selected_inventory_cell() -> void:
	if _is_open and is_instance_valid(_selected_cell):
		_selected_cell.grab_focus()

func _has_equip_candidate_for_slot(gear_slot: int) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(_selected_item):
		return false
	if _selected_item.item_kind != ItemDefinition.ItemKind.EQUIPMENT or not is_instance_valid(_selected_item.equipment):
		return false
	return _selected_item.equipment.gear_slot == gear_slot and player.inventory.get_item_quantity(_selected_item.item_id) > 0

func _schedule_tooltip_hide() -> void:
	call_deferred("_hide_tooltip_if_pointer_outside")

func _hide_tooltip_if_pointer_outside() -> void:
	if not _tooltip_panel.visible:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if _tooltip_panel.get_global_rect().grow(18.0).has_point(mouse_position):
		return
	if is_instance_valid(_tooltip_anchor) and _tooltip_anchor.get_global_rect().grow(18.0).has_point(mouse_position):
		return
	_hide_tooltip()

func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.visible = false
	_tooltip_anchor = null

func _position_tooltip() -> void:
	if not _is_open or not is_instance_valid(_tooltip_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_margin := 12.0
	var anchor_rect := Rect2(Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5), Vector2.ZERO)
	if is_instance_valid(_tooltip_anchor):
		anchor_rect = Rect2(_tooltip_anchor.global_position, _tooltip_anchor.size)
	var right_space := viewport_size.x - anchor_rect.end.x - safe_margin
	var left_space := anchor_rect.position.x - safe_margin
	var preferred_width := minf(380.0, maxf(160.0, maxf(viewport_size.x - safe_margin * 2.0, viewport_size.x * 0.32)))
	var tooltip_width := minf(preferred_width, maxf(160.0, maxf(left_space, right_space)))
	var max_height := maxf(80.0, viewport_size.y - safe_margin * 2.0)
	_tooltip_text.custom_minimum_size.x = tooltip_width - 24.0
	_tooltip_text.custom_minimum_size.y = 72.0
	_tooltip_panel.custom_minimum_size = Vector2(tooltip_width, 0.0)
	_tooltip_panel.size = Vector2(tooltip_width, minf(max_height, maxf(130.0, _tooltip_panel.get_combined_minimum_size().y)))
	var x := anchor_rect.end.x + safe_margin if right_space >= tooltip_width or right_space >= left_space else anchor_rect.position.x - tooltip_width - safe_margin
	x = clampf(x, safe_margin, maxf(safe_margin, viewport_size.x - tooltip_width - safe_margin))
	var y := anchor_rect.position.y + (anchor_rect.size.y - _tooltip_panel.size.y) * 0.5
	y = clampf(y, safe_margin, maxf(safe_margin, viewport_size.y - _tooltip_panel.size.y - safe_margin))
	_tooltip_panel.position = Vector2(x, y)

func _format_stat_delta(incoming: EquipmentDefinition, current: EquipmentDefinition) -> String:
	var before_health := current.max_health_bonus if is_instance_valid(current) else 0.0
	var before_anima := current.max_anima_bonus if is_instance_valid(current) else 0.0
	var before_damage := current.attack_damage_bonus if is_instance_valid(current) else 0.0
	var before_range := current.attack_range_bonus if is_instance_valid(current) else 0.0
	var before_speed := current.attack_speed_bonus if is_instance_valid(current) else 0.0
	var lines := [
		_format_colored_stat_delta("HP", incoming.max_health_bonus - before_health),
		_format_colored_stat_delta("Anima", incoming.max_anima_bonus - before_anima),
		_format_colored_stat_delta("Damage", incoming.attack_damage_bonus - before_damage),
		_format_colored_stat_delta("Range", incoming.attack_range_bonus - before_range),
		_format_colored_stat_delta("Attack speed", incoming.attack_speed_bonus - before_speed)
	]
	if incoming is WeaponDefinition:
		var old_weapon := current as WeaponDefinition
		if is_instance_valid(old_weapon):
			lines.append(_format_colored_stat_delta("Weapon damage", incoming.attack_damage - old_weapon.attack_damage))
			lines.append(_format_colored_stat_delta("Weapon range", incoming.attack_range - old_weapon.attack_range))
			lines.append(_format_colored_stat_delta("Attack interval", incoming.attack_interval - old_weapon.attack_interval))
		else:
			lines.append(_format_colored_stat_delta("Weapon damage", incoming.attack_damage))
			lines.append(_format_colored_stat_delta("Weapon range", incoming.attack_range))
			lines.append(_format_colored_stat_delta("Attack interval", incoming.attack_interval))
	return "[b]Stat change[/b]\n" + "\n".join(lines)

func _format_colored_stat_delta(label: String, delta: float) -> String:
	var color := "#76e39b" if delta > 0.0 else "#f07878" if delta < 0.0 else "#e4e8df"
	return "%s [color=%s]%s[/color]" % [label, color, ItemDefinition.format_signed(delta)]

func _equip_selected() -> void:
	if not is_instance_valid(player) or not is_instance_valid(_selected_item) or not is_instance_valid(_selected_item.equipment):
		return
	var incoming_item := _selected_item
	var incoming_equipment := incoming_item.equipment
	var current := player.equipment.get_equipped(incoming_equipment.gear_slot)
	var current_item := player.inventory.get_item_definition_for_equipment(current)
	if is_instance_valid(current) and not is_instance_valid(current_item):
		_status_label.text = "Cannot swap: no inventory item definition exists for equipped gear."
		return
	if not player.inventory.remove_item(incoming_item.item_id, 1):
		_status_label.text = "That item is no longer available."
		return
	if not player.equipment.equip(incoming_equipment):
		player.inventory.try_add_item(incoming_item, 1)
		_status_label.text = "This equipment does not fit that slot."
		return
	if is_instance_valid(current_item):
		player.inventory.try_add_item(current_item, 1)
	_selected_item = null
	_selected_cell = null
	_selected_gear_slot = incoming_equipment.gear_slot
	_selected_gear_button = _gear_buttons[_selected_gear_slot]
	_selection_from_gear = true
	_status_label.text = "%s equipped." % incoming_equipment.equipment_name
	_refresh_ui()
	call_deferred("_focus_selected_gear_slot")

func _unequip_selected() -> void:
	if not is_instance_valid(player) or _selected_gear_slot < 0:
		return
	var current := player.equipment.get_equipped(_selected_gear_slot)
	var item := player.inventory.get_item_definition_for_equipment(current)
	if not is_instance_valid(item):
		_status_label.text = "No inventory item definition exists for that gear."
		return
	if player.inventory.try_add_item(item, 1) != 1:
		_status_label.text = "Pack is full. Make room before unequipping."
		return
	player.equipment.unequip(_selected_gear_slot)
	_selection_from_gear = true
	_status_label.text = "%s unequipped." % current.equipment_name
	_refresh_ui()
	call_deferred("_focus_selected_gear_slot")

func _focus_selected_gear_slot() -> void:
	if not _is_open or _selected_gear_slot < 0 or _selected_gear_slot >= _gear_buttons.size():
		return
	var button := _gear_buttons[_selected_gear_slot]
	if is_instance_valid(button) and button.is_visible_in_tree():
		button.grab_focus()

func _first_inventory_cell() -> Button:
	return _inventory_cells[0] if not _inventory_cells.is_empty() else null

func _on_viewport_size_changed() -> void:
	call_deferred("_update_responsive_layout")
	if _tooltip_panel.visible:
		call_deferred("_position_tooltip")

func _update_responsive_layout() -> void:
	if not is_instance_valid(_content):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := clampf(minf(viewport_size.x, viewport_size.y) * 0.025, 8.0, 28.0)
	_content.add_theme_constant_override("margin_left", roundi(margin))
	_content.add_theme_constant_override("margin_right", roundi(margin))
	_content.add_theme_constant_override("margin_top", roundi(margin))
	_content.add_theme_constant_override("margin_bottom", roundi(margin))
	if is_instance_valid(_inventory_grid):
		_inventory_grid.columns = 4
	if is_instance_valid(_tooltip_panel) and _tooltip_panel.visible:
		call_deferred("_position_tooltip")
