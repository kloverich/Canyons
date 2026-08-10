extends Node3D

## Leech-only presentation. The supplied GLB contains a skinned mesh and
## deform chain, but no authored action, so this creates a looping crawl from
## the imported DEF bones at runtime.
const LEECH_SCENE := preload("res://assets/leech.glb")
const FEED_TARGET := preload("res://feed_target.gd")
var leech: Node3D
var feed_target: Node3D
var eating := false
var hint: Label
var skeletons: Array[Skeleton3D] = []
var deform_bones: Array[Dictionary] = []
var elapsed := 0.0
var camera: Camera3D
var zoom_target := 3.2
var orbit_yaw := 0.0
var orbit_pitch := 0.08
var orbit_target := Vector3(0, -0.08, 0)
var orbiting_camera := false

func _ready() -> void:
	leech = LEECH_SCENE.instantiate()
	leech.name = "AnimatedLeech"
	leech.scale = Vector3.ONE * 3.4
	leech.position = Vector3(0, -0.55, 0)
	add_child(leech)
	feed_target = Node3D.new()
	feed_target.set_script(FEED_TARGET)
	add_child(feed_target)
	var layer := CanvasLayer.new()
	add_child(layer)
	hint = Label.new()
	hint.text = "LEECH  |  2: eat player  |  drag: orbit  wheel: zoom  |  Esc: launcher"
	hint.position = Vector2(24, 24)
	hint.add_theme_font_size_override("font_size", 17)
	layer.add_child(hint)
	camera = get_node("Camera3D") as Camera3D
	_collect_skeletons(leech)
	for skeleton in skeletons:
		for bone_index in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone_index)
			if bone_name.begins_with("DEF-"):
				deform_bones.append({
					"skeleton": skeleton,
					"index": bone_index,
					"name": bone_name,
					"rest": skeleton.get_bone_pose_rotation(bone_index),
					"rest_scale": skeleton.get_bone_pose_scale(bone_index),
				})
	deform_bones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _bone_order(String(a["name"])) < _bone_order(String(b["name"]))
	)

func _collect_skeletons(node: Node) -> void:
	if node is Skeleton3D:
		skeletons.append(node as Skeleton3D)
	for child in node.get_children():
		_collect_skeletons(child)

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(camera):
		var current_radius := camera.position.distance_to(orbit_target)
		current_radius = lerpf(current_radius, zoom_target, 1.0 - exp(-delta * 8.0))
		var horizontal := cos(orbit_pitch) * current_radius
		var desired_camera := orbit_target + Vector3(
			sin(orbit_yaw) * horizontal,
			sin(orbit_pitch) * current_radius,
			cos(orbit_yaw) * horizontal
		)
		camera.position = camera.position.lerp(desired_camera, 1.0 - exp(-delta * 10.0))
		camera.look_at(orbit_target, Vector3.UP)
	var cycle := fmod(elapsed / 3.6, 1.0)
	for item in deform_bones.size():
		var entry: Dictionary = deform_bones[item]
		var skeleton: Skeleton3D = entry["skeleton"]
		var bone_index: int = entry["index"]
		var rest: Quaternion = entry["rest"]
		var body_t := float(item) / float(maxi(1, deform_bones.size() - 1))
		var local_cycle := fposmod(cycle - body_t * 0.075, 1.0)
		var middle_envelope := sin(PI * body_t)
		var contract_phase := _phase_window(local_cycle, 0.50, 0.88)
		var travel_phase := TAU * (cycle * 1.08 - body_t * 0.92)
		var head_influence := smoothstep(0.62, 1.0, body_t)

		# The large arch belongs to the contraction phase. A much smaller
		# lateral ripple travels through it, while the head explores between
		# sucker placements.
		var arch := sin(PI * body_t) * sin(PI * contract_phase) * 0.26
		var ripple := sin(travel_phase) * (0.035 + middle_envelope * 0.055)
		var head_search := sin(elapsed * 1.35) * head_influence * 0.10
		var bend := ripple + head_search
		var lift := arch + cos(travel_phase) * middle_envelope * 0.035
		var stretch := lerpf(1.0, _crawl_stretch(local_cycle), middle_envelope)
		skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(Vector3.FORWARD, bend) * Quaternion(Vector3.RIGHT, lift))
		var rest_scale: Vector3 = entry["rest_scale"]
		# Preserve approximate volume: a lengthening section becomes slimmer,
		# and a contracting section swells slightly.
		var girth := 1.0 / sqrt(maxf(stretch, 0.72))
		var endness := pow(abs(body_t * 2.0 - 1.0), 6.0)
		var sucker_spread := 1.0 + endness * _sucker_pressure(cycle, body_t) * 0.10
		skeleton.set_bone_pose_scale(bone_index, rest_scale * Vector3(girth * sucker_spread, stretch, girth * sucker_spread))
	if is_instance_valid(leech):
		# A small weight transfer sells the change between rear and front
		# anchoring without letting the exhibit drift out of frame.
		leech.position.x = sin(TAU * cycle - PI * 0.5) * 0.055
		leech.position.y = -0.55 + sin(PI * _phase_window(cycle, 0.48, 0.88)) * 0.035
		leech.rotation.z = sin(elapsed * 0.72) * 0.025
	if feed_target:
		if eating:
			feed_target.begin(Vector3(2.0, -0.2, 0.0), Vector3(0.52, -0.22, 0.0), Vector3.LEFT) if not feed_target.active else feed_target.tick(delta)
		else:
			feed_target.stop()

func _crawl_stretch(phase: float) -> float:
	if phase < 0.38:
		return lerpf(1.0, 1.20, smoothstep(0.02, 0.38, phase))
	if phase < 0.50:
		return 1.20
	if phase < 0.88:
		return lerpf(1.20, 0.90, smoothstep(0.50, 0.88, phase))
	return lerpf(0.90, 1.0, smoothstep(0.88, 1.0, phase))

func _phase_window(phase: float, start: float, finish: float) -> float:
	return clampf((phase - start) / (finish - start), 0.0, 1.0)

func _sucker_pressure(phase: float, body_t: float) -> float:
	# Posterior sucker is planted while extending; anterior sucker is planted
	# while the body catches up.
	if body_t < 0.5:
		return 1.0 - smoothstep(0.40, 0.56, phase)
	return smoothstep(0.40, 0.56, phase) * (1.0 - smoothstep(0.88, 1.0, phase))

func _bone_order(bone_name: String) -> int:
	if bone_name == "DEF-Bone":
		return 0
	return bone_name.get_slice(".", 1).to_int() + 1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://test_launcher.tscn")
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			orbiting_camera = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom_target - 0.35)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom_target + 0.35)
	elif event is InputEventMouseMotion and orbiting_camera:
		orbit_yaw -= event.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.006, -0.85, 0.85)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			_set_zoom(zoom_target - 0.35)
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_set_zoom(zoom_target + 0.35)
		elif event.keycode == KEY_R:
			orbit_yaw = 0.0
			orbit_pitch = 0.08
		elif event.keycode == KEY_2:
			eating = not eating

func _set_zoom(value: float) -> void:
	zoom_target = clampf(value, 1.55, 6.5)
