extends Node3D

# Procedural 3D specimen gallery. Every animal is built from real meshes so the
# same creature roots can be moved, animated, or attached to gameplay scenes.
const SKIN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/skins/anemone.png"),
	preload("res://assets/skins/crab.png"),
	preload("res://assets/skins/squid.png"),
	preload("res://assets/skins/astronaut.png"),
	preload("res://assets/skins/leech.png"),
	preload("res://assets/skins/urchin.png"),
	preload("res://assets/skins/octopus.png"),
	preload("res://assets/skins/jellyfish.png"),
	preload("res://assets/skins/mantis_shrimp.png"),
	preload("res://assets/skins/nautilus.png"),
	preload("res://assets/skins/horseshoe_crab.png"),
	preload("res://assets/skins/cuttlefish.png"),
	preload("res://assets/skins/starfish.png"),
	preload("res://assets/skins/lobster.png"),
]

const SPECIMENS := [
	["GIANT SEA ANEMONE", "crown of grasping tendrils", Color("#be526e")],
	["GIANT CRAB", "armored shell, eight legs and claws", Color("#d56e35")],
	["GIANT SQUID", "long mantle and ten tentacles", Color("#8052ae")],
	["ASTRONAUT", "environmental suit explorer", Color("#dce9f0")],
	["GIANT LEECH", "segmented muscular crawler", Color("#5ba866")],
	["SEA URCHIN", "radial armored spine ball", Color("#9852bd")],
	["OCTOPUS", "bulbous head and eight arms", Color("#b94778")],
	["JELLYFISH", "floating bell and tendrils", Color("#4ea6bc")],
	["MANTIS SHRIMP", "stalk eyes and raptorial clubs", Color("#4bb795")],
	["NAUTILUS", "spiral shell and feelers", Color("#c18b42")],
	["HORSESHOE CRAB", "domed shield and sword tail", Color("#7182b2")],
	["CUTTLEFISH", "broad finned mantle", Color("#c39c85")],
	["STARFISH", "five tapered gripping arms", Color("#bd5944")],
	["LOBSTER", "segmented tail, claws and antennae", Color("#b74b45")],
]

var specimens: Array[Node3D] = []
var wiggle_parts: Array[Node3D] = []
var selected := 0
var elapsed := 0.0
var camera: Camera3D
var selection_ring: MeshInstance3D
var title_label: Label
var detail_label: Label

func _ready() -> void:
	build_world()
	build_gallery()
	build_interface()
	var initial_specimen := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--specimen="):
			initial_specimen = clampi(argument.trim_prefix("--specimen=").to_int(), 0, SPECIMENS.size() - 1)
	select_specimen(initial_specimen)

func _process(delta: float) -> void:
	elapsed += delta
	for i in specimens.size():
		var creature := specimens[i]
		creature.position.y = 0.72 + sin(elapsed * 1.25 + i * 0.7) * 0.07
		creature.rotation.y += delta * (0.22 if i == selected else 0.055)
	for part in wiggle_parts:
		var rest: Vector3 = part.get_meta("rest_rotation")
		var axis: Vector3 = part.get_meta("wiggle_axis")
		var phase: float = part.get_meta("wiggle_phase")
		part.rotation = rest + axis * sin(elapsed * 2.0 + phase) * 0.13
	var target := specimens[selected].global_position + Vector3(0, 0.55, 0)
	var desired := target + Vector3(0, 3.25, 6.7)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 3.0))
	camera.look_at(target, Vector3.UP)
	selection_ring.global_position = specimens[selected].global_position + Vector3(0, -0.57, 0)
	selection_ring.rotation.y = elapsed * 0.45

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT, KEY_D, KEY_SPACE]:
			select_specimen((selected + 1) % SPECIMENS.size())
		elif event.keycode in [KEY_LEFT, KEY_A]:
			select_specimen((selected - 1 + SPECIMENS.size()) % SPECIMENS.size())
		elif event.keycode in [KEY_DOWN, KEY_S]:
			select_specimen((selected + 5) % SPECIMENS.size())
		elif event.keycode in [KEY_UP, KEY_W]:
			select_specimen((selected - 5 + SPECIMENS.size()) % SPECIMENS.size())

func build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Spatial colors are linear; these values render as the near-black navy used
	# by the canyon concept rather than the brighter blue of the first draft.
	env.background_color = Color(0.002, 0.005, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7591a6")
	env.ambient_light_energy = 0.43
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -28, 0)
	key.light_color = Color("#ffd2a1")
	key.light_energy = 2.0
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 145, 15)
	rim.light_color = Color("#72cfff")
	rim.light_energy = 1.25
	add_child(rim)

	camera = Camera3D.new()
	camera.fov = 48.0
	camera.position = Vector3(0, 3.8, 7.0)
	add_child(camera)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.012, 0.016, 0.018)
	ground_material.roughness = 0.9
	ground_material.metallic = 0.1
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(24, 0.3, 15)
	ground.mesh = ground_mesh
	ground.material_override = ground_material
	ground.position = Vector3(0, -0.82, 1.5)
	add_child(ground)

	selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.03
	ring_mesh.outer_radius = 1.09
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	selection_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("#50dff5")
	ring_material.emission_enabled = true
	ring_material.emission = Color("#29a8d8")
	ring_material.emission_energy_multiplier = 3.0
	selection_ring.material_override = ring_material
	add_child(selection_ring)

func build_gallery() -> void:
	for i in SPECIMENS.size():
		var root := Node3D.new()
		root.name = String(SPECIMENS[i][0]).to_pascal_case()
		var col := i % 5
		var row := i / 5
		root.position = Vector3((col - 2) * 4.0, 0.72, row * 4.0)
		add_child(root)
		specimens.append(root)
		var material := creature_material(i)
		match i:
			0: build_anemone(root, material)
			1: build_crab(root, material)
			2: build_squid(root, material)
			3: build_astronaut(root, material)
			4: build_leech(root, material)
			5: build_urchin(root, material)
			6: build_octopus(root, material)
			7: build_jellyfish(root, material)
			8: build_mantis_shrimp(root, material)
			9: build_nautilus(root, material)
			10: build_horseshoe_crab(root, material)
			11: build_cuttlefish(root, material)
			12: build_starfish(root, material)
			13: build_lobster(root, material)
		add_pedestal(root, i)

func creature_material(index: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = SKIN_TEXTURES[index]
	material.albedo_color = SPECIMENS[index][2].lightened(0.27)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3(2.2, 2.2, 2.2)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.48
	material.metallic = 0.22
	return material

func accent_material(color: Color, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.3
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
	return material

func add_pedestal(root: Node3D, index: int) -> void:
	var pedestal := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.42
	mesh.bottom_radius = 1.55
	mesh.height = 0.24
	mesh.radial_segments = 24
	pedestal.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.018, 0.022, 0.026)
	mat.metallic = 0.65
	mat.roughness = 0.48
	pedestal.material_override = mat
	pedestal.position.y = -0.67
	root.add_child(pedestal)
	var marker := MeshInstance3D.new()
	var marker_mesh := TorusMesh.new()
	marker_mesh.inner_radius = 1.25
	marker_mesh.outer_radius = 1.31
	marker_mesh.rings = 24
	marker_mesh.ring_segments = 6
	marker.mesh = marker_mesh
	marker.material_override = accent_material(SPECIMENS[index][2].lightened(0.2), true)
	marker.position.y = -0.53
	root.add_child(marker)

func add_sphere(parent: Node3D, position: Vector3, size: Vector3, material: Material, segments := 16) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = maxi(6, segments / 2)
	node.mesh = mesh
	node.position = position
	node.scale = size
	node.material_override = material
	parent.add_child(node)
	return node

func add_cylinder(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, taper := 0.82) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * taper
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	node.mesh = mesh
	node.position = (a + b) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	node.material_override = material
	parent.add_child(node)
	return node

func add_cone(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	return add_cylinder(parent, a, b, radius, material, 0.04)

func add_chain(parent: Node3D, points: PackedVector3Array, radius: float, material: Material, phase := 0.0) -> Node3D:
	var chain_root := Node3D.new()
	parent.add_child(chain_root)
	for i in range(points.size() - 1):
		add_cylinder(chain_root, points[i], points[i + 1], radius * (1.0 - i * 0.12), material)
		add_sphere(chain_root, points[i], Vector3.ONE * radius * 1.9, material, 10)
	add_sphere(chain_root, points[-1], Vector3.ONE * radius * 1.25, material, 10)
	chain_root.set_meta("rest_rotation", chain_root.rotation)
	chain_root.set_meta("wiggle_axis", Vector3(0.12, 0.05, 0.18))
	chain_root.set_meta("wiggle_phase", phase)
	wiggle_parts.append(chain_root)
	return chain_root

func add_eye(parent: Node3D, position: Vector3, scale := 0.12) -> void:
	add_sphere(parent, position, Vector3.ONE * scale, accent_material(Color("#071015"), false), 12)
	add_sphere(parent, position + Vector3(0, scale * 0.08, scale * 0.42), Vector3.ONE * scale * 0.33, accent_material(Color("#69eaff"), true), 8)

func radial_point(angle: float, radius: float, height := 0.0) -> Vector3:
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)

func build_anemone(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, -0.06, 0), Vector3(1.55, 0.55, 1.55), mat)
	var mouth := accent_material(Color("#17070d"))
	add_sphere(root, Vector3(0, 0.23, 0), Vector3(0.46, 0.13, 0.46), mouth)
	for i in 20:
		var a := TAU * i / 20.0
		var ring := 0.36 + float(i % 3) * 0.23
		var p0 := radial_point(a, ring, 0.25)
		var outward := radial_point(a, 1.25 + 0.2 * sin(i * 2.0), 0.72 + 0.18 * cos(i))
		var tip := radial_point(a + sin(i) * 0.16, 1.55, 1.25 + 0.25 * sin(i * 1.7))
		add_chain(root, PackedVector3Array([p0, outward, tip]), 0.12, mat, i * 0.55)

func build_crab(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.12, 0), Vector3(1.62, 0.62, 1.05), mat)
	add_eye(root, Vector3(-0.48, 0.48, 0.82), 0.16)
	add_eye(root, Vector3(0.48, 0.48, 0.82), 0.16)
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := -0.62 + i * 0.4
			add_chain(root, PackedVector3Array([Vector3(side * 0.75, 0.05, z), Vector3(side * 1.35, -0.12, z + 0.12), Vector3(side * 1.62, -0.48, z + 0.38)]), 0.13, mat, i + side)
		var wrist := Vector3(side * 1.35, 0.5, 0.65)
		add_chain(root, PackedVector3Array([Vector3(side * 0.67, 0.25, 0.55), wrist]), 0.21, mat, side)
		add_sphere(root, wrist + Vector3(side * 0.28, 0.05, 0.05), Vector3(0.62, 0.38, 0.46), mat)
		add_cone(root, wrist + Vector3(side * 0.35, 0.08, 0.0), wrist + Vector3(side * 0.72, 0.23, 0.18), 0.16, mat)
		add_cone(root, wrist + Vector3(side * 0.35, 0.02, 0.0), wrist + Vector3(side * 0.72, -0.12, 0.18), 0.16, mat)

func build_squid(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.55, -0.2), Vector3(0.78, 1.75, 0.72), mat)
	add_cone(root, Vector3(0, 1.05, -0.2), Vector3(0, 1.75, -0.2), 0.5, mat)
	add_sphere(root, Vector3(0, -0.2, 0.12), Vector3(0.82, 0.55, 0.7), mat)
	add_eye(root, Vector3(-0.37, -0.05, 0.66), 0.14)
	add_eye(root, Vector3(0.37, -0.05, 0.66), 0.14)
	for i in 10:
		var a := TAU * i / 10.0
		var start := radial_point(a, 0.36, -0.37) + Vector3(0, 0, 0.08)
		var length := 1.75 if i < 2 else 1.15
		add_chain(root, PackedVector3Array([start, start + radial_point(a, length * 0.42, -0.38), start + radial_point(a + 0.18 * sin(i), length, -0.68)]), 0.1, mat, i)

func build_astronaut(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 1.0, 0), Vector3(0.72, 0.72, 0.72), mat)
	add_sphere(root, Vector3(0, 1.0, 0.35), Vector3(0.53, 0.48, 0.22), accent_material(Color("#122637"), true))
	add_sphere(root, Vector3(0, 0.2, 0), Vector3(0.82, 1.0, 0.55), mat)
	var joint := accent_material(Color("#8ea3ad"))
	for side in [-1.0, 1.0]:
		add_chain(root, PackedVector3Array([Vector3(side * 0.55, 0.55, 0), Vector3(side * 0.9, 0.12, 0.05), Vector3(side * 0.98, -0.25, 0.3)]), 0.16, mat, side)
		add_sphere(root, Vector3(side * 0.98, -0.28, 0.32), Vector3.ONE * 0.3, joint)
		add_chain(root, PackedVector3Array([Vector3(side * 0.3, -0.33, 0), Vector3(side * 0.38, -0.92, 0.05), Vector3(side * 0.48, -1.35, 0.27)]), 0.22, mat, side + 2.0)
		add_sphere(root, Vector3(side * 0.49, -1.36, 0.43), Vector3(0.48, 0.25, 0.68), joint)
	add_sphere(root, Vector3(0, 0.25, -0.48), Vector3(0.8, 0.92, 0.35), accent_material(Color("#4f5c62")))

func build_leech(root: Node3D, mat: Material) -> void:
	for i in 10:
		var x := -1.35 + i * 0.3
		var y := sin(i * 0.72) * 0.18
		var z := cos(i * 0.54) * 0.18
		var scale := 0.52 + sin(float(i) / 9.0 * PI) * 0.26
		add_sphere(root, Vector3(x, y, z), Vector3(0.52, scale, scale), mat, 12)
	add_sphere(root, Vector3(1.45, 0.03, 0.05), Vector3(0.22, 0.5, 0.5), accent_material(Color("#22070d")))

func build_urchin(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3.ZERO, Vector3.ONE * 1.25, mat, 20)
	for latitude: float in [-0.55, 0.0, 0.55]:
		var ring_radius := cos(latitude)
		for i in 12:
			var a := TAU * i / 12.0 + latitude
			var direction := Vector3(cos(a) * ring_radius, sin(latitude), sin(a) * ring_radius).normalized()
			add_cone(root, direction * 0.48, direction * 1.72, 0.105, mat)
	add_cone(root, Vector3(0, 0.48, 0), Vector3(0, 1.8, 0), 0.11, mat)
	add_cone(root, Vector3(0, -0.48, 0), Vector3(0, -1.55, 0), 0.11, mat)

func build_octopus(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.63, 0), Vector3(1.02, 1.35, 0.94), mat)
	add_eye(root, Vector3(-0.38, 0.68, 0.76), 0.16)
	add_eye(root, Vector3(0.38, 0.68, 0.76), 0.16)
	for i in 8:
		var a := TAU * i / 8.0
		var start := radial_point(a, 0.42, 0.0)
		add_chain(root, PackedVector3Array([start, radial_point(a, 1.0, -0.35), radial_point(a + 0.2 * sin(i), 1.55, -0.68)]), 0.18, mat, i)

func build_jellyfish(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.7, 0), Vector3(1.35, 0.72, 1.35), mat, 20)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.94
	rim.outer_radius = 1.08
	rim.rings = 28
	rim.ring_segments = 8
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.material_override = mat
	rim_node.position.y = 0.48
	root.add_child(rim_node)
	for i in 10:
		var a := TAU * i / 10.0
		var start := radial_point(a, 0.72, 0.38)
		add_chain(root, PackedVector3Array([start, start + Vector3(0, -0.72, 0), start + radial_point(a + 0.3, 0.28, -1.42)]), 0.075, mat, i)

func build_mantis_shrimp(root: Node3D, mat: Material) -> void:
	for i in 7:
		add_sphere(root, Vector3(0, 0.18, -0.82 + i * 0.27), Vector3(0.82 - i * 0.035, 0.48, 0.42), mat, 12)
	add_sphere(root, Vector3(0, 0.3, 1.05), Vector3(0.78, 0.58, 0.65), mat)
	for side in [-1.0, 1.0]:
		add_cylinder(root, Vector3(side * 0.28, 0.48, 1.24), Vector3(side * 0.5, 0.78, 1.35), 0.08, mat)
		add_eye(root, Vector3(side * 0.52, 0.84, 1.38), 0.18)
		add_chain(root, PackedVector3Array([Vector3(side * 0.48, 0.15, 0.85), Vector3(side * 0.95, 0.55, 0.65), Vector3(side * 1.12, 0.03, 1.08)]), 0.2, mat, side)
	for i in 5:
		for side in [-1.0, 1.0]:
			add_chain(root, PackedVector3Array([Vector3(side * 0.35, 0.0, -0.55 + i * 0.28), Vector3(side * 0.78, -0.28, -0.42 + i * 0.28)]), 0.075, mat, i + side)

func build_nautilus(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.42, -0.18), Vector3(1.38, 1.38, 0.62), mat, 20)
	var spiral_mat := accent_material(Color("#e6a54e"), true)
	for i in 15:
		var a0 := i * 0.56
		var a1 := (i + 1) * 0.56
		var r0 := 0.08 + i * 0.065
		var r1 := 0.08 + (i + 1) * 0.065
		add_cylinder(root, Vector3(cos(a0) * r0, 0.42 + sin(a0) * r0, 0.45), Vector3(cos(a1) * r1, 0.42 + sin(a1) * r1, 0.45), 0.045, spiral_mat, 1.0)
	add_sphere(root, Vector3(0, -0.25, 0.52), Vector3(0.72, 0.55, 0.55), mat)
	add_eye(root, Vector3(-0.28, -0.18, 0.92), 0.11)
	add_eye(root, Vector3(0.28, -0.18, 0.92), 0.11)
	for i in 12:
		var a := TAU * i / 12.0
		add_chain(root, PackedVector3Array([Vector3(cos(a) * 0.32, -0.35, 0.75), Vector3(cos(a) * 0.55, -0.78, 1.05 + sin(a) * 0.3)]), 0.055, mat, i)

func build_horseshoe_crab(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.15, 0.2), Vector3(1.45, 0.42, 1.62), mat, 20)
	add_sphere(root, Vector3(0, 0.12, -0.85), Vector3(1.05, 0.35, 0.8), mat)
	add_cone(root, Vector3(0, 0.0, -1.22), Vector3(0, -0.08, -2.55), 0.13, mat)
	add_eye(root, Vector3(-0.45, 0.43, 0.62), 0.09)
	add_eye(root, Vector3(0.45, 0.43, 0.62), 0.09)
	for side in [-1.0, 1.0]:
		for i in 4:
			add_chain(root, PackedVector3Array([Vector3(side * 0.42, -0.05, -0.55 + i * 0.4), Vector3(side * 0.94, -0.38, -0.45 + i * 0.42)]), 0.075, mat, i + side)

func build_cuttlefish(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.25, -0.2), Vector3(1.18, 0.58, 1.72), mat, 20)
	add_sphere(root, Vector3(0, 0.2, 0.95), Vector3(0.82, 0.55, 0.72), mat)
	add_sphere(root, Vector3(-1.0, 0.18, -0.25), Vector3(0.42, 0.12, 1.42), mat)
	add_sphere(root, Vector3(1.0, 0.18, -0.25), Vector3(0.42, 0.12, 1.42), mat)
	add_eye(root, Vector3(-0.37, 0.38, 1.42), 0.13)
	add_eye(root, Vector3(0.37, 0.38, 1.42), 0.13)
	for i in 10:
		var a := -0.9 + i * 0.2
		var start := Vector3(sin(a) * 0.35, 0.02, 1.35)
		add_chain(root, PackedVector3Array([start, start + Vector3(sin(a) * 0.55, -0.28, 0.68)]), 0.075, mat, i)

func build_starfish(root: Node3D, mat: Material) -> void:
	add_sphere(root, Vector3(0, 0.02, 0), Vector3(0.75, 0.3, 0.75), mat)
	for i in 5:
		var a := TAU * i / 5.0 + PI * 0.5
		var p0 := radial_point(a, 0.25, 0.0)
		var p1 := radial_point(a, 0.92, -0.06)
		var p2 := radial_point(a, 1.65, -0.15)
		add_cylinder(root, p0, p1, 0.36, mat, 0.62)
		add_cylinder(root, p1, p2, 0.24, mat, 0.08)

func build_lobster(root: Node3D, mat: Material) -> void:
	for i in 6:
		add_sphere(root, Vector3(0, 0.16, -0.85 + i * 0.3), Vector3(0.78 - i * 0.03, 0.48, 0.46), mat, 12)
	add_sphere(root, Vector3(0, 0.26, 0.92), Vector3(0.85, 0.62, 0.75), mat)
	add_eye(root, Vector3(-0.35, 0.55, 1.48), 0.13)
	add_eye(root, Vector3(0.35, 0.55, 1.48), 0.13)
	for side in [-1.0, 1.0]:
		for i in 4:
			add_chain(root, PackedVector3Array([Vector3(side * 0.38, 0.0, -0.35 + i * 0.35), Vector3(side * 0.95, -0.35, -0.25 + i * 0.35)]), 0.075, mat, i + side)
		var wrist := Vector3(side * 1.12, 0.18, 0.82)
		add_chain(root, PackedVector3Array([Vector3(side * 0.5, 0.22, 0.72), wrist]), 0.17, mat, side)
		add_sphere(root, wrist + Vector3(side * 0.2, 0, 0.18), Vector3(0.52, 0.34, 0.62), mat)
		add_cone(root, wrist + Vector3(side * 0.22, 0.05, 0.32), wrist + Vector3(side * 0.62, 0.18, 0.7), 0.13, mat)
		add_cone(root, wrist + Vector3(side * 0.22, -0.02, 0.32), wrist + Vector3(side * 0.62, -0.16, 0.7), 0.13, mat)
		add_chain(root, PackedVector3Array([Vector3(side * 0.25, 0.42, 1.35), Vector3(side * 0.65, 0.62, 2.0), Vector3(side * 0.95, 0.58, 2.75)]), 0.035, mat, side + 7.0)
	for side in [-1.0, 0.0, 1.0]:
		add_sphere(root, Vector3(side * 0.48, 0.1, -1.2), Vector3(0.52, 0.18, 0.62), mat)

func build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.045, 0.075, 0.9)
	panel.position = Vector2(24, 24)
	panel.size = Vector2(560, 108)
	canvas.add_child(panel)
	title_label = Label.new()
	title_label.position = Vector2(42, 38)
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override("font_color", Color("#e8f8ff"))
	canvas.add_child(title_label)
	detail_label = Label.new()
	detail_label.position = Vector2(43, 75)
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", Color("#79bed0"))
	canvas.add_child(detail_label)
	var help := Label.new()
	help.text = "A / D or arrow keys  •  inspect all 14 procedural 3D specimens"
	help.position = Vector2(43, 104)
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("#7791a0"))
	canvas.add_child(help)

func select_specimen(index: int) -> void:
	selected = index
	if title_label:
		title_label.text = "%02d  /  %s" % [index + 1, SPECIMENS[index][0]]
		detail_label.text = String(SPECIMENS[index][1]).to_upper()
