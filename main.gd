extends Node2D

# Stick Rig Aquarium — every creature is built from animated line segments.
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
const SKIN_UV_PER_PIXEL := 0.0009 # One shared, large-scale projection across an entire creature.
const LIMB_UV_SCALE := 0.07 # Fixed bone-local UV range: texture travels with each animated sleeve.
var active_skin: Texture2D = SKIN_TEXTURES[0]
var active_skin_origin := Vector2.ZERO
var t := 0.0
var selected := 0
var creatures := [
	["GIANT SEA ANEMONE", "petal-chain rig", Color("#ff7b9c"), 14],
	["GIANT CRAB", "eight-leg gait", Color("#ff9a58"), 8],
	["GIANT SQUID", "tentacle wave rig", Color("#bd8cff"), 10],
	["ASTRONAUT", "zero-g stick suit", Color("#e9f3ff"), 6],
	["GIANT LEECH", "segment crawl rig", Color("#83ed92"), 9],
	["SEA URCHIN", "radial spine rig", Color("#d783ff"), 22],
	["OCTOPUS", "eight-arm rig", Color("#fa75b1"), 8],
	["JELLYFISH", "bell + tendril rig", Color("#60dfff"), 9],
	["MANTIS SHRIMP", "raptor-arm rig", Color("#78efc2"), 10],
	["NAUTILUS", "spiral shell rig", Color("#ffcb74"), 12],
	["HORSESHOE CRAB", "tail + leg rig", Color("#a6baf9"), 8],
	["CUTTLEFISH", "fin ripple rig", Color("#ffd2b4"), 10],
	["STARFISH", "five-arm rig", Color("#ff8c72"), 5],
	["LOBSTER", "claw + antenna rig", Color("#f27870"), 8],
]

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT, KEY_D, KEY_SPACE]: selected = (selected + 1) % creatures.size()
		if event.keycode in [KEY_LEFT, KEY_A]: selected = (selected - 1 + creatures.size()) % creatures.size()
	if event is InputEventMouseButton and event.pressed:
		var cols: int = maxi(1, int((get_viewport_rect().size.x - 48.0) / 190.0))
		var local: Vector2 = event.position - Vector2(24, 160)
		var index: int = int(local.y / 142.0) * cols + int(local.x / 190.0)
		if local.x >= 0 and local.y >= 0 and index >= 0 and index < creatures.size(): selected = index

func _draw() -> void:
	var s := get_viewport_rect().size
	# deep-water blueprint field
	draw_rect(Rect2(Vector2.ZERO, s), Color("#07101f"))
	for x in range(0, int(s.x) + 1, 48): draw_line(Vector2(x, 0), Vector2(x, s.y), Color(0.12,0.24,0.37,0.22), 1)
	for y in range(0, int(s.y) + 1, 48): draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.12,0.24,0.37,0.22), 1)
	draw_string(ThemeDB.fallback_font, Vector2(24, 42), "STICK RIG SPECIMEN ARCHIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#e8f8ff"))
	draw_string(ThemeDB.fallback_font, Vector2(25, 70), "14 animated 2D invertebrate rigs  •  click a specimen or use ← →", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#7ca4bb"))
	draw_line(Vector2(24, 92), Vector2(s.x - 24, 92), Color("#2a6073"), 2)
	var cols: int = maxi(1, int((s.x - 48.0) / 190.0))
	for i in creatures.size():
		var col: int = i % cols
		var row: int = i / cols
		var r := Rect2(24 + col * 190, 112 + row * 142, 172, 124)
		draw_card(r, i)
	var info_y: float = minf(s.y - 64, 112 + (int((creatures.size() - 1) / cols) + 1) * 142 + 8)
	var c = creatures[selected]
	draw_rect(Rect2(24, info_y, s.x - 48, 42), Color("#102741"), true)
	draw_line(Vector2(24, info_y), Vector2(s.x - 24, info_y), c[2], 2)
	draw_string(ThemeDB.fallback_font, Vector2(38, info_y + 27), "ACTIVE RIG  /  " + c[0] + "  /  " + c[1].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c[2])

func draw_card(r: Rect2, index: int) -> void:
	var c = creatures[index]
	var active := index == selected
	draw_rect(r, Color("#11253a") if active else Color("#0c1a2b"), true)
	draw_rect(r, c[2] if active else Color("#25415a"), false, 2 if active else 1)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(9, 18), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ecf7ff"))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(9, 112), c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#7c9aad"))
	var center := r.position + Vector2(86, 62)
	active_skin = SKIN_TEXTURES[index]
	active_skin_origin = center
	draw_rig(center, index, c[2], float(index) * 0.47)

# The bright line is the original wire skeleton. A soft, spline-edged sleeve is
# generated around every bone, using those two moving joints as its anchors.
func stick(a: Vector2, b: Vector2, color: Color, w := 3.0) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.01:
		return
	var tangent := axis / length
	var normal := Vector2(-tangent.y, tangent.x)
	var radius := maxf(3.4, w * 1.15)
	draw_spline_skin(a, b, normal, radius, color)
	# The stick is now a hidden deformation bone: only its textured surface is rendered.

func draw_spline_skin(a: Vector2, b: Vector2, normal: Vector2, radius: float, color: Color) -> void:
	# Two smooth, bowed polylines approximate the opposing sides of a spline tube.
	# The varying width makes each limb feel organic rather than like a rigid rectangle.
	var edge_a := PackedVector2Array()
	var edge_b := PackedVector2Array()
	var samples := 7
	for i in range(samples + 1):
		var u := float(i) / samples
		var along := a.lerp(b, u)
		var bulge := 0.68 + sin(u * PI) * 0.42
		var side_wave := sin(u * PI) * radius * 0.16
		edge_a.append(along + normal * (radius * bulge + side_wave))
		edge_b.append(along - normal * (radius * bulge - side_wave))
	var skin := PackedVector2Array()
	for point in edge_a: skin.append(point)
	for i in range(edge_b.size() - 1, -1, -1): skin.append(edge_b[i])
	var skin_uv := PackedVector2Array()
	for i in range(edge_a.size()):
		skin_uv.append(Vector2(0.44 + float(i) / samples * LIMB_UV_SCALE, 0.46))
	for i in range(edge_b.size() - 1, -1, -1):
		skin_uv.append(Vector2(0.44 + float(i) / samples * LIMB_UV_SCALE, 0.46 + LIMB_UV_SCALE))
	# These UVs are fixed in the spline mesh's local length/width coordinates. Unlike
	# world projection, the pixels therefore travel and rotate with the moving bone.
	draw_polygon(skin, PackedColorArray([Color.WHITE]), skin_uv, active_skin)

func chain(base: Vector2, angle: float, count: int, length: float, color: Color, phase: float, wave := 0.4) -> Vector2:
	var p := base
	for n in count:
		var a := angle + sin(t * 2.1 + phase + n * 0.7) * wave
		var q := p + Vector2.from_angle(a) * length
		stick(p, q, color, max(1.0, 3.3 - n * 0.22))
		p = q
	return p

func oval_sticks(center: Vector2, rx: float, ry: float, color: Color, segments := 12, rotation := 0.0) -> void:
	# A closed silhouette is one continuous skin mesh, rather than individual bone sleeves.
	var outline := PackedVector2Array()
	for n in range(segments):
		var a := TAU * n / segments
		outline.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rotation))
	var skin_uv := PackedVector2Array()
	for point in outline:
		skin_uv.append(Vector2(0.5, 0.5) + (point - active_skin_origin) * SKIN_UV_PER_PIXEL)
	# One continuous UV-mapped skin surface; the wires are drawn above it below.
	draw_polygon(outline, PackedColorArray([Color.WHITE]), skin_uv, active_skin)
	var prev := outline[0]
	for n in range(1, segments + 1):
		var a := TAU * n / segments
		var p := center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rotation)
		stick(prev, p, color, 3)
		prev = p

func draw_rig(p: Vector2, id: int, color: Color, phase: float) -> void:
	var k := t + phase
	match id:
		0: # anemone
			oval_sticks(p + Vector2(0,10), 22, 13, color)
			for n in 14: chain(p + Vector2(0,5), -PI + TAU*n/14.0, 3, 11, color, k+n, 0.48)
		1: # crab
			oval_sticks(p, 26, 14, color, 10)
			for n in 4:
				chain(p + Vector2(-18, -7+n*5), PI + 0.2, 3, 12, color, k+n, 0.42)
				chain(p + Vector2(18, -7+n*5), -0.2, 3, 12, color, k+n+2, 0.42)
		2: # squid
			oval_sticks(p + Vector2(0,-8), 15, 28, color, 10)
			for n in 10: chain(p + Vector2(0,15), PI/2 + (n-4.5)*0.11, 4, 10, color, k+n, 0.36)
		3: # astronaut
			oval_sticks(p+Vector2(0,-18), 11, 12, color, 8)
			oval_sticks(p+Vector2(0,5), 15, 20, color, 8)
			chain(p+Vector2(-12,0), 2.7, 2, 15, color, k, 0.2); chain(p+Vector2(12,0), .4, 2, 15, color, k+1, 0.2)
			chain(p+Vector2(-7,22), 1.95, 2, 15, color, k+2, 0.15); chain(p+Vector2(7,22), 1.2, 2, 15, color, k+3, 0.15)
		4: # leech
			var last := p + Vector2(-37,0)
			for n in 7:
				var q := p + Vector2(-37+n*12, sin(k*3+n*.9)*8)
				stick(last,q,color,6); last=q
		5: # urchin
			oval_sticks(p, 15,15,color,10)
			for n in 22: chain(p, TAU*n/22.0, 2, 13, color, k+n*.2, 0.16)
		6: # octopus
			oval_sticks(p+Vector2(0,-10), 19,20,color,10)
			for n in 8: chain(p+Vector2(0,8), PI/2+(n-3.5)*.28,4,11,color,k+n,.42)
		7: # jellyfish
			for n in 7: stick(p+Vector2(-28+n*9,-3),p+Vector2(-23+n*8,-15+sin(k+n)*4),color,3)
			for n in 9: chain(p+Vector2(-27+n*7,2),PI/2,3,10,color,k+n,.25)
		8: # shrimp
			chain(p+Vector2(-30,-3),0,6,11,color,k,.18)
			for n in 5: chain(p+Vector2(-10+n*9,5),PI/2+.35,2,13,color,k+n,.35)
			chain(p+Vector2(20,-4),-.7,3,12,color,k,0.3)
		9: # nautilus
			var last:=p+Vector2(28,0)
			for n in 1: pass
			for n in range(1,25):
				var a:=n*.52; var q:=p+Vector2(cos(a),sin(a))*(30-n*.95); stick(last,q,color,3); last=q
		10: # horseshoe
			oval_sticks(p,30,17,color,10)
			chain(p+Vector2(28,0),0,3,15,color,k,.1)
			for n in 4: chain(p+Vector2(-12+n*9,8),PI/2+.45,2,12,color,k+n,.25)
		11: # cuttlefish
			oval_sticks(p,32,15,color,12)
			for n in 6:
				stick(p+Vector2(-25+n*10,-15),p+Vector2(-25+n*10,-25+sin(k*4+n)*5),color,2)
				stick(p+Vector2(-25+n*10,15),p+Vector2(-25+n*10,25+sin(k*4+n)*5),color,2)
			chain(p+Vector2(28,0),0,2,11,color,k,.25)
		12: # starfish
			for n in 5: chain(p, -PI/2+TAU*n/5,3,13,color,k+n,.2)
		13: # lobster
			chain(p+Vector2(-22,0),0,5,11,color,k,.15)
			for n in 4: chain(p+Vector2(-10+n*9,5),PI/2+.45,2,11,color,k+n,.25)
			chain(p+Vector2(-23,-5),-2.35,3,11,color,k,.25); chain(p+Vector2(-23,5),2.35,3,11,color,k+1,.25)
