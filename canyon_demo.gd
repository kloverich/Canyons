extends Node3D

const CurledTerrain = preload("res://curled_terrain_generator.gd")

var generator: CurledTerrainGenerator
var terrain_root: Node3D
var camera: Camera3D
var seed := 8271
var periodic := false
var seed_label: Label

func _ready() -> void:
	_build_world()
	_build_ui()
	_rebuild()

func _process(delta: float) -> void:
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y -= 1.0
	if movement != Vector3.ZERO:
		camera.position += movement.normalized() * delta * 11.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			seed += 1
			_rebuild()
		elif event.keycode == KEY_P:
			periodic = not periodic
			_rebuild()
		elif event.keycode == KEY_Q:
			camera.position.z = clampf(camera.position.z + 2.0, 10.0, 40.0)
		elif event.keycode == KEY_E:
			camera.position.z = clampf(camera.position.z - 2.0, 10.0, 40.0)

func _rebuild() -> void:
	if terrain_root:
		terrain_root.queue_free()
	terrain_root = Node3D.new()
	terrain_root.name = "ProceduralCanyonSamples"
	add_child(terrain_root)
	generator = CurledTerrainGenerator.new(seed, CurledTerrainGenerator.BoundaryMode.PERIODIC if periodic else CurledTerrainGenerator.BoundaryMode.INFINITE, 28.0)
	for chunk_index in range(-1, 2):
		terrain_root.add_child(generator.build_chunk(chunk_index))
	seed_label.text = "SEED %d  |  %s\nR: new shapes    P: boundary mode    A/D/W/S: camera    Q/E: zoom" % [seed, "PERIODIC (repeating)" if periodic else "INFINITE (unique chunks)"]

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#111827")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#91a9be")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("#ffd0a0")
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_color = Color("#5da5d0")
	fill.light_energy = 1.1
	add_child(fill)
	camera = Camera3D.new()
	camera.position = Vector3(0, 7, 27)
	add_child(camera)
	camera.look_at(Vector3(0, 4.5, 0))
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(110, 18)
	floor.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#251d20")
	floor_mat.roughness = 1.0
	floor.material_override = floor_mat
	floor.position = Vector3(0, -1.2, 0)
	add_child(floor)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.025, 0.05, 0.78)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(650, 74)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "CURLING CANYON ROCK GENERATOR"
	title.position = Vector2(34, 26)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f5bd8b"))
	layer.add_child(title)
	seed_label = Label.new()
	seed_label.position = Vector2(35, 53)
	seed_label.add_theme_font_size_override("font_size", 15)
	seed_label.add_theme_color_override("font_color", Color("#b6d9ed"))
	layer.add_child(seed_label)
