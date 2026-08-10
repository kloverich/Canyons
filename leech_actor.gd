extends CharacterBody3D

## Reusable surface-crawling leech. It begins in a long, straight pose, then
## runs an accordion-like extension/contraction over its deform chain.
const LEECH_SKIN := preload("res://assets/leech_alien+worm+3d+model_basecolor.jpg")
const CONTACT_DISTANCE := 0.24
@export var crawl_speed := 0.72
@export var display_scale := 0.48
@export var initial_surface_normal := Vector3.UP
@export var initial_travel_direction := Vector3.FORWARD
@export var wall_patrol := false
@export var wall_min_y := -1000000.0
@export var wall_max_y := 1000000.0
var deform_bones: Array[Dictionary] = []
var elapsed := 0.0
var surface_normal := Vector3.UP
var travel_direction := Vector3.FORWARD
var ground_probe: RayCast3D
var wall_probe: RayCast3D
var visual_root: Node3D
var lost_surface := false

func _ready() -> void:
	surface_normal = initial_surface_normal.normalized()
	travel_direction = initial_travel_direction.normalized()
	visual_root = _build_straight_visual()
	_add_surface_probes()
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 1.25
	collision.shape = shape
	collision.position = Vector3.ZERO
	collision.rotation.x = PI * 0.5
	add_child(collision)
	_align_to_surface(surface_normal)

func _build_straight_visual() -> Node3D:
	var visual := Node3D.new()
	visual.name = "StraightLeechVisual"
	add_child(visual)
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = LEECH_SKIN
	skin.albedo_color = Color("#9c7450")
	skin.roughness = 0.52
	skin.uv1_triplanar = true
	skin.uv1_scale = Vector3(2.2, 2.2, 2.2)
	var body := MeshInstance3D.new()
	body.mesh = _create_tapered_body_mesh()
	body.material_override = skin
	visual.add_child(body)
	# The mouth is physically placed at local -Z. Godot's look_at uses -Z as
	# forward, so reversing travel at a wall top also reverses the actual face.
	var mouth_material := StandardMaterial3D.new()
	mouth_material.albedo_color = Color("#19070a")
	mouth_material.roughness = 0.62
	var mouth := MeshInstance3D.new()
	var mouth_mesh := CylinderMesh.new()
	mouth_mesh.height = 0.025
	mouth_mesh.top_radius = 0.125
	mouth_mesh.bottom_radius = 0.125
	mouth_mesh.radial_segments = 24
	mouth.mesh = mouth_mesh
	mouth.rotation.x = PI * 0.5
	mouth.position.z = -0.618
	mouth.material_override = mouth_material
	visual.add_child(mouth)
	var lip := MeshInstance3D.new()
	var lip_mesh := TorusMesh.new()
	lip_mesh.inner_radius = 0.112
	lip_mesh.outer_radius = 0.168
	lip_mesh.rings = 24
	lip_mesh.ring_segments = 8
	lip.mesh = lip_mesh
	lip.rotation.x = PI * 0.5
	lip.position.z = -0.632
	lip.material_override = skin
	visual.add_child(lip)
	var tooth_material := StandardMaterial3D.new()
	tooth_material.albedo_color = Color("#e7d5b4")
	tooth_material.roughness = 0.38
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var tooth := MeshInstance3D.new()
		var tooth_mesh := CylinderMesh.new()
		tooth_mesh.height = 0.105
		tooth_mesh.top_radius = 0.006
		tooth_mesh.bottom_radius = 0.026
		tooth_mesh.radial_segments = 8
		tooth.mesh = tooth_mesh
		# Cylinder +Y is rotated toward -Z, making the narrow end point out
		# from the mouth while preserving the leech's forward orientation.
		tooth.rotation.x = -PI * 0.5
		tooth.position = Vector3(cos(angle) * 0.105, sin(angle) * 0.105, -0.675)
		tooth.material_override = tooth_material
		visual.add_child(tooth)
	return visual

func _create_tapered_body_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length_segments := 16
	var radial_segments := 24
	for i in length_segments:
		var t0 := float(i) / float(length_segments)
		var t1 := float(i + 1) / float(length_segments)
		var z0 := lerpf(-0.61, 0.61, t0)
		var z1 := lerpf(-0.61, 0.61, t1)
		var r0 := _body_radius(t0)
		var r1 := _body_radius(t1)
		for j in radial_segments:
			var u0 := float(j) / float(radial_segments)
			var u1 := float(j + 1) / float(radial_segments)
			var a0 := TAU * u0
			var a1 := TAU * u1
			var p00 := Vector3(cos(a0) * r0, sin(a0) * r0, z0)
			var p01 := Vector3(cos(a1) * r0, sin(a1) * r0, z0)
			var p10 := Vector3(cos(a0) * r1, sin(a0) * r1, z1)
			var p11 := Vector3(cos(a1) * r1, sin(a1) * r1, z1)
			_add_body_triangle(surface, p00, Vector2(u0, t0), p10, Vector2(u0, t1), p11, Vector2(u1, t1))
			_add_body_triangle(surface, p00, Vector2(u0, t0), p11, Vector2(u1, t1), p01, Vector2(u1, t0))
	# Close the narrow tail; the mouth disk closes the broad front end.
	var tail_radius := _body_radius(1.0)
	for j in radial_segments:
		var a0 := TAU * float(j) / float(radial_segments)
		var a1 := TAU * float(j + 1) / float(radial_segments)
		_add_body_triangle(surface, Vector3(0, 0, 0.61), Vector2(0.5, 1.0), Vector3(cos(a1) * tail_radius, sin(a1) * tail_radius, 0.61), Vector2(0, 1), Vector3(cos(a0) * tail_radius, sin(a0) * tail_radius, 0.61), Vector2(1, 1))
	surface.generate_normals()
	return surface.commit()

func _body_radius(t: float) -> float:
	# Broad muscular head, a subtle mid-body swell, then a decisive taper to
	# roughly one quarter of the head radius at the tail.
	var taper := smoothstep(0.18, 1.0, t)
	return lerpf(0.175, 0.043, taper) + sin(PI * t) * 0.028

func _add_body_triangle(surface: SurfaceTool, a: Vector3, uv_a: Vector2, b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)

func _collect_deform_bones(node: Node) -> void:
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		for bone_index in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone_index)
			if bone_name.begins_with("DEF-"):
				deform_bones.append({"skeleton": skeleton, "index": bone_index, "name": bone_name, "rest": skeleton.get_bone_pose_rotation(bone_index), "scale": skeleton.get_bone_pose_scale(bone_index)})
	for child in node.get_children():
		_collect_deform_bones(child)
	deform_bones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _bone_order(String(a["name"])) < _bone_order(String(b["name"])))

func _physics_process(delta: float) -> void:
	elapsed += delta
	_update_surface_motion(delta)
	# Hold a deliberately stretched, neutral pose before the crawl starts. This
	# makes the beginning legible and avoids inheriting the source rig's bent
	# presentation pose.
	var startup := smoothstep(0.0, 0.85, elapsed)
	var cycle := fmod(maxf(elapsed - 0.85, 0.0) / 3.35, 1.0)
	var stretch := lerpf(1.32, _crawl_stretch(cycle), startup)
	# Slightly stronger than strict volume preservation so the accordion change
	# remains readable at gameplay-camera distances.
	var girth := pow(1.0 / maxf(stretch, 0.54), 0.72)
	# The exported bone scales are not propagated consistently by the imported
	# Rigify hierarchy. Scale the actual skinned scene along its known long (Z)
	# axis so the accordion action is unambiguous on every renderer.
	var base_scale := 2.55 * display_scale
	visual_root.scale = Vector3(base_scale * girth, base_scale * girth, base_scale * stretch)
	# Do not rotate any deform bone. The corrected asset has a straight bind
	# chain, and leaving every pose at reset guarantees that the tail can never
	# curl. All locomotion deformation is longitudinal scaling only.

func _add_surface_probes() -> void:
	ground_probe = RayCast3D.new()
	ground_probe.name = "SurfaceProbe"
	ground_probe.target_position = Vector3(0, -2.4, 0)
	ground_probe.collision_mask = 1
	add_child(ground_probe)
	wall_probe = RayCast3D.new()
	wall_probe.name = "ForwardSurfaceProbe"
	wall_probe.position = Vector3(0, 0.12, -0.26)
	wall_probe.target_position = Vector3(0, -0.45, -1.25)
	wall_probe.collision_mask = 1
	add_child(wall_probe)

func _update_surface_motion(delta: float) -> void:
	ground_probe.force_raycast_update()
	wall_probe.force_raycast_update()
	var desired_normal := surface_normal
	if ground_probe.is_colliding():
		desired_normal = ground_probe.get_collision_normal()
		var contact_point := ground_probe.get_collision_point()
		var adhered_position := contact_point + desired_normal * CONTACT_DISTANCE
		global_position = adhered_position
		lost_surface = false
	else:
		# Never allow a crawler to continue into empty space. Turn it back once
		# and wait for its contact probe to reacquire the platform.
		if not lost_surface:
			travel_direction = -travel_direction
			lost_surface = true
		_align_to_surface(surface_normal)
		global_position += travel_direction * crawl_speed * delta
		return
	if wall_patrol:
		if global_position.y >= wall_max_y and travel_direction.y > 0.0:
			travel_direction = Vector3.DOWN.slide(surface_normal).normalized()
		elif global_position.y <= wall_min_y and travel_direction.y < 0.0:
			travel_direction = Vector3.UP.slide(surface_normal).normalized()
	if wall_probe.is_colliding():
		var wall_normal := wall_probe.get_collision_normal()
		var forward := -global_transform.basis.z
		if forward.dot(wall_normal) < -0.28:
			# On a wall hit, turn the former surface-up direction into the new
			# travel direction so the leech climbs instead of sliding sideways.
			travel_direction = surface_normal
			desired_normal = wall_normal
	_align_to_surface(desired_normal)
	var tangent := travel_direction.slide(surface_normal)
	if tangent.length_squared() < 0.001:
		tangent = (-global_transform.basis.z).slide(surface_normal)
	tangent = tangent.normalized()
	var hit := move_and_collide(tangent * crawl_speed * delta)
	if hit:
		if wall_patrol:
			travel_direction = -travel_direction
		else:
			travel_direction = surface_normal
			_align_to_surface(hit.get_normal())

func _align_to_surface(new_normal: Vector3) -> void:
	surface_normal = new_normal.normalized()
	var tangent := travel_direction.slide(surface_normal)
	if tangent.length_squared() < 0.001:
		tangent = (-global_transform.basis.z).slide(surface_normal)
	if tangent.length_squared() < 0.001:
		tangent = surface_normal.cross(Vector3.RIGHT)
	travel_direction = tangent.normalized()
	look_at(global_position + travel_direction, surface_normal)

func _crawl_stretch(phase: float) -> float:
	if phase < 0.20: return 1.32
	if phase < 0.55: return lerpf(1.32, 0.58, smoothstep(0.20, 0.55, phase))
	if phase < 0.70: return 0.58
	return lerpf(0.58, 1.32, smoothstep(0.70, 1.0, phase))

func _window(phase: float, start: float, finish: float) -> float:
	return clampf((phase - start) / (finish - start), 0.0, 1.0)

func _bone_order(bone_name: String) -> int:
	return 0 if bone_name == "DEF-Bone" else bone_name.get_slice(".", 1).to_int() + 1
