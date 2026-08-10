extends Node3D

## Procedural presentation for the supplied static worm mesh.
## The GLB has no skeleton or animation clips, so a looping body sway is
## combined with a vertex-wave shader for an organic peristaltic motion.
const FEED_TARGET := preload("res://feed_target.gd")
var worm: Node3D
var animation_player: AnimationPlayer
var feed_target: Node3D
var eating := false
var hint: Label

func _ready() -> void:
	# The original worm GLB is not in the current asset drop, so keep this
	# showcase self-contained with a tapered segmented stand-in until it is
	# re-added. The animation and feeding test work identically on the GLB.
	worm = Node3D.new()
	for i in 5:
		var segment := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = lerpf(0.25, 0.42, sin(PI * float(i) / 4.0))
		mesh.height = 0.8
		mesh.radial_segments = 16
		segment.mesh = mesh
		segment.position = Vector3((i - 2) * 0.42, 0, 0)
		segment.rotation.z = PI * 0.5
		worm.add_child(segment)
	worm.name = "AlienWormMesh"
	worm.scale = Vector3.ONE * 3.2
	add_child(worm)
	_apply_motion_materials(worm)
	_build_looping_motion()
	feed_target = Node3D.new()
	feed_target.set_script(FEED_TARGET)
	add_child(feed_target)
	var layer := CanvasLayer.new()
	add_child(layer)
	hint = Label.new()
	hint.text = "ALIEN WORM  |  2: eat player  |  Esc: launcher"
	hint.position = Vector2(24, 24)
	hint.add_theme_font_size_override("font_size", 18)
	layer.add_child(hint)

func _process(_delta: float) -> void:
	if is_instance_valid(worm):
		worm.rotation.z = sin(Time.get_ticks_msec() * 0.0017) * 0.07
	if feed_target:
		if eating:
			feed_target.begin(Vector3(2.0, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), Vector3.LEFT) if not feed_target.active else feed_target.tick(_delta)
		else:
			feed_target.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://test_launcher.tscn")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2:
		eating = not eating

func _apply_motion_materials(node: Node) -> void:
	for child in node.get_children():
		_apply_motion_materials(child)
	if not node is MeshInstance3D:
		return
	var mesh_node := node as MeshInstance3D
	var source := mesh_node.get_active_material(0)
	var skin := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled, diffuse_burley;\nuniform sampler2D albedo_texture : source_color, filter_linear_mipmap;\nuniform float wave_strength = 0.075;\nvoid vertex() {\n float along = VERTEX.z;\n float envelope = smoothstep(-0.48, -0.18, along) * (1.0 - smoothstep(0.18, 0.48, along));\n float phase = TIME * 4.0 - along * 15.0;\n VERTEX.x += sin(phase) * wave_strength * envelope;\n VERTEX.y += cos(phase * 0.86) * wave_strength * 0.62 * envelope;\n}\nvoid fragment() {\n vec4 texel = texture(albedo_texture, UV);\n ALBEDO = texel.rgb;\n ALPHA = texel.a;\n ROUGHNESS = 0.42;\n}\n"
	skin.shader = shader
	if source is BaseMaterial3D and (source as BaseMaterial3D).albedo_texture:
		skin.set_shader_parameter("albedo_texture", (source as BaseMaterial3D).albedo_texture)
	mesh_node.material_override = skin

func _build_looping_motion() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "WormAnimation"
	add_child(animation_player)
	var library := AnimationLibrary.new()
	var crawl := Animation.new()
	crawl.resource_name = "PeristalticCrawl"
	crawl.length = 3.2
	crawl.loop_mode = Animation.LOOP_LINEAR
	var rotation_track := crawl.add_track(Animation.TYPE_VALUE)
	crawl.track_set_path(rotation_track, NodePath(".:rotation:y"))
	crawl.value_track_set_update_mode(rotation_track, Animation.UPDATE_CONTINUOUS)
	crawl.track_insert_key(rotation_track, 0.0, -0.12)
	crawl.track_insert_key(rotation_track, 0.8, 0.12)
	crawl.track_insert_key(rotation_track, 1.6, -0.12)
	crawl.track_insert_key(rotation_track, 2.4, 0.12)
	crawl.track_insert_key(rotation_track, 3.2, -0.12)
	var position_track := crawl.add_track(Animation.TYPE_VALUE)
	crawl.track_set_path(position_track, NodePath(".:position:x"))
	crawl.value_track_set_update_mode(position_track, Animation.UPDATE_CONTINUOUS)
	crawl.track_insert_key(position_track, 0.0, -0.18)
	crawl.track_insert_key(position_track, 1.6, 0.18)
	crawl.track_insert_key(position_track, 3.2, -0.18)
	library.add_animation("PeristalticCrawl", crawl)
	animation_player.add_animation_library("", library)
	animation_player.play("PeristalticCrawl")
