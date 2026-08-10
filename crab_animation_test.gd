extends Node3D

## Animation test for the supplied 63-bone alien crab.
const CRAB_SCENE := preload("res://assets/Rigged Alien Crab.glb")
const FEED_TARGET := preload("res://feed_target.gd")
var crab: Node3D
var feed_target: Node3D
var skeleton: Skeleton3D
var rest_rotations: Dictionary = {}
var elapsed := 0.0
var animation_mode := "SCUTTLE"
var camera: Camera3D
var zoom_target := 6.2
var orbit_yaw := 0.0
var orbit_pitch := 0.12
var orbiting := false
var mode_label: Label

func _ready() -> void:
	_build_world()
	crab = CRAB_SCENE.instantiate()
	crab.name = "AnimatedAlienCrab"
	crab.scale = Vector3.ONE * 3.5
	crab.position = Vector3(0, -0.62, 0)
	add_child(crab)
	feed_target = Node3D.new()
	feed_target.set_script(FEED_TARGET)
	feed_target.name = "FeedingPlayer"
	add_child(feed_target)
	_find_skeleton(crab)
	if skeleton:
		for bone_index in skeleton.get_bone_count():
			rest_rotations[bone_index] = skeleton.get_bone_pose_rotation(bone_index)
	_build_ui()

func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D and not skeleton:
		skeleton = node as Skeleton3D
	for child in node.get_children():
		_find_skeleton(child)

func _process(delta: float) -> void:
	elapsed += delta
	if skeleton:
		_animate_crab()
	if feed_target:
		if animation_mode == "EAT":
			feed_target.begin(Vector3(3.2, 0.2, 0.2), Vector3(0.15, -0.05, 0.18), Vector3.LEFT) if not feed_target.active else feed_target.tick(delta)
		else:
			feed_target.stop()
	_update_camera(delta)

func _animate_crab() -> void:
	var mode_phase := elapsed * (5.6 if animation_mode == "SCUTTLE" else 2.0)
	for bone_index in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		var rest: Quaternion = rest_rotations[bone_index]
		if bone_name == "bone_0":
			var body_pitch := sin(elapsed * 2.0) * (0.035 if animation_mode == "IDLE" else 0.07)
			var body_yaw := sin(elapsed * 1.2) * (0.04 if animation_mode != "THREAT" else 0.14)
			skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(Vector3.RIGHT, body_pitch) * Quaternion(Vector3.UP, body_yaw))
			continue
		var number := _bone_number(bone_name)
		var side := -1.0 if number % 2 == 0 else 1.0
		var phase_offset := float(number) * 0.31 + (PI if side < 0.0 else 0.0)
		var swing := 0.0
		var lift := 0.0
		match animation_mode:
			"EAT":
				swing = sin(elapsed * 5.0 + phase_offset) * 0.16
				lift = 0.08 + maxf(0.0, sin(elapsed * 5.0 + phase_offset)) * 0.11
			"IDLE":
				swing = sin(elapsed * 1.7 + phase_offset) * 0.045
				lift = cos(elapsed * 1.5 + phase_offset) * 0.025
			"SCUTTLE":
				swing = sin(mode_phase + phase_offset) * 0.22
				lift = maxf(0.0, sin(mode_phase + phase_offset)) * 0.16
			"THREAT":
				swing = sin(elapsed * 2.4 + phase_offset) * 0.08
				lift = 0.16 + sin(elapsed * 2.0 + phase_offset) * 0.06
			"PINCH":
				swing = sin(elapsed * 4.0 + phase_offset) * 0.32
				lift = cos(elapsed * 3.5 + phase_offset) * 0.10
		var axis := Vector3.FORWARD if number % 3 else Vector3.RIGHT
		skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(axis, swing) * Quaternion(Vector3.RIGHT, lift * side))

func _bone_number(name: String) -> int:
	var parts := name.split("_")
	return int(parts[1]) if parts.size() > 1 else 0

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0a1520")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7e9eb8")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("#ffd0a0")
	key.light_energy = 2.3
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 145, 10)
	rim.light_color = Color("#62c9ff")
	rim.light_energy = 1.4
	add_child(rim)
	var floor := MeshInstance3D.new()
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 4.2
	floor_mesh.bottom_radius = 4.5
	floor_mesh.height = 0.25
	floor_mesh.radial_segments = 12
	floor.mesh = floor_mesh
	floor.position.y = -0.82
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#211d25")
	floor_mat.roughness = 0.9
	floor.material_override = floor_mat
	add_child(floor)
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.1, 6.2)
	camera.fov = 43.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.15, 0), Vector3.UP)

func _update_camera(delta: float) -> void:
	if not camera:
		return
	var radius := lerpf(camera.position.distance_to(Vector3(0, 0.1, 0)), zoom_target, 1.0 - exp(-delta * 8.0))
	var horizontal := cos(orbit_pitch) * radius
	var target := Vector3(0, 0.1, 0)
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
		match event.keycode:
			KEY_1: _set_mode("IDLE")
			KEY_2: _set_mode("SCUTTLE")
			KEY_3: _set_mode("THREAT")
			KEY_4: _set_mode("PINCH")
			KEY_5: _set_mode("EAT")
			KEY_R:
				orbit_yaw = 0.0
				orbit_pitch = 0.12

func _set_mode(mode: String) -> void:
	animation_mode = mode
	if mode_label:
		mode_label.text = "MODE: %s   |   1 idle   2 scuttle   3 threat   4 pinch   5 eat player" % mode

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.035, 0.065, 0.86)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(650, 70)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "ALIEN CRAB ANIMATION TEST"
	title.position = Vector2(38, 29)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#ffd0a0"))
	layer.add_child(title)
	mode_label = Label.new()
	mode_label.position = Vector2(39, 57)
	mode_label.add_theme_font_size_override("font_size", 14)
	mode_label.add_theme_color_override("font_color", Color("#c2e7ff"))
	layer.add_child(mode_label)
	_set_mode(animation_mode)
