extends Control

const TESTS := [
	["CANYON PLATFORMER PREVIEW", "res://canyon_platformer_preview.tscn", "Seeded open-air canyon landscape with fly camera and surface-crawling leeches."],
	["ALIEN CRAB ANIMATION TEST", "res://crab_animation_test.tscn", "Rigged crab idle, scuttle, threat, and pinch poses."],
	["ALIEN JELLYFISH ANIMATION TEST", "res://jellyfish_animation_test.tscn", "Floating bell pulse, tentacle wave, and spread poses."],
	["ANCHORED ALIEN ANEMONE TEST", "res://anemone_animation_test.tscn", "Fixed base with neck stretch and current-driven tentacle motion."],
	["LEECH SURFACE CRAWLER", "res://leech_showcase.tscn", "Standalone leech view with orbit camera and zoom."],
	["CREATURE SKIN GALLERY", "res://main.tscn", "All procedural creature specimens, including the animated worm."],
	["ALIEN WORM ANIMATION", "res://alien_worm_showcase.tscn", "Procedural worm motion and peristaltic shader test."],
]
var selected := 0
var buttons: Array[Button] = []

func _ready() -> void:
	_build_background()
	_build_panel()

func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("#07111d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var glow := ColorRect.new()
	glow.color = Color(0.10, 0.18, 0.28, 0.30)
	glow.position = Vector2(0, 0)
	glow.size = Vector2(960, 7)
	add_child(glow)

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(90, 58)
	panel.size = Vector2(840, 560)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.032, 0.06, 0.96)
	style.border_color = Color("#31536d")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := Label.new()
	title.text = "CANYONS  /  VISUAL TEST LAB"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#ffd0a0"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose a scene to inspect"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#8db6cd"))
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 9
	column.add_child(spacer)
	for i in TESTS.size():
		var button := Button.new()
		button.text = "%d   %s\n      %s" % [i + 1, TESTS[i][0], TESTS[i][2]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 66)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_open_test.bind(i))
		column.add_child(button)
		buttons.append(button)
	var help := Label.new()
	help.text = "Enter: open selected    Up/Down: choose    Esc: return here from a test"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("#6e93aa"))
	column.add_child(help)
	_update_selection()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_DOWN, KEY_S]:
			selected = (selected + 1) % TESTS.size()
			_update_selection()
		elif event.keycode in [KEY_UP, KEY_W]:
			selected = (selected - 1 + TESTS.size()) % TESTS.size()
			_update_selection()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_open_test(selected)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
			selected = event.keycode - KEY_1
			_open_test(selected)

func _update_selection() -> void:
	for i in buttons.size():
		buttons[i].modulate = Color("#ffd0a0") if i == selected else Color("#d6e8f0")
		if i == selected:
			buttons[i].grab_focus()

func _open_test(index: int) -> void:
	get_tree().change_scene_to_file(TESTS[index][1])
