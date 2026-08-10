"""Unwrap the curved source leech onto a mathematically straight centerline."""
import bpy
from mathutils import Vector

SOURCE = "/home/kaiper/canyons/assets/leech.glb"
OUTPUT = "/home/kaiper/canyons/assets/leech_straight.glb"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=SOURCE)

armature = bpy.data.objects["RIG-Armature.001"]
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.find_armature() == armature)
names = ["DEF-Bone"] + [f"DEF-Bone.{index:03d}" for index in range(1, 11)]

# Build world-space centerline segments from the bones that actually weight
# the render mesh. Candidate segments are selected from vertex groups, which
# prevents the folded tail being matched to the nearby middle of the body.
heads = [armature.matrix_world @ armature.data.bones[name].head_local for name in names]
heads.append(armature.matrix_world @ armature.data.bones[names[-1]].tail_local)
segments = []
distance = 0.0
for index, name in enumerate(names):
    head = heads[index]
    tail = heads[index + 1]
    length = (tail - head).length
    # The exported Rigify chain contains one zero-distance pivot whose bone
    # tail points backward. Follow consecutive joint heads instead; that is
    # the actual continuous deformation path through the mesh.
    segments.append((index, name, head, tail, distance, length))
    distance += length

world_up = Vector((0.0, 1.0, 0.0))
group_names = {group.index: group.name for group in mesh.vertex_groups}
for vertex in mesh.data.vertices:
    point = mesh.matrix_world @ vertex.co
    weighted = [
        (element.weight, group_names[element.group])
        for element in vertex.groups
        if element.weight > 0.01 and group_names[element.group].startswith("DEF-")
    ]
    if weighted:
        dominant_name = max(weighted)[1]
        dominant = names.index(dominant_name)
        candidates = [segment for segment in segments if abs(segment[0] - dominant) <= 1 and segment[5] > 0.01]
    else:
        candidates = [segment for segment in segments if segment[5] > 0.01]
    best = None
    for _, _, head, tail, start, length in candidates:
        tangent = (tail - head).normalized()
        along = max(0.0, min(length, (point - head).dot(tangent)))
        center = head + tangent * along
        distance_squared = (point - center).length_squared
        if best is None or distance_squared < best[0]:
            best = (distance_squared, center, tangent, start + along)
    _, center, tangent, longitudinal = best
    side = world_up.cross(tangent).normalized()
    if side.length_squared < 0.001:
        side = Vector((1.0, 0.0, 0.0))
    cross_up = tangent.cross(side).normalized()
    offset = point - center
    unwrapped = Vector((offset.dot(side), offset.dot(cross_up), longitudinal - distance * 0.5))
    vertex.co = unwrapped

mesh.parent = None
mesh.matrix_world.identity()
for polygon in mesh.data.polygons:
    polygon.use_smooth = True
for modifier in list(mesh.modifiers):
    mesh.modifiers.remove(modifier)

# The runtime animation is transform-based, so export only the corrected
# render mesh and remove every source rig/widget from the generated asset.
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format="GLB",
    use_selection=True,
    export_animations=False,
    export_yup=True,
)
print(f"Wrote straightened leech to {OUTPUT}")
