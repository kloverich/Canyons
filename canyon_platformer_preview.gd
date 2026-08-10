extends Node3D

## One-screen 2.5D platforming room built directly over the supplied concept.
## The art is the level; invisible 3D collision follows its visible ledges.
const BACKGROUND := preload("res://design-concepts/SideScroller.png")
const PLAYER_SCENE := preload("res://assets/black+tactical+suit+3d+model.glb")
const CRAB_SCENE := preload("res://assets/Rigged Alien Crab.glb")
const ANEMONE_SCENE := preload("res://assets/rigged-sea-anenome.glb")
const JELLY_SCENE := preload("res://assets/alient-jellyfish-rigged.glb")
const LEECH_ACTOR := preload("res://leech_actor.gd")

const LEVEL_WIDTH := 48.0
const LEVEL_HEIGHT := 27.0
const LEVEL_CENTER_Y := 4.5
const GRAVITY := 24.0
const RUN_SPEED := 6.5
const JUMP_SPEED := 10.5

@export var landscape_seed := 481516
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var player: CharacterBody3D
var player_model: Node3D
var player_animator: AnimationPlayer
var current_player_animation := ""
var facing_direction := 1.0
var creatures: Array[Dictionary] = []
var elapsed := 0.0
var seed_label: Label

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			landscape_seed = argument.trim_prefix("--seed=").to_int()
	rng.seed = landscape_seed
	_build_world()
	_build_collision_map()
	_build_player()
	_place_creatures()
	_build_interface()

func _physics_process(delta: float) -> void:
	if not player:
		return
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A): direction = -1.0
	if Input.is_key_pressed(KEY_D): direction = 1.0
	player.velocity.x = move_toward(player.velocity.x, direction * RUN_SPEED, 28.0 * delta)
	player.velocity.z = 0.0
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	if (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_W)) and player.is_on_floor():
		player.velocity.y = JUMP_SPEED
	player.move_and_slide()
	player.position.z = 1.1
	player.position.x = clampf(player.position.x, -23.2, 23.2)
	if player.position.y < -12.0:
		player.position = Vector3(-20.5, 12.4, 1.1)
		player.velocity = Vector3.ZERO
	if player_model and absf(direction) > 0.01:
		facing_direction = direction
		var facing_angle := -PI * 0.5 if direction > 0.0 else PI * 0.5
		player_model.rotation.y = lerp_angle(player_model.rotation.y, facing_angle, 1.0 - exp(-delta * 18.0))
	_update_player_animation(direction)

func _process(delta: float) -> void:
	elapsed += delta
	_animate_creatures()
	_update_follow_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://test_launcher.tscn")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(5.5, camera.size - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(27.0, camera.size + 1.0)

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#120b09")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d39d7c")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, LEVEL_CENTER_Y, 30.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.look_at(Vector3(0.0, LEVEL_CENTER_Y, 0.0))

	var backdrop := MeshInstance3D.new()
	backdrop.name = "SideScrollerArtwork"
	var quad := QuadMesh.new()
	quad.size = Vector2(LEVEL_WIDTH, LEVEL_HEIGHT)
	backdrop.mesh = quad
	backdrop.position = Vector3(0.0, LEVEL_CENTER_Y, -8.0)
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_material.albedo_texture = BACKGROUND
	backdrop_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	backdrop.material_override = backdrop_material
	add_child(backdrop)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color("#ffd0a3")
	key.light_energy = 2.4
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 5)
	rim.light_color = Color("#52d8ff")
	rim.light_energy = 1.25
	add_child(rim)

func _build_collision_map() -> void:
	# Coordinates are measured from the visible top edges in SideScroller.png
	# and converted to this 48 x 27 orthographic room.
	_add_platform("Ground", Vector3(0.0, -8.55, 1.0), Vector3(48.0, 0.55, 4.0))
	_add_platform("LeftUpperDoor", Vector3(-21.2, 11.02, 1.0), Vector3(5.8, 0.46, 4.0))
	_add_platform("LeftHighShelf", Vector3(-14.95, 5.65, 1.0), Vector3(6.9, 0.46, 4.0))
	_add_platform("LeftMiddleShelf", Vector3(-18.8, 1.05, 1.0), Vector3(10.3, 0.48, 4.0))
	_add_platform("LeftLowShelf", Vector3(-11.95, -3.20, 1.0), Vector3(5.7, 0.46, 4.0))
	_add_platform("CenterHigh", Vector3(-4.15, 7.92, 1.0), Vector3(7.0, 0.48, 4.0))
	_add_platform("CenterLeft", Vector3(-7.1, 1.08, 1.0), Vector3(5.9, 0.48, 4.0))
	_add_platform("CenterMain", Vector3(-0.45, -2.78, 1.0), Vector3(10.2, 0.50, 4.0))
	_add_platform("CenterStep", Vector3(4.25, 0.95, 1.0), Vector3(4.4, 0.48, 4.0))
	_add_platform("CenterTallStep", Vector3(5.70, 2.55, 1.0), Vector3(3.4, 0.46, 4.0))
	_add_platform("CenterLowStep", Vector3(7.50, -3.18, 1.0), Vector3(3.25, 0.46, 4.0))
	_add_platform("RightPortalShelf", Vector3(16.60, 7.45, 1.0), Vector3(14.8, 0.50, 4.0))
	_add_platform("RightMiddleShelf", Vector3(17.45, 2.48, 1.0), Vector3(13.1, 0.50, 4.0))
	_add_platform("RightLowerShelf", Vector3(18.70, -0.78, 1.0), Vector3(10.7, 0.48, 4.0))
	_add_platform("RightBottomShelf", Vector3(14.75, -5.43, 1.0), Vector3(10.3, 0.50, 4.0))
	_add_wall("LeftBoundary", Vector3(-24.0, 4.5, 1.0), Vector3(0.5, 27.0, 4.0))
	_add_wall("RightBoundary", Vector3(24.0, 4.5, 1.0), Vector3(0.5, 27.0, 4.0))

func _add_platform(node_name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_wall(node_name: String, position: Vector3, size: Vector3) -> void:
	_add_platform(node_name, position, size)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "ControllableTacticalSuit"
	player.position = Vector3(-21.0, 12.25, 1.1)
	player.floor_snap_length = 0.22
	player.floor_max_angle = deg_to_rad(50.0)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	player.add_child(collision)
	player_model = PLAYER_SCENE.instantiate()
	player_model.name = "TacticalSuitVisual"
	player_model.scale = Vector3.ONE * 1.25
	player_model.position.y = -0.88
	player.add_child(player_model)
	add_child(player)
	camera.position.x = -18.0
	camera.position.y = 10.5
	player_animator = _find_animation_player(player_model)
	if player_animator:
		_set_animation_loop("NlaTrack", true)
		_set_animation_loop("NlaTrack_001", true)
		_set_animation_loop("NlaTrack_003", true)
		_play_player_animation("NlaTrack")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _set_animation_loop(animation_name: StringName, enabled: bool) -> void:
	if not player_animator or not player_animator.has_animation(animation_name):
		return
	var animation := player_animator.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR if enabled else Animation.LOOP_NONE

func _play_player_animation(animation_name: StringName, blend := 0.16, speed := 1.0) -> void:
	if not player_animator or not player_animator.has_animation(animation_name):
		return
	if current_player_animation == animation_name:
		player_animator.speed_scale = speed
		return
	current_player_animation = animation_name
	player_animator.play(animation_name, blend, speed)

func _update_player_animation(direction: float) -> void:
	if not player_animator:
		return
	if not player.is_on_floor():
		if player.velocity.y > 0.15:
			_play_player_animation("NlaTrack_004", 0.10, 1.15)
		else:
			_play_player_animation("NlaTrack_002", 0.14, 1.0)
	elif absf(direction) > 0.05 or absf(player.velocity.x) > 0.5:
		var speed_ratio := absf(player.velocity.x) / RUN_SPEED
		if speed_ratio < 0.62:
			_play_player_animation("NlaTrack_001", 0.12, clampf(speed_ratio * 1.45, 0.65, 1.0))
		else:
			_play_player_animation("NlaTrack_003", 0.12, clampf(speed_ratio, 0.85, 1.25))
	else:
		_play_player_animation("NlaTrack", 0.22, 1.0)

func _update_follow_camera(delta: float) -> void:
	if not camera or not player:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_width := camera.size * aspect * 0.5
	var half_height := camera.size * 0.5
	var look_ahead := player.velocity.x / RUN_SPEED * minf(2.1, camera.size * 0.15)
	var min_x := -LEVEL_WIDTH * 0.5 + half_width
	var max_x := LEVEL_WIDTH * 0.5 - half_width
	var min_y := LEVEL_CENTER_Y - LEVEL_HEIGHT * 0.5 + half_height
	var max_y := LEVEL_CENTER_Y + LEVEL_HEIGHT * 0.5 - half_height
	var target_x := clampf(player.position.x + look_ahead, min_x, max_x) if min_x <= max_x else 0.0
	var target_y := clampf(player.position.y + 0.8, min_y, max_y) if min_y <= max_y else LEVEL_CENTER_Y
	var target := Vector3(target_x, target_y, camera.position.z)
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 5.5))

func _place_creatures() -> void:
	_add_rigged_creature("CRAB", CRAB_SCENE, Vector3(-6.8, 1.65, 0.7), Vector3.ONE * 2.25)
	_add_rigged_creature("CRAB", CRAB_SCENE, Vector3(16.8, 8.05, 0.7), Vector3.ONE * 1.85)
	_add_rigged_creature("ANEMONE", ANEMONE_SCENE, Vector3(-1.0, -2.28, 0.65), Vector3.ONE * 2.25)
	_add_rigged_creature("ANEMONE", ANEMONE_SCENE, Vector3(18.0, 2.98, 0.65), Vector3.ONE * 1.9)
	var wall_anemone := _add_rigged_creature("ANEMONE", ANEMONE_SCENE, Vector3(-21.0, 4.0, 0.65), Vector3.ONE * 1.7)
	wall_anemone.rotation.z = -PI * 0.5
	_add_rigged_creature("JELLY", JELLY_SCENE, Vector3(2.2, 9.4, 0.45), Vector3.ONE * 2.35)
	_add_rigged_creature("JELLY", JELLY_SCENE, Vector3(10.8, 5.2, 0.45), Vector3.ONE * 1.75)
	_add_leech(Vector3(-13.0, -2.72, 0.75), Vector3.UP, Vector3.RIGHT)
	_add_leech(Vector3(23.45, 0.4, 0.75), Vector3.LEFT, Vector3.DOWN, -4.8, 6.8)

func _add_rigged_creature(kind: String, scene: PackedScene, position: Vector3, scale_value: Vector3) -> Node3D:
	var creature := scene.instantiate()
	creature.name = "Canyon%s" % kind.to_pascal_case()
	creature.position = position
	creature.scale = scale_value
	add_child(creature)
	var skeleton := _find_skeleton(creature)
	var rotations: Dictionary = {}
	var scales: Dictionary = {}
	if skeleton:
		for i in skeleton.get_bone_count():
			rotations[i] = skeleton.get_bone_pose_rotation(i)
			scales[i] = skeleton.get_bone_pose_scale(i)
	creatures.append({"kind": kind, "root": creature, "base": position, "base_scale": scale_value, "skeleton": skeleton, "rotations": rotations, "scales": scales, "phase": rng.randf_range(0.0, TAU)})
	return creature

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _animate_creatures() -> void:
	for entry in creatures:
		var root: Node3D = entry["root"]
		var kind: String = entry["kind"]
		var phase: float = entry["phase"]
		var skeleton: Skeleton3D = entry["skeleton"]
		if kind == "JELLY":
			var base: Vector3 = entry["base"]
			var base_scale: Vector3 = entry["base_scale"]
			root.position = base + Vector3(sin(elapsed * 0.7 + phase) * 0.45, sin(elapsed * 1.2 + phase) * 0.55, 0.0)
			var pulse := 1.0 + sin(elapsed * 3.0 + phase) * 0.12
			root.scale = Vector3(base_scale.x / sqrt(pulse), base_scale.y * pulse, base_scale.z / sqrt(pulse))
		if not skeleton:
			continue
		var rests: Dictionary = entry["rotations"]
		for bone_index in skeleton.get_bone_count():
			var rest: Quaternion = rests[bone_index]
			var offset := float(bone_index) * 0.31 + phase
			var amount := 0.06
			if kind == "CRAB": amount = 0.13
			elif kind == "ANEMONE": amount = 0.18
			elif kind == "JELLY": amount = 0.12
			skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(Vector3.FORWARD, sin(elapsed * 2.1 + offset) * amount) * Quaternion(Vector3.RIGHT, cos(elapsed * 1.7 + offset) * amount * 0.55))

func _add_leech(position: Vector3, normal: Vector3, direction: Vector3, min_y := -1000.0, max_y := 1000.0) -> void:
	var leech := CharacterBody3D.new()
	leech.name = "CanyonLeech"
	leech.set_script(LEECH_ACTOR)
	leech.position = position
	leech.set("display_scale", 0.45)
	leech.set("crawl_speed", 0.62)
	leech.set("initial_surface_normal", normal)
	leech.set("initial_travel_direction", direction)
	leech.set("wall_patrol", absf(normal.dot(Vector3.UP)) < 0.55)
	leech.set("wall_min_y", min_y)
	leech.set("wall_max_y", max_y)
	add_child(leech)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.01, 0.02, 0.78)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(720, 67)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "CANYONS • SIDE-SCROLLER ROOM"
	title.position = Vector2(34, 25)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#ffd0a0"))
	layer.add_child(title)
	seed_label = Label.new()
	seed_label.text = "A/D or arrows: run   Space/W: jump   wheel: zoom close/far   R: restart   Esc: tests"
	seed_label.position = Vector2(35, 54)
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color("#bfeaff"))
	layer.add_child(seed_label)
