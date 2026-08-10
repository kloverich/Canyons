extends Node3D

## Shared presentation target used by creature feeding tests.
## The imported suit is deliberately kept as a separate child so each test can
## place and animate the target without changing the creature's rig.
const PLAYER_SCENE := preload("res://assets/black+tactical+suit+3d+model.glb")

var player: Node3D
var skeleton: Skeleton3D
var rest_rotations: Dictionary = {}
var elapsed := 0.0
var origin := Vector3.ZERO
var capture_point := Vector3.ZERO
var mouth := Vector3.ZERO
var active := false
var travel_axis := Vector3.LEFT
var player_bones: Dictionary = {}
var feeding_style := "swallow"
var tear_fragments: Array[MeshInstance3D] = []

func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "TacticalSuitTarget"
	player.scale = Vector3.ONE * 1.25
	add_child(player)
	_find_skeleton(player)
	if skeleton:
		for i in skeleton.get_bone_count():
			rest_rotations[i] = skeleton.get_bone_pose_rotation(i)
			player_bones[skeleton.get_bone_name(i)] = i
	_build_tear_fragments()
	visible = false

func _build_tear_fragments() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#232936")
	material.metallic = 0.45
	material.roughness = 0.38
	for size in [Vector3(0.18, 0.48, 0.18), Vector3(0.18, 0.48, 0.18), Vector3(0.20, 0.54, 0.20), Vector3(0.20, 0.54, 0.20), Vector3(0.34, 0.42, 0.24)]:
		var piece := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = size.x
		mesh.height = size.y
		mesh.radial_segments = 10
		piece.mesh = mesh
		piece.material_override = material
		piece.visible = false
		add_child(piece)
		tear_fragments.append(piece)

func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D and not skeleton:
		skeleton = node as Skeleton3D
	for child in node.get_children():
		_find_skeleton(child)

func begin(start: Vector3, grab_point: Vector3, mouth_point: Vector3, axis := Vector3.LEFT, style := "swallow") -> void:
	origin = start
	capture_point = grab_point
	mouth = mouth_point
	travel_axis = axis.normalized()
	feeding_style = style
	active = true
	elapsed = 0.0
	visible = true

func stop() -> void:
	active = false
	visible = false
	if skeleton:
		skeleton.reset_bone_poses()

func tick(delta: float) -> void:
	if not active or not player:
		return
	elapsed += delta
	var time := fposmod(elapsed, 6.2)
	var flee_end := origin - travel_axis * 1.05
	var p := origin
	player.scale = Vector3.ONE * 1.25
	if skeleton:
		skeleton.reset_bone_poses()
	if time < 1.65:
		# The target runs away from the creature before its appendage reaches it.
		p = origin.lerp(flee_end, smoothstep(0.0, 1.65, time))
		player.rotation = Vector3(0.0, atan2(-travel_axis.x, -travel_axis.z), 0.0)
		_run_pose()
	elif time < 2.55:
		# The appendage catches the target at its actual pincer/tentacle point.
		p = flee_end.lerp(capture_point, smoothstep(1.65, 2.55, time))
		player.rotation = Vector3(sin(elapsed * 9.0) * 0.18, 0.3, cos(elapsed * 8.0) * 0.24)
		_ragdoll(0.7)
		_struggle_pose(0.85)
	elif time < 4.25:
		# Carry the captured target visibly from the appendage into the mouth.
		var destination := mouth if feeding_style != "crab" else mouth - travel_axis * 0.42
		p = capture_point.lerp(destination, smoothstep(2.55, 4.25, time))
		player.rotation = Vector3(sin(elapsed * 11.0) * 0.28, elapsed * 1.8, cos(elapsed * 9.0) * 0.24)
		_ragdoll(1.0)
		_struggle_pose(1.25)
	elif time < 4.8 and feeding_style == "crab":
		# The crab holds its catch directly in front of the mouth while the jaws
		# open. The crab test reads this phase to close the bite around it.
		p = mouth - travel_axis * 0.42
		player.rotation = Vector3(sin(elapsed * 12.0) * 0.20, 0.0, cos(elapsed * 10.0) * 0.18)
		_struggle_pose(1.15)
	elif time < 5.12 and feeding_style == "crab":
		p = (mouth - travel_axis * 0.42).lerp(mouth, smoothstep(4.8, 5.12, time))
		_ragdoll(0.55)
	elif time < 4.8:
		# Keep full size while crossing the mouth: it is eaten, not scaled away.
		p = mouth + travel_axis * smoothstep(4.25, 4.8, time) * 0.22
		player.rotation = Vector3(0.25, 0.4, 0.15)
		if feeding_style == "tear_apart":
			_tear_apart_pose()
		else:
			_ragdoll(0.35)
	else:
		visible = false
		return
	player.position = p
	if feeding_style != "tear_apart" or time < 4.25:
		player.visible = true
		_set_tear_fragments_visible(false)
	visible = true

func _run_pose() -> void:
	var stride := sin(elapsed * 10.0)
	_set_bone_rotation("L_Upperarm", Vector3.FORWARD, stride * 0.58)
	_set_bone_rotation("R_Upperarm", Vector3.FORWARD, -stride * 0.58)
	_set_bone_rotation("L_Thigh", Vector3.FORWARD, -stride * 0.72)
	_set_bone_rotation("R_Thigh", Vector3.FORWARD, stride * 0.72)
	_set_bone_rotation("L_Calf", Vector3.FORWARD, maxf(0.0, stride) * 0.48)
	_set_bone_rotation("R_Calf", Vector3.FORWARD, maxf(0.0, -stride) * 0.48)

func _set_bone_rotation(bone_name: String, axis: Vector3, angle: float) -> void:
	if not skeleton or not player_bones.has(bone_name):
		return
	var bone_index: int = player_bones[bone_name]
	var rest: Quaternion = rest_rotations[bone_index]
	skeleton.set_bone_pose_rotation(bone_index, rest * Quaternion(axis, angle))

func _struggle_pose(amount: float) -> void:
	# Deliberate large limb motions read as resistance much more clearly than
	# the general ragdoll noise alone: arms push outward and legs kick apart.
	var flail_a := sin(elapsed * 13.0) * amount
	var flail_b := sin(elapsed * 17.0 + 1.1) * amount
	_set_bone_rotation("L_Upperarm", Vector3.FORWARD, 1.05 + flail_a * 0.62)
	_set_bone_rotation("R_Upperarm", Vector3.FORWARD, -1.05 - flail_b * 0.62)
	_set_bone_rotation("L_Forearm", Vector3.RIGHT, -0.72 + flail_b * 0.48)
	_set_bone_rotation("R_Forearm", Vector3.RIGHT, 0.72 - flail_a * 0.48)
	_set_bone_rotation("L_Thigh", Vector3.FORWARD, -flail_b * 0.82)
	_set_bone_rotation("R_Thigh", Vector3.FORWARD, flail_a * 0.82)
	_set_bone_rotation("L_Calf", Vector3.FORWARD, 0.48 + maxf(0.0, flail_a) * 0.72)
	_set_bone_rotation("R_Calf", Vector3.FORWARD, -0.48 - maxf(0.0, flail_b) * 0.72)
	_set_bone_rotation("Spine01", Vector3.RIGHT, sin(elapsed * 10.0) * 0.20 * amount)

func _tear_apart_pose() -> void:
	# The tentacles pull in opposing directions at the mouth: limbs are driven
	# into a full spread before the target vanishes, without a shrink effect.
	var pull := smoothstep(4.25, 4.8, fposmod(elapsed, 6.2))
	_set_bone_rotation("L_Upperarm", Vector3.FORWARD, 1.65 + pull * 0.55)
	_set_bone_rotation("R_Upperarm", Vector3.FORWARD, -1.65 - pull * 0.55)
	_set_bone_rotation("L_Forearm", Vector3.RIGHT, -1.10)
	_set_bone_rotation("R_Forearm", Vector3.RIGHT, 1.10)
	_set_bone_rotation("L_Thigh", Vector3.FORWARD, -0.95 - pull * 0.45)
	_set_bone_rotation("R_Thigh", Vector3.FORWARD, 0.95 + pull * 0.45)
	_set_bone_rotation("L_Calf", Vector3.FORWARD, 0.85)
	_set_bone_rotation("R_Calf", Vector3.FORWARD, -0.85)
	_set_bone_rotation("Spine01", Vector3.RIGHT, sin(elapsed * 18.0) * 0.30)
	player.visible = false
	var directions := [Vector3(-1.0, 0.8, 0.2), Vector3(1.0, 0.65, -0.15), Vector3(-0.85, -0.8, -0.2), Vector3(0.9, -0.7, 0.15), Vector3(0.0, 0.25, 0.4)]
	for index in tear_fragments.size():
		var piece := tear_fragments[index]
		piece.visible = true
		piece.position = mouth + directions[index] * (0.10 + pull * 0.85)
		piece.rotation = Vector3(elapsed * (4.0 + index), elapsed * (3.0 + index * 0.4), elapsed * (5.0 - index * 0.2))

func _set_tear_fragments_visible(value: bool) -> void:
	for piece in tear_fragments:
		piece.visible = value

func get_feed_time() -> float:
	return fposmod(elapsed, 6.2)

func _ragdoll(amount: float) -> void:
	if not skeleton:
		return
	for i in skeleton.get_bone_count():
		var rest: Quaternion = rest_rotations[i]
		var n := float(i)
		skeleton.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, sin(elapsed * 8.0 + n) * 0.18 * amount) * Quaternion(Vector3.FORWARD, cos(elapsed * 6.0 + n * 0.7) * 0.16 * amount))
