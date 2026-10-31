extends CanvasLayer
## Shows live player stats and recent gameplay events for development debugging.
class_name DebugHUD

var _player: Player
var _stats_label: Label
var _events_label: Label
var _events: Array[String] = []
var _panel: PanelContainer
var _inventory_open := false
var _visible_before_inventory := true

func _ready() -> void:
	add_to_group("debug_hud")
	_build_ui()

func bind_player(player: Player) -> void:
	_player = player
	if is_instance_valid(_player) and not _player.inventory_ui.opened_changed.is_connected(set_inventory_open):
		_player.inventory_ui.opened_changed.connect(set_inventory_open)
		if _inventory_open:
			_visible_before_inventory = visible
			visible = false

func set_inventory_open(is_open: bool) -> void:
	if is_open == _inventory_open:
		return
	_inventory_open = is_open
	if is_open:
		_visible_before_inventory = visible
		visible = false
	else:
		visible = _visible_before_inventory

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_panel.visible = not _panel.visible
	if not _panel.visible or not is_instance_valid(_player):
		return
	var stats := _player.get_debug_stats()
	var skill_cooldowns: Array = stats.skill_cooldowns
	_stats_label.text = "FPS: %d\nHP: %.0f / %.0f     Anima: %.0f / %.0f\nSTR %.0f  FIN %.0f  ARK %.0f\nBasic attack: %.0f dmg  |  %.1fm  |  %.2fs cooldown\nTarget: %s\nSkills cooldowns: %.1f / %.1f / %.1f / %.1f / %.1f / %.1f\nDash: %.1fs cooldown  |  Invulnerable: %s" % [
		Engine.get_frames_per_second(), stats.health, stats.max_health, stats.anima, stats.max_anima,
		stats["str"], stats["fin"], stats["ark"],
		stats.damage, stats.range, stats.attack_cooldown, stats.target,
		skill_cooldowns[0], skill_cooldowns[1], skill_cooldowns[2], skill_cooldowns[3], skill_cooldowns[4], skill_cooldowns[5],
		stats.dash_cooldown, "YES" if stats.invulnerable else "NO"
	]
	_events_label.text = "RECENT EVENTS\n" + "\n".join(_events)

func log_event(message: String) -> void:
	_events.push_front("%s  %s" % [Time.get_time_string_from_system(), message])
	if _events.size() > 6:
		_events.resize(6)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(14, 14)
	_panel.scale = Vector2(0.5, 0.5)
	_panel.custom_minimum_size = Vector2(390, 230)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.06, 0.92)
	panel_style.border_color = Color(0.35, 0.78, 0.7, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(0)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 9.0
	panel_style.content_margin_bottom = 9.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	_panel.add_child(layout)
	var title := Label.new()
	title.text = "COMBAT DEBUG  [TAB]"
	title.add_theme_color_override("font_color", Color("8de3ce"))
	layout.add_child(title)
	_stats_label = Label.new()
	_stats_label.add_theme_color_override("font_color", Color("e5ece9"))
	layout.add_child(_stats_label)
	_events_label = Label.new()
	_events_label.add_theme_color_override("font_color", Color("f1c978"))
	_events_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(_events_label)
	var controls := Label.new()
	controls.text = "L-stick move · click-to-move facing · Q–Y / X-Y-RB-LB-RT-LT skills · 1–4 / D-pad items"
	controls.add_theme_color_override("font_color", Color("aab9b3"))
	controls.add_theme_font_size_override("font_size", 11)
	layout.add_child(controls)
