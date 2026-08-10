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
var mouth := Vector3.ZERO
var active := false
var travel_axis := Vector3.LEFT

func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "TacticalSuitTarget"
	player.scale = Vector3.ONE * 1.25
	add_child(player)
	_find_skeleton(player)
	if skeleton:
		for i in skeleton.get_bone_count():
			rest_rotations[i] = skeleton.get_bone_pose_rotation(i)
	visible = false

func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D and not skeleton:
		skeleton = node as Skeleton3D
	for child in node.get_children():
		_find_skeleton(child)

func begin(start: Vector3, target: Vector3, axis := Vector3.LEFT) -> void:
	origin = start
	mouth = target
	travel_axis = axis.normalized()
	active = true
	elapsed = 0.0
	visible = true

func stop() -> void:
	active = false
	visible = false

func tick(delta: float) -> void:
	if not active or not player:
		return
	elapsed += delta
	var phase := fposmod(elapsed / 5.2, 1.0)
	var p := origin
	if phase < 0.25:
		p = origin.lerp(origin + travel_axis * 0.65, smoothstep(0.0, 0.25, phase))
		player.rotation = Vector3(0, 0, sin(elapsed * 2.0) * 0.03)
	elif phase < 0.56:
		var grab := smoothstep(0.25, 0.56, phase)
		p = origin.lerp(mouth + travel_axis * 0.42, grab)
		player.rotation = Vector3(sin(elapsed * 7.0) * 0.22, sin(elapsed * 5.0) * 0.35, cos(elapsed * 6.0) * 0.28)
		_ragdoll(0.8)
	else:
		var swallow := smoothstep(0.56, 0.92, phase)
		p = (mouth + travel_axis * 0.42).lerp(mouth, swallow)
		player.rotation = Vector3(0.2 + sin(elapsed * 3.0) * 0.05, 0.4, 0.18)
		player.scale = Vector3.ONE * lerpf(1.25, 0.72, swallow)
	player.position = p
	if phase < 0.56:
		player.scale = Vector3.ONE * 1.25

func _ragdoll(amount: float) -> void:
	if not skeleton:
		return
	for i in skeleton.get_bone_count():
		var rest: Quaternion = rest_rotations[i]
		var n := float(i)
		skeleton.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, sin(elapsed * 8.0 + n) * 0.18 * amount) * Quaternion(Vector3.FORWARD, cos(elapsed * 6.0 + n * 0.7) * 0.16 * amount))
