extends Node3D

## Floating jellyfish animation test. The GLB has a central bell bone and
## seventeen tentacle chains; the test drives both as a coordinated swim.
const JELLY_SCENE := preload("res://assets/alient-jellyfish-rigged.glb")
const FEED_TARGET := preload("res://feed_target.gd")
var jelly: Node3D
var feed_target: Node3D
var skeleton: Skeleton3D
var rest_rotations: Dictionary = {}
var rest_scales: Dictionary = {}
var elapsed := 0.0
var animation_mode := "PULSE"
var camera: Camera3D
var zoom_target := 6.0
var orbit_yaw := 0.0
var orbit_pitch := 0.1
var orbiting := false
var mode_label: Label

func _ready() -> void:
	_build_world()
	jelly = JELLY_SCENE.instantiate()
	jelly.name = "AnimatedAlienJellyfish"
	jelly.scale = Vector3.ONE * 3.0
	jelly.position = Vector3(0, 0.1, 0)
	add_child(jelly)
	feed_target = Node3D.new()
	feed_target.set_script(FEED_TARGET)
	feed_target.name = "FeedingPlayer"
	add_child(feed_target)
	_find_skeleton(jelly)
	if skeleton:
		for bone_index in skeleton.get_bone_count():
			rest_rotations[bone_index] = skeleton.get_bone_pose_rotation(bone_index)
			rest_scales[bone_index] = skeleton.get_bone_pose_scale(bone_index)
	_build_ui()

func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D and not skeleton:
		skeleton = node as Skeleton3D
	for child in node.get_children():
		_find_skeleton(child)

func _process(delta: float) -> void:
	elapsed += delta
	if jelly:
		var pulse := 1.0 + sin(elapsed * 3.0) * (0.15 if animation_mode == "PULSE" else 0.075)
		jelly.scale = Vector3(3.0 / sqrt(pulse), 3.0 * pulse, 3.0 / sqrt(pulse))
		jelly.position.y = 0.15 + sin(elapsed * 1.1) * 0.22
		jelly.rotation.y = sin(elapsed * 0.45) * 0.16
		jelly.rotation.z = sin(elapsed * 1.3) * 0.055
	if feed_target:
		if animation_mode == "EAT":
			feed_target.begin(Vector3(0.0, -2.4, 0.15), Vector3(0.0, -1.05, 0.0), Vector3(0.0, -0.35, 0.0), Vector3.UP, "tear_apart") if not feed_target.active else feed_target.tick(delta)
		else:
			feed_target.stop()
	if skeleton:
		var bell_index := skeleton.find_bone("bone_0")
		if bell_index >= 0:
			var bell_rest: Quaternion = rest_rotations[bell_index]
			var bell_rest_scale: Vector3 = rest_scales[bell_index]
			var bell_phase := elapsed * 3.0
			var bell_flex := sin(bell_phase) * (0.19 if animation_mode == "PULSE" else (0.15 if animation_mode == "EAT" else 0.065))
			var bell_tilt := cos(bell_phase * 0.72) * 0.075
			skeleton.set_bone_pose_rotation(bell_index, bell_rest * Quaternion(Vector3.RIGHT, bell_flex) * Quaternion(Vector3.FORWARD, bell_tilt))
			skeleton.set_bone_pose_scale(bell_index, bell_rest_scale * Vector3(1.08 - bell_flex * 0.18, 1.0 + bell_flex, 1.08 + bell_flex * 0.18))
		_animate_tentacles()
	_update_camera(delta)

func _animate_tentacles() -> void:
	for bone_index in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		if bone_name == "bone_0":
			continue
		var number := _bone_number(bone_name)
		var chain_phase := elapsed * (3.0 if animation_mode == "WAVE" else 2.0) + number * 0.42
		var amplitude := 0.16 if animation_mode == "WAVE" else (0.13 if animation_mode == "EAT" else 0.07)
		if animation_mode == "SPREAD":
			amplitude = 0.20
		var sway := sin(chain_phase) * amplitude
		var curl := cos(chain_phase * 0.83) * amplitude * 0.7
		var rest: Quaternion = rest_rotations[bone_index]
		var rest_scale: Vector3 = rest_scales[bone_index]
		skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(Vector3.FORWARD, sway) * Quaternion(Vector3.RIGHT, curl))
		if animation_mode == "SPREAD":
			var spread := 1.0 + sin(float(number) * 0.7) * 0.08
			skeleton.set_bone_pose_scale(bone_index, rest_scale * Vector3(spread, 1.0, spread))
		else:
			skeleton.set_bone_pose_scale(bone_index, rest_scale)

func _bone_number(name: String) -> int:
	var parts := name.split("_")
	return int(parts[1]) if parts.size() > 1 else 0

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#071322")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#709cc0")
	env.ambient_light_energy = 0.60
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var environment_resource := Environment.new()
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_color = Color("#9edbff")
	key.light_energy = 2.2
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 145, 5)
	rim.light_color = Color("#d17dff")
	rim.light_energy = 1.4
	add_child(rim)
	var camera_target := Vector3(0, 0.25, 0)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 6.0)
	camera.fov = 43.0
	add_child(camera)
	camera.look_at(camera_target, Vector3.UP)

func _update_camera(delta: float) -> void:
	if not camera:
		return
	var target := Vector3(0, 0.25, 0)
	var radius := lerpf(camera.position.distance_to(target), zoom_target, 1.0 - exp(-delta * 8.0))
	var horizontal := cos(orbit_pitch) * radius
	var desired := target + Vector3(sin(orbit_yaw) * horizontal, sin(orbit_pitch) * radius, cos(orbit_yaw) * horizontal)
	camera.position = camera.position.lerp(desired, 1.0 - exp(-delta * 9.0))
	camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://test_launcher.tscn")
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = maxf(3.0, zoom_target - 0.45)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = minf(10.0, zoom_target + 0.45)
	elif event is InputEventMouseMotion and orbiting:
		orbit_yaw -= event.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.006, -0.7, 0.75)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1: _set_mode("PULSE")
		elif event.keycode == KEY_2: _set_mode("WAVE")
		elif event.keycode == KEY_3: _set_mode("SPREAD")
		elif event.keycode == KEY_4: _set_mode("EAT")
		elif event.keycode == KEY_R:
			orbit_yaw = 0.0
			orbit_pitch = 0.1

func _set_mode(mode: String) -> void:
	animation_mode = mode
	if mode_label:
		mode_label.text = "MODE: %s   |   1 pulse   2 tentacle wave   3 spread   4 eat player" % mode

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.025, 0.08, 0.84)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(620, 70)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "ALIEN JELLYFISH ANIMATION TEST"
	title.position = Vector2(38, 29)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#d6a5ff"))
	layer.add_child(title)
	mode_label = Label.new()
	mode_label.position = Vector2(39, 57)
	mode_label.add_theme_font_size_override("font_size", 14)
	mode_label.add_theme_color_override("font_color", Color("#c8e5ff"))
	layer.add_child(mode_label)
	_set_mode(animation_mode)
