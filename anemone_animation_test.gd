extends Node3D

## Anchored sea-anemone test. The root/base never translates or bobs; only the
## neck and tentacle chain flex, as they would while attached to rock or sand.
const ANEMONE_SCENE := preload("res://assets/rigged-sea-anenome.glb")
const FEED_TARGET := preload("res://feed_target.gd")
var anemone: Node3D
var feed_target: Node3D
var skeleton: Skeleton3D
var rest_rotations: Dictionary = {}
var rest_scales: Dictionary = {}
var elapsed := 0.0
var animation_mode := "CURRENT"
var camera: Camera3D
var zoom_target := 5.8
var orbit_yaw := 0.0
var orbit_pitch := 0.12
var orbiting := false
var mode_label: Label

func _ready() -> void:
	_build_world()
	anemone = ANEMONE_SCENE.instantiate()
	anemone.name = "AnchoredAlienAnemone"
	anemone.scale = Vector3.ONE * 3.5
	anemone.position = Vector3(0, -0.72, 0)
	add_child(anemone)
	feed_target = Node3D.new()
	feed_target.set_script(FEED_TARGET)
	feed_target.name = "FeedingPlayer"
	add_child(feed_target)
	_find_skeleton(anemone)
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
	if skeleton:
		_animate_anemone()
	if feed_target:
		if animation_mode == "EAT":
			feed_target.begin(Vector3(2.8, 0.15, 0.0), Vector3(1.05, 0.58, 0.0), Vector3(0.0, 0.18, 0.0), Vector3.LEFT, "tear_apart") if not feed_target.active else feed_target.tick(delta)
		else:
			feed_target.stop()
	_update_camera(delta)

func _animate_anemone() -> void:
	var wave_speed := 2.3 if animation_mode == "CURRENT" else (3.0 if animation_mode == "EAT" else 3.6)
	for bone_index in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		var number := _bone_number(bone_name)
		var rest: Quaternion = rest_rotations[bone_index]
		var rest_scale: Vector3 = rest_scales[bone_index]
		if bone_name == "bone_0":
			# Small neck stretch and a slow crown tilt; the world/root stays fixed.
			var neck := sin(elapsed * 1.8) * (0.10 if animation_mode == "CURRENT" else (0.22 if animation_mode == "EAT" else 0.17))
			skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(Vector3.FORWARD, neck))
			skeleton.set_bone_pose_scale(bone_index, rest_scale * Vector3(0.96, 1.0 + sin(elapsed * 1.8) * 0.14, 0.96))
			continue
		var phase := elapsed * wave_speed - float(number) * 0.31
		var bend := sin(phase) * (0.12 + float(number) * 0.004)
		if animation_mode == "EAT":
			# One leading tentacle reaches sideways, curls around the target, and
			# retracts toward the fixed mouth while the rest keep a current wave.
			var grab := sin(elapsed * 2.2 + float(number) * 0.35)
			bend += grab * (0.18 + float(number) * 0.008)
		var twist := cos(phase * 0.76) * 0.07
		skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(Vector3.FORWARD, bend) * Quaternion(Vector3.RIGHT, twist))
		skeleton.set_bone_pose_scale(bone_index, rest_scale)

func _bone_number(name: String) -> int:
	var parts := name.split("_")
	return int(parts[1]) if parts.size() > 1 else 0

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#081622")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7b9db0")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -30, 0)
	key.light_color = Color("#ffd0a0")
	key.light_energy = 2.1
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 145, 8)
	fill.light_color = Color("#58c9e7")
	fill.light_energy = 1.3
	add_child(fill)
	var ground := MeshInstance3D.new()
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 3.3
	ground_mesh.bottom_radius = 3.5
	ground_mesh.height = 0.18
	ground_mesh.radial_segments = 32
	ground.mesh = ground_mesh
	ground.position.y = -0.83
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#1c2525")
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	add_child(ground)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.9, 5.8)
	camera.fov = 44.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.25, 0), Vector3.UP)

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
			zoom_target = maxf(3.0, zoom_target - 0.4)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = minf(9.0, zoom_target + 0.4)
	elif event is InputEventMouseMotion and orbiting:
		orbit_yaw -= event.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.006, -0.7, 0.75)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1: _set_mode("CURRENT")
		elif event.keycode == KEY_2: _set_mode("SURGE")
		elif event.keycode == KEY_3: _set_mode("EAT")
		elif event.keycode == KEY_R:
			orbit_yaw = 0.0
			orbit_pitch = 0.12

func _set_mode(mode: String) -> void:
	animation_mode = mode
	if mode_label:
		mode_label.text = "MODE: %s   |   1 current   2 stronger surge   3 eat player" % mode

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.035, 0.055, 0.86)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(600, 70)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "ANCHORED ALIEN ANEMONE ANIMATION TEST"
	title.position = Vector2(38, 29)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#f2b6a7"))
	layer.add_child(title)
	mode_label = Label.new()
	mode_label.position = Vector2(39, 57)
	mode_label.add_theme_font_size_override("font_size", 14)
	mode_label.add_theme_color_override("font_color", Color("#c8e5df"))
	layer.add_child(mode_label)
	_set_mode(animation_mode)
