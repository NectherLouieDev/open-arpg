extends CanvasLayer
## Displays health, Anima, skill cooldowns, loot, and combat status in the HUD.
class_name CombatHUD

const SKILL_ACTIONS := ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6"]
const ITEM_ACTIONS := ["item_1", "item_2", "item_3", "item_4"]
const SKILL_BINDINGS := ["Q / X", "W / Y", "E / RB", "R / LB", "T / RT", "Y / LT"]
const SKILL_GEAR_SLOTS := ["HEAD", "BODY", "LEGS", "FEET", "HANDS", "WEAPON"]
const ITEM_BINDINGS := ["1 / ↑", "2 / →", "3 / ↓", "4 / ←"]

var _player: Player
var _skills: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _health_orb: Dictionary
var _anima_orb: Dictionary
var _failure_label: Label
var _failure_time_left := 0.0
var _pickup_label: Label
var _pickup_time_left := 0.0
var _inventory_open := false
var _visible_before_inventory := true

func _ready() -> void:
	_build_ui()
	add_to_group("combat_hud")

func bind_player(player: Player) -> void:
	if is_instance_valid(_player) and _player.inventory.inventory_changed.is_connected(_refresh_item_slots):
		_player.inventory.inventory_changed.disconnect(_refresh_item_slots)
	if is_instance_valid(_player) and _player.skill.skill_failed.is_connected(_on_skill_failed):
		_player.skill.skill_failed.disconnect(_on_skill_failed)
	_player = player
	if is_instance_valid(_player) and not _player.skill.skill_failed.is_connected(_on_skill_failed):
		_player.skill.skill_failed.connect(_on_skill_failed)
	if is_instance_valid(_player) and not _player.inventory_ui.opened_changed.is_connected(set_inventory_open):
		_player.inventory_ui.opened_changed.connect(set_inventory_open)
		if _inventory_open:
			_visible_before_inventory = visible
			visible = false
	if is_instance_valid(_player) and not _player.inventory.inventory_changed.is_connected(_refresh_item_slots):
		_player.inventory.inventory_changed.connect(_refresh_item_slots)
	_refresh_item_slots()

func set_inventory_open(is_open: bool) -> void:
	if is_open == _inventory_open:
		return
	_inventory_open = is_open
	if is_open:
		_visible_before_inventory = visible
		visible = false
	else:
		visible = _visible_before_inventory

func _process(delta: float) -> void:
	_pickup_time_left = maxf(0.0, _pickup_time_left - delta)
	if is_instance_valid(_pickup_label):
		_pickup_label.visible = _pickup_time_left > 0.0
	_failure_time_left = maxf(0.0, _failure_time_left - delta)
	if is_instance_valid(_failure_label):
		_failure_label.visible = _failure_time_left > 0.0
	for index in range(SKILL_ACTIONS.size()):
		if Input.is_action_just_pressed(SKILL_ACTIONS[index]):
			_flash_slot(_skills[index])
	for index in range(ITEM_ACTIONS.size()):
		if Input.is_action_just_pressed(ITEM_ACTIONS[index]) and is_instance_valid(_player) and is_instance_valid(_player.inventory.get_quick_item_definition(index)):
			_flash_slot(_items[index])

	for index in range(_skills.size()):
		var slot := _skills[index]
		slot.flash_left = maxf(0.0, slot.flash_left - delta)
		slot.fail_left = maxf(0.0, slot.fail_left - delta)
		slot.active = is_instance_valid(_player) and _player.skill.is_targeting() and _player.skill.get_targeting_slot() == index + 1
		_update_slot_style(slot)
	for slot in _items:
		slot.flash_left = maxf(0.0, slot.flash_left - delta)
		_update_slot_style(slot)

	if not is_instance_valid(_player):
		return
	_update_orb(_health_orb, _player.stats.health, _player.stats.max_health)
	_update_orb(_anima_orb, _player.stats.anima, _player.stats.max_anima)
	for index in range(_skills.size()):
		var skill_slot := index + 1
		var slot := _skills[index]
		var skill_name := _player.skill.get_skill_name(skill_slot)
		var name_label: Label = slot.name_label
		name_label.text = skill_name.to_upper()
		var cooldown := _player.skill.get_cooldown_left(skill_slot)
		var cooldown_duration := maxf(0.01, _player.skill.get_skill_cooldown(skill_slot))
		_update_cooldown(slot, cooldown, cooldown_duration)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var skill_bar := HBoxContainer.new()
	skill_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_bar.position = Vector2(-184.0, -82.0)
	skill_bar.size = Vector2(368.0, 64.0)
	skill_bar.add_theme_constant_override("separation", 4)
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_bar)
	for index in range(SKILL_ACTIONS.size()):
		var slot := _make_slot(SKILL_BINDINGS[index], SKILL_GEAR_SLOTS[index], Vector2(58.0, 62.0))
		_skills.append(slot)
		skill_bar.add_child(slot.control)

	var skill_hint := Label.new()
	skill_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_hint.position = Vector2(-184.0, -104.0)
	skill_hint.size = Vector2(368.0, 16.0)
	skill_hint.text = "HOLD TO PREVIEW · RELEASE TO CAST · B / RMB CANCEL"
	skill_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_hint.add_theme_color_override("font_color", Color("b9d7d0"))
	skill_hint.add_theme_font_size_override("font_size", 9)
	skill_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_hint)
	_failure_label = Label.new()
	_failure_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_failure_label.position = Vector2(-184.0, -126.0)
	_failure_label.size = Vector2(368.0, 18.0)
	_failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_failure_label.add_theme_color_override("font_color", Color("ff8b7a"))
	_failure_label.add_theme_font_size_override("font_size", 11)
	_failure_label.visible = false
	_failure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_failure_label)
	_pickup_label = Label.new()
	_pickup_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pickup_label.position = Vector2(-190.0, 76.0)
	_pickup_label.size = Vector2(380.0, 48.0)
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_label.add_theme_color_override("font_color", Color("f5e7b4"))
	_pickup_label.add_theme_font_size_override("font_size", 13)
	_pickup_label.visible = false
	_pickup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pickup_label)

	var item_cross := Control.new()
	item_cross.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	item_cross.position = Vector2(14.0, -166.0)
	item_cross.size = Vector2(152.0, 152.0)
	item_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item_cross)
	var item_positions := [Vector2(52, 0), Vector2(0, 52), Vector2(52, 104), Vector2(104, 52)]
	for index in range(ITEM_ACTIONS.size()):
		var slot := _make_slot(ITEM_BINDINGS[index], "ITEM", Vector2(48.0, 48.0))
		slot.control.position = item_positions[index]
		_items.append(slot)
		item_cross.add_child(slot.control)

	_health_orb = _make_orb(root, false)
	_anima_orb = _make_orb(root, true)
	_make_talisman_slots(root)

func _make_slot(binding: String, detail: String, slot_size: Vector2) -> Dictionary:
	var control := Control.new()
	control.custom_minimum_size = slot_size
	control.size = slot_size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.06, 0.9)
	style.border_color = Color(0.43, 0.58, 0.56, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", style)
	control.add_child(background)
	var cooldown_overlay := ColorRect.new()
	cooldown_overlay.size = slot_size
	cooldown_overlay.color = Color(0.04, 0.08, 0.16, 0.78)
	cooldown_overlay.visible = false
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(cooldown_overlay)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 2.0
	content.offset_top = 2.0
	content.offset_right = -2.0
	content.offset_bottom = -2.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(content)
	var binding_label := Label.new()
	binding_label.text = binding
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	binding_label.add_theme_color_override("font_color", Color("b9d7d0"))
	binding_label.add_theme_font_size_override("font_size", 10)
	content.add_child(binding_label)
	var gear_label := Label.new()
	gear_label.text = detail
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_label.add_theme_color_override("font_color", Color("b9d7d0"))
	gear_label.add_theme_font_size_override("font_size", 8)
	content.add_child(gear_label)
	var name_label := Label.new()
	name_label.text = ""
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color("f1eee5"))
	name_label.add_theme_font_size_override("font_size", 9)
	content.add_child(name_label)
	var cooldown_label := Label.new()
	cooldown_label.text = ""
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	cooldown_label.add_theme_font_size_override("font_size", 12)
	content.add_child(cooldown_label)
	return {
		"control": control,
		"style": style,
		"cooldown_overlay": cooldown_overlay,
		"cooldown_label": cooldown_label,
		"name_label": name_label,
		"binding_label": binding_label,
		"detail_label": gear_label,
		"flash_left": 0.0,
		"fail_left": 0.0,
		"active": false
	}

func _refresh_item_slots() -> void:
	if not is_instance_valid(_player):
		return
	for index in range(mini(_items.size(), InventoryComponent.QUICK_ITEM_SLOT_COUNT)):
		var item := _player.inventory.get_quick_item_definition(index)
		var slot := _items[index]
		var name_label: Label = slot.name_label
		var detail_label: Label = slot.detail_label
		if is_instance_valid(item):
			name_label.text = item.display_name.to_upper()
			detail_label.text = "x%d" % _player.inventory.get_item_quantity(item.item_id)
		else:
			name_label.text = ""
			detail_label.text = "EMPTY"

func _make_orb(root: Control, is_anima: bool) -> Dictionary:
	var orb := Control.new()
	orb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	orb.position = Vector2(212.0, -146.0) if is_anima else Vector2(-340.0, -146.0)
	orb.size = Vector2(128.0, 128.0)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(orb)
	var bar := TextureProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.texture_under = _make_orb_texture(Color(0.045, 0.055, 0.075), true, false)
	bar.texture_progress = _make_orb_texture(Color(0.75, 0.11, 0.12) if not is_anima else Color(0.12, 0.42, 0.92), false, false)
	bar.texture_over = _make_orb_texture(Color.TRANSPARENT, false, true)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(bar)
	var title := Label.new()
	title.position = Vector2(0.0, -17.0)
	title.size = Vector2(128.0, 16.0)
	title.text = "ANIMA" if is_anima else "HEALTH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("e8e4d7"))
	title.add_theme_font_size_override("font_size", 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(title)
	var value_label := Label.new()
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	value_label.add_theme_constant_override("shadow_offset_x", 1)
	value_label.add_theme_constant_override("shadow_offset_y", 1)
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(value_label)
	return {"bar": bar, "label": value_label}

func _make_orb_texture(base_color: Color, is_background: bool, ring_only: bool) -> Texture2D:
	const TEXTURE_SIZE := 128
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE * 0.5, TEXTURE_SIZE * 0.5)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			if radius > 62.0:
				continue
			var color := Color.TRANSPARENT
			if ring_only:
				if radius >= 54.0:
					color = Color(0.025, 0.035, 0.045, 0.98) if radius > 59.0 else Color(0.68, 0.63, 0.48, 0.96)
			elif is_background:
				color = Color(0.045, 0.055, 0.075, 0.98) if radius < 54.0 else Color(0.02, 0.025, 0.035, 1.0)
			elif radius < 54.0:
				var light := clampf(0.16 - (offset.x + offset.y) / 900.0, 0.0, 0.22)
				color = base_color.lightened(light)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _make_talisman_slots(root: Control) -> void:
	var slots := Control.new()
	slots.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	slots.position = Vector2(-154.0, -118.0)
	slots.size = Vector2(138.0, 88.0)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slots)
	var ring_texture := _make_talisman_ring_texture()
	var triangle_positions := [Vector2(48, 0), Vector2(0, 44), Vector2(96, 44)]
	for index in range(3):
		var slot := TextureRect.new()
		slot.position = triangle_positions[index]
		slot.size = Vector2(42.0, 42.0)
		slot.texture = ring_texture
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_SCALE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots.add_child(slot)

func _make_talisman_ring_texture() -> Texture2D:
	const TEXTURE_SIZE := 48
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE * 0.5, TEXTURE_SIZE * 0.5)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var radius := (Vector2(x, y) - center).length()
			if radius <= 22.0 and radius >= 18.0:
				image.set_pixel(x, y, Color(0.58, 0.49, 0.32, 0.95))
			elif radius < 18.0:
				image.set_pixel(x, y, Color(0.025, 0.035, 0.045, 0.82))
	return ImageTexture.create_from_image(image)

func _update_orb(orb: Dictionary, current: float, maximum: float) -> void:
	var bar: TextureProgressBar = orb.bar
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(current, 0.0, bar.max_value)
	var label: Label = orb.label
	label.text = "%.0f\n/ %.0f" % [current, maximum]

func _flash_slot(slot: Dictionary) -> void:
	slot.flash_left = 0.14

func _update_slot_style(slot: Dictionary) -> void:
	var style: StyleBoxFlat = slot.style
	if slot.fail_left > 0.0:
		style.bg_color = Color(0.62, 0.12, 0.1, 0.98)
		style.border_color = Color("ffb0a4")
		return
	var flashing: bool = slot.flash_left > 0.0 or slot.active
	style.bg_color = Color(0.18, 0.58, 0.48, 0.98) if flashing else Color(0.035, 0.05, 0.06, 0.9)
	style.border_color = Color("a5ffe7") if flashing else Color(0.43, 0.58, 0.56, 0.92)

func _update_cooldown(slot: Dictionary, remaining: float, duration: float) -> void:
	var overlay: ColorRect = slot.cooldown_overlay
	var label: Label = slot.cooldown_label
	var root: Control = slot.control
	if remaining <= 0.0:
		overlay.visible = false
		label.text = ""
		return
	var ratio := clampf(remaining / duration, 0.0, 1.0)
	overlay.visible = true
	overlay.size = Vector2(root.size.x, root.size.y * ratio)
	label.text = "%.1f" % remaining

func _on_skill_failed(slot_index: int, reason: String) -> void:
	if slot_index >= 1 and slot_index <= _skills.size():
		_skills[slot_index - 1].fail_left = 0.5
	_failure_label.text = "SKILL %d · %s" % [slot_index, reason.to_upper()]
	_failure_time_left = 1.0

func show_pickup(item: ItemDefinition, quantity: int) -> void:
	if not is_instance_valid(item):
		return
	_pickup_label.text = "PICKED UP · " + item.get_pickup_description(quantity)
	_pickup_time_left = 2.3

func show_pickup_rejected(item: ItemDefinition) -> void:
	if not is_instance_valid(item):
		return
	_pickup_label.text = "INVENTORY FULL · " + item.display_name + " remains on the ground"
	_pickup_time_left = 2.3
