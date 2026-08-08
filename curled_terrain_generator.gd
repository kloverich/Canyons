## Builds the large, curled "wave / frond" rock forms used by the canyon demo.
##
## The mesh is a broad 2D cliff silhouette extruded through Z. This is more
## useful than a heightmap for side-scrollers: it can make true overhangs,
## arches and curls, and the triangle mesh doubles as walkable collision.
class_name CurledTerrainGenerator
extends RefCounted

enum BoundaryMode { INFINITE, PERIODIC }

var seed: int = 8271
var boundary_mode: BoundaryMode = BoundaryMode.INFINITE
var period: float = 30.0
var path_segments := 56

var rock_material: StandardMaterial3D

func _init(p_seed := 8271, p_boundary_mode := BoundaryMode.INFINITE, p_period := 30.0) -> void:

	seed = p_seed
	boundary_mode = p_boundary_mode
	period = p_period
	rock_material = StandardMaterial3D.new()
	rock_material.albedo_color = Color("#51403b")
	rock_material.roughness = 0.96
	rock_material.metallic = 0.04
	rock_material.vertex_color_use_as_albedo = true
	rock_material.cull_mode = BaseMaterial3D.CULL_DISABLED


## Returns one terrain chunk.  In PERIODIC mode chunk -1, 0, and 1 repeat
## exactly every `period` units; INFINITE uses a new deterministic seed per cell.
func build_chunk(chunk_index: int) -> Node3D:

	var root := Node3D.new()
	root.name = "TerrainChunk_%d" % chunk_index
	var cell := posmod(chunk_index, 1) if boundary_mode == BoundaryMode.PERIODIC else chunk_index
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + cell * 104729
	var origin_x := chunk_index * period
	var form_count := 2
	for form_index in form_count:
		var local_x := lerpf(3.0, period - 3.0, (form_index + 0.5) / form_count) + rng.randf_range(-1.0, 1.0)
		var width := rng.randf_range(7.0, 10.5)
		var height := rng.randf_range(8.0, 13.0)
		# These are deliberately very substantial: the concept is made of heavy
		# sedimentary sheets, not tentacles or pipes.
		var thickness := rng.randf_range(1.35, 2.10)
		var depth := rng.randf_range(0.75, 1.25)
		# About two-thirds of a turn gives the concept-art hook: crest, inward
		# underside, downward-pointing tip. A full turn reads like a snail shell.
		var curl_turns := rng.randf_range(0.58, 0.68)
		var facing := -1.0 if rng.randf() < 0.5 else 1.0
		var rock := _build_curl_mesh(local_x, width, height, thickness, depth, curl_turns, facing, rng)
		rock.position.x = origin_x
		root.add_child(rock)
	return root


func _build_curl_mesh(local_x: float, width: float, height: float, thickness: float, depth: float, curl_turns: float, facing: float, rng: RandomNumberGenerator) -> MeshInstance3D:

	var centers := PackedVector3Array()
	for i in path_segments + 1:
		var t := float(i) / path_segments
		centers.append(_curl_centerline(t, local_x, width, height, curl_turns, facing))
	var cliff_edges := _build_cliff_edges(centers, thickness, rng)
	var outer: PackedVector2Array = cliff_edges[0]
	var inner: PackedVector2Array = cliff_edges[1]
	var profile := PackedVector2Array(outer)
	var reversed_inner := PackedVector2Array(inner)
	reversed_inner.reverse()
	profile.append_array(reversed_inner)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Build the face as connected cliff slices. Tight hooks can overlap, which is
	# fine visually and avoids a polygon triangulator punching holes in the curl.
	for i in outer.size() - 1:
		var base := vertices.size()
		vertices.append_array([
			Vector3(outer[i].x, outer[i].y, depth),
			Vector3(inner[i].x, inner[i].y, depth),
			Vector3(outer[i + 1].x, outer[i + 1].y, depth),
			Vector3(inner[i + 1].x, inner[i + 1].y, depth),
			Vector3(outer[i].x, outer[i].y, -depth),
			Vector3(inner[i].x, inner[i].y, -depth),
			Vector3(outer[i + 1].x, outer[i + 1].y, -depth),
			Vector3(inner[i + 1].x, inner[i + 1].y, -depth),
		])
		for unused in 4:
			normals.append(Vector3.FORWARD)
			colors.append(Color("#4b342a"))
		for unused in 4:
			normals.append(Vector3.BACK)
			colors.append(Color("#251b1b"))
		indices.append_array([base, base + 1, base + 2, base + 2, base + 1, base + 3])
		indices.append_array([base + 6, base + 5, base + 4, base + 7, base + 5, base + 6])
	# Extruded perimeter walls catch the light and make the ledges read as 3D.
	for i in profile.size():
		var next := (i + 1) % profile.size()
		var edge := (profile[next] - profile[i]).normalized()
		var wall_normal := Vector3(edge.y, -edge.x, 0.0)
		var base := vertices.size()
		vertices.append_array([
			Vector3(profile[i].x, profile[i].y, depth),
			Vector3(profile[i].x, profile[i].y, -depth),
			Vector3(profile[next].x, profile[next].y, depth),
			Vector3(profile[next].x, profile[next].y, -depth),
		])
		for unused in 4:
			normals.append(wall_normal)
			colors.append(Color("#35251f"))
		indices.append_array([base, base + 1, base + 2, base + 2, base + 1, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = "CurlingRock"
	instance.mesh = mesh
	instance.material_override = rock_material
	var body := StaticBody3D.new()
	body.name = "WalkableCollision"
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	instance.add_child(body)
	_add_sedimentary_ridges(instance, centers, thickness, depth)
	return instance


func _build_cliff_edges(centers: PackedVector3Array, thickness: float, rng: RandomNumberGenerator) -> Array:

	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in centers.size():
		var tangent := _path_tangent(centers, i)
		var side := Vector2(-tangent.y, tangent.x).normalized()
		var t := float(i) / path_segments
		var flare := lerpf(1.75, 0.13, pow(t, 1.12))
		var strata_wobble := 1.0 + 0.055 * sin(i * 1.63 + rng.seed * 0.001)
		var center := Vector2(centers[i].x, centers[i].y)
		outer.append(center + side * thickness * flare * strata_wobble)
		inner.append(center - side * thickness * flare * (0.82 + 0.04 * sin(i * 1.17)))
	return [outer, inner]


## Long, shallow raised ribbons provide the horizontal, stacked rock language
## visible in the reference. They follow the curl instead of being random decals.
func _add_sedimentary_ridges(parent: Node3D, centers: PackedVector3Array, thickness: float, depth: float) -> void:

	var ridge_material := StandardMaterial3D.new()
	ridge_material.albedo_color = Color("#211716")
	ridge_material.roughness = 1.0
	for stripe in 9:
		var across := lerpf(-0.72, 0.72, float(stripe) / 8.0)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		for i in centers.size():
			var tangent := _path_tangent(centers, i)
			var side := Vector3(-tangent.y, tangent.x, 0.0).normalized()
			var taper := lerpf(1.75, 0.13, pow(float(i) / path_segments, 1.12))
			var ridge_center := centers[i] + side * across * thickness * taper + Vector3.FORWARD * (depth + 0.025)
			var half_width := 0.035 + 0.012 * taper
			vertices.append(ridge_center - side * half_width)
			vertices.append(ridge_center + side * half_width)
			normals.append(Vector3.FORWARD)
			normals.append(Vector3.FORWARD)
		for i in centers.size() - 1:
			var a := i * 2
			indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var ridge := MeshInstance3D.new()
		ridge.name = "SedimentaryRidge"
		ridge.mesh = mesh
		ridge.material_override = ridge_material
		parent.add_child(ridge)


func _path_tangent(centers: PackedVector3Array, index: int) -> Vector3:

	if index == 0:
		return (centers[1] - centers[0]).normalized()
	if index == centers.size() - 1:
		return (centers[index] - centers[index - 1]).normalized()
	return (centers[index + 1] - centers[index - 1]).normalized()


func _curl_centerline(t: float, x: float, width: float, height: float, curl_turns: float, facing: float) -> Vector3:

	# First, a broad outer wave; its crest is deliberately long and overhung.
	# The final half reverses tightly toward the body like a breaking wave.
	if t < 0.48:
		var q := t / 0.48
		var p0 := Vector2(x, 0.0)
		var p1 := Vector2(x - facing * width * 0.26, height * 0.35)
		# The low third control makes the path enter the spiral while still rising;
		# the spiral itself creates the large, top-heavy crest without a kink.
		var p2 := Vector2(x + facing * width * 0.88, height * 0.40)
		var p3 := Vector2(x + facing * width * 1.04, height * 0.66)
		var p := _bezier(p0, p1, p2, p3, q)
		return Vector3(p.x, p.y, 0.0)
	var q := (t - 0.48) / 0.52
	var center := Vector2(x + facing * width * 0.53, height * 0.62)
	var start_radius := width * 0.51
	# Begin on the right of the spiral and travel up, over, then inward.
	var angle := 0.08 + q * curl_turns * TAU
	var radius := lerpf(start_radius, width * 0.055, pow(q, 0.78))
	var p := center + Vector2(cos(angle) * radius * facing, sin(angle) * radius)
	return Vector3(p.x, p.y, 0.0)


func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:

	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t
