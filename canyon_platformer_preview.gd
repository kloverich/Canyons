extends Node3D

## One-screen 2.5D platforming room with a deterministic procedural canyon.
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
const CLIMB_SPEED := 3.25
const BLOCK_WIDTH := 1.0
const BLOCK_HEIGHT := 1.0
const CANYON_FLOOR := -8.8

# The imported GLB names its NLA strips numerically.  Keep the gameplay names
# here so state code cannot accidentally assign a clip to the wrong action.
const ANIM_WALK := &"NlaTrack_001"
const ANIM_RUN := &"NlaTrack_002"
const ANIM_JUMP := &"NlaTrack_003"
const ANIM_CLIMB := &"gameplay/climb"

@export var landscape_seed := 481516
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var player: CharacterBody3D
var player_model: Node3D
var player_animator: AnimationPlayer
var player_skeleton: Skeleton3D
var player_rest_rotations: Dictionary = {}
var player_bones: Dictionary = {}
var current_player_animation := ""
var facing_direction := 1.0
var is_climbing := false
var active_climb_wall: Dictionary = {}
var creatures: Array[Dictionary] = []
var elapsed := 0.0
var seed_label: Label
var terrain_columns: Array[Dictionary] = []
var camera_focus := Vector3.ZERO
var camera_look_ahead := 0.0
var camera_focus_initialized := false

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
	var climb_up := Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
	var detected_wall := _climb_wall_at_player(direction)
	if not is_climbing and not detected_wall.is_empty() and (climb_up or absf(direction) > 0.05):
		is_climbing = true
		active_climb_wall = detected_wall
	if is_climbing:
		var wall := active_climb_wall
		# Hold the player against the rock and advance vertically.  This avoids
		# the old ledge-pull motion and makes Up a continuous rock-climb input.
		player.velocity = Vector3.ZERO
		player.position.x = float(wall["x"])
		# Tall cube faces are climbed continuously once the player reaches them.
		player.position.y += CLIMB_SPEED * delta
		if player.position.y >= float(wall["top"]):
			player.position = wall["mount"]
			player.velocity = Vector3.ZERO
			is_climbing = false
			active_climb_wall = {}
	else:
		player.velocity.x = move_toward(player.velocity.x, direction * RUN_SPEED, 28.0 * delta)
		player.velocity.z = 0.0
		if not player.is_on_floor():
			player.velocity.y -= GRAVITY * delta
		if Input.is_action_just_pressed("ui_accept") and player.is_on_floor():
			player.velocity.y = JUMP_SPEED
		player.move_and_slide()
	player.position.z = 1.1
	player.position.x = clampf(player.position.x, -23.2, 23.2)
	if player.position.y < -12.0:
		player.position = Vector3(-21.0, _surface_y_at(-21.0) + 0.9, 1.1)
		player.velocity = Vector3.ZERO
	if player_model and absf(direction) > 0.01:
		facing_direction = direction
		# The tactical-suit source mesh faces the opposite local direction from
		# the level coordinate system, so its visual turn must be inverted.
		var facing_angle := PI * 0.5 if direction > 0.0 else -PI * 0.5
		player_model.rotation.y = lerp_angle(player_model.rotation.y, facing_angle, 1.0 - exp(-delta * 18.0))
	_update_player_animation(direction)

func _climb_wall_at_player(input_direction: float) -> Dictionary:
	if terrain_columns.size() < 2 or absf(input_direction) < 0.05:
		return {}
	var direction := 1 if input_direction > 0.0 else -1
	var current_index := _terrain_column_index_at(player.position.x)
	var next_index := current_index + direction
	if next_index < 0 or next_index >= terrain_columns.size():
		return {}
	var current_surface := float(terrain_columns[current_index]["surface"])
	var next_surface := float(terrain_columns[next_index]["surface"])
	# Every one-block-or-higher face is climbable; short steps should not force
	# the player into a jump while taller canyon faces use the same traversal.
	if next_surface - current_surface < BLOCK_HEIGHT:
		return {}
	var boundary_x := -24.0 + (maxi(current_index, next_index)) * BLOCK_WIDTH
	if absf(player.position.x - boundary_x) > 0.62:
		return {}
	return {
		"x": boundary_x - direction * 0.38,
		"direction": direction,
		"bottom": current_surface,
		# The actor's center must climb to the same standing height as the mount,
		# otherwise a one-block face appears as a teleport for the final 0.9m.
		"top": next_surface + 0.9,
		"mount": Vector3(-23.5 + next_index * BLOCK_WIDTH, next_surface + 0.9, 1.1),
	}
	return {}

func _process(delta: float) -> void:
	elapsed += delta
	_update_procedural_climb_pose(delta)
	_animate_creatures(delta)
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
	camera.position = Vector3(0.0, LEVEL_CENTER_Y + 3.4, 30.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.look_at(Vector3(0.0, LEVEL_CENTER_Y, 0.0))

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
	# A low-frequency random walk produces a readable Mario-like histogram:
	# solid block columns, stepped slopes, and deep canyon bowls.
	var terrain_root := Node3D.new()
	terrain_root.name = "RandomBlockCanyon"
	add_child(terrain_root)
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = landscape_seed * 13 + 91
	var surface := -2.8
	for column in range(48):
		if column > 0:
			surface += terrain_rng.randf_range(-2.15, 2.15)
			if column % 7 == 0:
				surface -= terrain_rng.randf_range(2.8, 4.8)
			# Align every surface to a whole cube, including the collision top.
			surface = CANYON_FLOOR + snappedf(clampf(surface, -7.8, 10.2) - CANYON_FLOOR, BLOCK_HEIGHT)
		var x := -23.5 + column * BLOCK_WIDTH
		terrain_columns.append({"x": x, "surface": surface})
		_add_canyon_column(terrain_root, column, x, surface, terrain_rng)

func _add_canyon_column(parent: Node3D, column: int, x: float, surface: float, terrain_rng: RandomNumberGenerator) -> void:
	var collision_body := StaticBody3D.new()
	collision_body.name = "CanyonColumn_%d" % column
	collision_body.position = Vector3(x, (CANYON_FLOOR + surface) * 0.5, 1.0)
	var collision := CollisionShape3D.new()
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(BLOCK_WIDTH, surface - CANYON_FLOOR, 4.0)
	collision.shape = collision_shape
	collision_body.add_child(collision)
	parent.add_child(collision_body)
	var rows := int(ceil((surface - CANYON_FLOOR) / BLOCK_HEIGHT))
	for row in rows:
		# Three cube layers give each column actual depth, not a thin front wall.
		for depth_layer in range(3):
			var block := MeshInstance3D.new()
			block.name = "CanyonBlock_%d_%d_%d" % [column, row, depth_layer]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(BLOCK_WIDTH - 0.07, BLOCK_HEIGHT - 0.07, BLOCK_WIDTH - 0.07)
			block.mesh = mesh
			block.position = Vector3(x, CANYON_FLOOR + BLOCK_HEIGHT * (row + 0.5), -0.55 - depth_layer * BLOCK_WIDTH)
			var material := StandardMaterial3D.new()
			var shade := terrain_rng.randf_range(-0.055, 0.055)
			material.albedo_color = Color("#593b31").lightened(maxf(0.0, shade)).darkened(maxf(0.0, -shade))
			material.roughness = 0.92
			block.material_override = material
			parent.add_child(block)

func _surface_y_at(x: float) -> float:
	if terrain_columns.is_empty():
		return CANYON_FLOOR
	var index := _terrain_column_index_at(x)
	return float(terrain_columns[index]["surface"])

func _terrain_column_index_at(x: float) -> int:
	return clampi(roundi((x + 23.5) / BLOCK_WIDTH), 0, terrain_columns.size() - 1)

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
	player.position = Vector3(-21.0, _surface_y_at(-21.0) + 0.9, 1.1)
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
	camera_focus = player.position + Vector3(0.0, 0.8, 0.0)
	camera_focus_initialized = true
	player_animator = _find_animation_player(player_model)
	player_skeleton = _find_skeleton(player_model)
	if player_skeleton:
		for bone_index in player_skeleton.get_bone_count():
			player_rest_rotations[bone_index] = player_skeleton.get_bone_pose_rotation(bone_index)
			player_bones[player_skeleton.get_bone_name(bone_index)] = bone_index
	if player_animator:
		_set_animation_loop(ANIM_WALK, true)
		_set_animation_loop(ANIM_RUN, true)
		_remove_animation_root_motion(ANIM_WALK)
		_remove_animation_root_motion(ANIM_RUN)
		_remove_animation_root_motion(ANIM_JUMP)
		_build_climb_animation()

func _build_climb_animation() -> void:
	if not player_animator or not player_skeleton:
		return
	var animation_root := player_animator.get_node(player_animator.root_node)
	var skeleton_path := animation_root.get_path_to(player_skeleton)
	var climb := Animation.new()
	climb.resource_name = "ProceduralRockClimb"
	climb.length = 0.90
	climb.loop_mode = Animation.LOOP_LINEAR
	# One side reaches while the opposite knee rises; the second half swaps the
	# planted hand and foot. These are authored runtime tracks, not an imported
	# pull-up clip or frame-dependent manual skeleton overrides.
	_add_climb_rotation_track(climb, skeleton_path, "L_Upperarm", Vector3.FORWARD, -1.57, -0.42)
	_add_climb_rotation_track(climb, skeleton_path, "R_Upperarm", Vector3.FORWARD, 0.42, 1.57)
	_add_climb_rotation_track(climb, skeleton_path, "L_Forearm", Vector3.RIGHT, -0.82, -0.24)
	_add_climb_rotation_track(climb, skeleton_path, "R_Forearm", Vector3.RIGHT, 0.24, 0.82)
	_add_climb_rotation_track(climb, skeleton_path, "L_Thigh", Vector3.UP, 0.58, -0.08)
	_add_climb_rotation_track(climb, skeleton_path, "R_Thigh", Vector3.UP, 0.08, -0.58)
	_add_climb_rotation_track(climb, skeleton_path, "L_Calf", Vector3.RIGHT, -1.18, -0.22)
	_add_climb_rotation_track(climb, skeleton_path, "R_Calf", Vector3.RIGHT, -0.22, -1.18)
	_add_climb_rotation_track(climb, skeleton_path, "Spine01", Vector3.RIGHT, -0.11, 0.11)
	var library := AnimationLibrary.new()
	library.add_animation("climb", climb)
	if player_animator.has_animation_library("gameplay"):
		player_animator.remove_animation_library("gameplay")
	player_animator.add_animation_library("gameplay", library)

func _add_climb_rotation_track(animation: Animation, skeleton_path: NodePath, bone_name: String, axis: Vector3, first_angle: float, second_angle: float) -> void:
	if not player_bones.has(bone_name):
		return
	var bone_index: int = player_bones[bone_name]
	var rest: Quaternion = player_rest_rotations[bone_index]
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone_name]))
	animation.rotation_track_insert_key(track, 0.0, rest * Quaternion(axis, first_angle))
	animation.rotation_track_insert_key(track, 0.45, rest * Quaternion(axis, second_angle))
	animation.rotation_track_insert_key(track, 0.90, rest * Quaternion(axis, first_angle))

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

func _remove_animation_root_motion(animation_name: StringName) -> void:
	if not player_animator or not player_animator.has_animation(animation_name):
		return
	var animation := player_animator.get_animation(animation_name)
	# Hip is the skeleton root in this GLB. Its imported translation makes the
	# mesh lunge sideways and snap back at the clip boundary; CharacterBody3D
	# already supplies the real movement, so that track must not be played.
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if String(animation.track_get_path(track_index)).ends_with(":Hip"):
			animation.remove_track(track_index)

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
	if is_climbing:
		_play_player_animation(ANIM_CLIMB, 0.08, 1.0)
	elif not player.is_on_floor():
		if player.velocity.y > 0.15:
			_play_player_animation(ANIM_JUMP, 0.10, 1.15)
		else:
			_play_player_animation(ANIM_JUMP, 0.14, 0.35)
	elif absf(direction) > 0.05 or absf(player.velocity.x) > 0.5:
		var speed_ratio := absf(player.velocity.x) / RUN_SPEED
		if speed_ratio < 0.62:
			_play_player_animation(ANIM_WALK, 0.12, clampf(speed_ratio * 1.45, 0.65, 1.0))
		else:
			_play_player_animation(ANIM_RUN, 0.12, clampf(speed_ratio, 0.85, 1.25))
	else:
		# This model has no idle strip.  Leave it in its neutral rest pose rather
		# than playing NlaTrack, which is its imported climbing/pull-up motion.
		if current_player_animation != "rest":
			player_animator.stop()
			if player_skeleton:
				player_skeleton.reset_bone_poses()
			current_player_animation = "rest"

func _update_procedural_climb_pose(delta: float) -> void:
	if not player_skeleton or not player_model:
		return
	if not is_climbing:
		player_model.position.y = lerpf(player_model.position.y, -0.88, 1.0 - exp(-delta * 14.0))
		player_model.rotation.z = lerp_angle(player_model.rotation.z, 0.0, 1.0 - exp(-delta * 14.0))
		return
	# The AnimationPlayer owns the limb tracks; this adds only a small whole-body
	# weight transfer so each planted-hand step visibly lifts the climber.
	var phase := elapsed * 6.2
	var planted_bob := absf(sin(phase))
	player_model.position.y = -0.88 + planted_bob * 0.08

func _update_follow_camera(delta: float) -> void:
	if not camera or not player:
		return
	if not camera_focus_initialized:
		camera_focus = player.position + Vector3(0.0, 0.8, 0.0)
		camera_focus_initialized = true
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_width := camera.size * aspect * 0.5
	var half_height := camera.size * 0.5
	var desired_look_ahead := player.velocity.x / RUN_SPEED * minf(2.1, camera.size * 0.15)
	camera_look_ahead = lerpf(camera_look_ahead, desired_look_ahead, 1.0 - exp(-delta * 3.0))
	var min_x := -LEVEL_WIDTH * 0.5 + half_width
	var max_x := LEVEL_WIDTH * 0.5 - half_width
	var min_y := LEVEL_CENTER_Y - LEVEL_HEIGHT * 0.5 + half_height
	var max_y := LEVEL_CENTER_Y + LEVEL_HEIGHT * 0.5 - half_height
	var desired_x := clampf(player.position.x + camera_look_ahead, min_x, max_x) if min_x <= max_x else 0.0
	var desired_y := clampf(player.position.y + 0.8, min_y, max_y) if min_y <= max_y else LEVEL_CENTER_Y
	camera_focus.x = lerpf(camera_focus.x, desired_x, 1.0 - exp(-delta * 4.0))
	# A vertical dead zone prevents every stair-step and animation bob from
	# nudging the camera, while sustained jumps/climbs still track smoothly.
	var vertical_error := desired_y - camera_focus.y
	if absf(vertical_error) > 0.65:
		var vertical_target := desired_y - signf(vertical_error) * 0.65
		camera_focus.y = lerpf(camera_focus.y, vertical_target, 1.0 - exp(-delta * 3.2))
	var desired_camera_position := Vector3(camera_focus.x, camera_focus.y + 3.4, camera.position.z)
	camera.position = camera.position.lerp(desired_camera_position, 1.0 - exp(-delta * 4.0))
	camera.look_at(Vector3(camera_focus.x, camera_focus.y, 0.0), Vector3.UP)

func _place_creatures() -> void:
	_add_rigged_creature("CRAB", CRAB_SCENE, Vector3(-8.0, _surface_y_at(-8.0) + 0.08, 0.7), Vector3.ONE * 2.25)
	_add_rigged_creature("CRAB", CRAB_SCENE, Vector3(16.0, _surface_y_at(16.0) + 0.08, 0.7), Vector3.ONE * 1.85)
	_add_rigged_creature("ANEMONE", ANEMONE_SCENE, Vector3(-1.0, _surface_y_at(-1.0) + 0.03, 0.65), Vector3.ONE * 2.25)
	_add_rigged_creature("ANEMONE", ANEMONE_SCENE, Vector3(19.0, _surface_y_at(19.0) + 0.03, 0.65), Vector3.ONE * 1.9)
	_add_rigged_creature("JELLY", JELLY_SCENE, Vector3(4.0, _surface_y_at(4.0) + 3.1, 0.45), Vector3.ONE * 2.0)
	_add_rigged_creature("JELLY", JELLY_SCENE, Vector3(11.0, _surface_y_at(11.0) + 2.7, 0.45), Vector3.ONE * 1.7)
	_add_leech(Vector3(-13.0, _surface_y_at(-13.0) + 0.08, 0.75), Vector3.UP, Vector3.RIGHT)
	_add_leech(Vector3(22.0, _surface_y_at(22.0) + 0.08, 0.75), Vector3.UP, Vector3.LEFT)

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
	var entry: Dictionary = {"kind": kind, "root": creature, "base": position, "base_scale": scale_value, "skeleton": skeleton, "rotations": rotations, "scales": scales, "phase": rng.randf_range(0.0, TAU)}
	if kind == "CRAB":
		var home_column := _terrain_column_index_at(position.x)
		var initial_direction := 1 if rng.randf() > 0.5 else -1
		entry["crab_column"] = home_column
		entry["crab_direction"] = initial_direction
		entry["crab_state"] = "ground"
		entry["crab_min_column"] = maxi(0, home_column - 3)
		entry["crab_max_column"] = mini(terrain_columns.size() - 1, home_column + 3)
		creature.position.x = _column_center_x(home_column)
		creature.rotation.y = PI * 0.5 if initial_direction > 0 else -PI * 0.5
	creatures.append(entry)
	return creature

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _animate_creatures(delta: float) -> void:
	for entry in creatures:
		var root: Node3D = entry["root"]
		var kind: String = entry["kind"]
		var phase: float = entry["phase"]
		var skeleton: Skeleton3D = entry["skeleton"]
		var base: Vector3 = entry["base"]
		if kind == "CRAB":
			_animate_crab_patrol(entry, root, base, delta)
		if kind == "JELLY":
			var base_scale: Vector3 = entry["base_scale"]
			# Broad drifting, vertical pulsing, and a slow turn make these read as
			# swimming creatures rather than stationary decorations.
			var swim_time := elapsed + phase
			root.position = base + Vector3(
				sin(swim_time * 0.48) * 1.25,
				sin(swim_time * 1.18) * 0.65 + sin(swim_time * 0.37) * 0.28,
				cos(swim_time * 0.61) * 0.42
			)
			root.rotation.y = sin(swim_time * 0.46) * 0.42
			root.rotation.z = sin(swim_time * 1.18) * 0.12
			var bell_pulse := 1.0 + sin(swim_time * 3.4) * 0.14
			root.scale = Vector3(base_scale.x / sqrt(bell_pulse), base_scale.y * bell_pulse, base_scale.z / sqrt(bell_pulse))
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

func _animate_crab_patrol(entry: Dictionary, crab: Node3D, base: Vector3, delta: float) -> void:
	var column: int = entry["crab_column"]
	var direction: int = entry["crab_direction"]
	var state: String = entry["crab_state"]
	var min_column: int = entry["crab_min_column"]
	var max_column: int = entry["crab_max_column"]
	var next_column := column + direction
	if state == "ground" and (next_column < min_column or next_column > max_column):
		direction *= -1
		next_column = column + direction
		entry["crab_direction"] = direction
	var current_surface := float(terrain_columns[column]["surface"])
	var target_yaw := PI * 0.5 if direction > 0 else -PI * 0.5
	var target_roll := 0.0
	if state == "ground":
		var next_surface := float(terrain_columns[next_column]["surface"])
		var height_change := next_surface - current_surface
		# Walk to the shared edge first. A height change becomes a vertical wall
		# traversal instead of teleporting between the two block tops.
		var horizontal_target := _column_boundary_x(column, next_column) if absf(height_change) > 0.01 else _column_center_x(next_column)
		crab.position.x = move_toward(crab.position.x, horizontal_target, 1.35 * delta)
		crab.position.y = current_surface + 0.08
		if absf(crab.position.x - horizontal_target) < 0.025:
			if absf(height_change) > 0.01:
				state = "wall"
				entry["crab_state"] = state
			else:
				column = next_column
				entry["crab_column"] = column
	else:
		var next_surface := float(terrain_columns[next_column]["surface"])
		var moving_up := next_surface > current_surface
		var vertical_target := next_surface + 0.08
		crab.position.x = _column_boundary_x(column, next_column)
		crab.position.y = move_toward(crab.position.y, vertical_target, 1.35 * delta)
		# Lean all the way into the vertical route; signs distinguish an upward
		# crawl from a controlled descent on the other side of a block ledge.
		target_roll = -direction * PI * 0.5 if moving_up else direction * PI * 0.5
		if absf(crab.position.y - vertical_target) < 0.025:
			column = next_column
			entry["crab_column"] = column
			entry["crab_state"] = "ground"
			crab.position.x += direction * 0.04
	var turn_weight := 1.0 - exp(-delta * 5.0)
	# Compose a profile yaw with a world-space 90-degree turn in the screen
	# plane. Quaternion interpolation preserves that side-on profile while it
	# rotates onto (and back off) the vertical wall.
	var profile_rotation := Quaternion(Vector3.UP, target_yaw)
	var wall_rotation := Quaternion(Vector3.FORWARD, target_roll)
	var target_orientation := wall_rotation * profile_rotation
	crab.quaternion = crab.quaternion.slerp(target_orientation, turn_weight)

func _column_center_x(column: int) -> float:
	return -23.5 + column * BLOCK_WIDTH

func _column_boundary_x(first_column: int, second_column: int) -> float:
	return (_column_center_x(first_column) + _column_center_x(second_column)) * 0.5

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
	seed_label.text = "A/D or arrows: run   Space: jump   Up/W on a climb wall: climb   wheel: zoom   R: restart   Esc: tests"
	seed_label.position = Vector2(35, 54)
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color("#bfeaff"))
	layer.add_child(seed_label)
