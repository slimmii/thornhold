"""Round-trip validation for the generated .blend and .glb deliverables."""
import bpy
import json
import math
import struct
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'blackguard.blend'))
rig=bpy.data.objects['Blackguard_Rig']
character=bpy.data.collections['BLACKGUARD | Character']
meshes=[obj for obj in character.objects if obj.type=='MESH']
assert len(rig.data.bones)==18
assert all(obj.data.uv_layers for obj in meshes)
assert all(any(mod.type=='ARMATURE' and mod.object==rig for mod in obj.modifiers) for obj in meshes)
assert bpy.data.images['REFERENCE | Blackguard concept'].packed_file

def bounds(objects):
    points=[obj.matrix_world@vertex.co for obj in objects for vertex in obj.data.vertices]
    return [tuple(min(p[i] for p in points) for i in range(3)),
            tuple(max(p[i] for p in points) for i in range(3))]

source_bounds=bounds(meshes)
source_triangles=0
for obj in meshes:
    obj.data.calc_loop_triangles()
    source_triangles+=len(obj.data.loop_triangles)

# Check a real head pose moves the weighted helmet, then reset the pose.
head=rig.pose.bones['head']
helmet=bpy.data.objects['Helm | brow and crown']
def evaluated_vertex(obj):
    graph=bpy.context.evaluated_depsgraph_get()
    evaluated=obj.evaluated_get(graph)
    return evaluated.matrix_world@evaluated.data.vertices[0].co
before=evaluated_vertex(helmet)
head.rotation_mode='XYZ'
head.rotation_euler.z=.25
bpy.context.view_layer.update()
after=evaluated_vertex(helmet)
assert (after-before).length>.01, 'Helmet does not follow head bone'
head.rotation_euler.z=0
bpy.context.view_layer.update()

# Back view checks the finished rear surfaces and armor coverage.
scene=bpy.context.scene
scene.camera.location=(-3.5,7,3)
scene.camera.rotation_euler=(Vector((0,0,1.18))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=840
scene.render.resolution_y=980
scene.cycles.samples=24
scene.render.filepath=str(OUT/'blackguard-back-preview.png')
bpy.ops.render.render(write_still=True)

# A fresh import catches missing skins, materials, incorrect transforms and stage leaks.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'blackguard.glb'))
armatures=[obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE']
# Blender creates an Icosphere helper for bone display when importing glTF skins.
bone_shapes={bone.custom_shape for arm in armatures for bone in arm.pose.bones if bone.custom_shape}
imports=[obj for obj in bpy.context.scene.objects if obj.type=='MESH' and obj not in bone_shapes]
raw=(OUT/'blackguard.glb').read_bytes()
chunk_size=struct.unpack_from('<I',raw,12)[0]
gltf=json.loads(raw[20:20+chunk_size])
assert len(gltf['meshes'])==1
assert len(imports)==1, len(imports)
assert len(armatures)==1
assert len(armatures[0].data.bones)==18
assert all(obj.type in ('MESH','ARMATURE','EMPTY') for obj in bpy.context.scene.objects)
obj=imports[0]
assert obj.data.uv_layers
assert any(mod.type=='ARMATURE' for mod in obj.modifiers)
assert all(vertex.groups and abs(sum(g.weight for g in vertex.groups)-1)<.0001 for vertex in obj.data.vertices)
assert all(math.isfinite(c) for vertex in obj.data.vertices for c in vertex.co)
obj.data.calc_loop_triangles()
assert len(obj.data.loop_triangles)==source_triangles
imported_bounds=bounds(imports)
assert all(abs(a-b)<.0001 for source,export in zip(source_bounds,imported_bounds) for a,b in zip(source,export)), (source_bounds,imported_bounds)
report={'blender_file_reopened':True,'packed_concept_reference':True,'all_meshes_uv_mapped':True,
        'head_pose_verified':True,'glb_reimported':True,'glb_meshes':len(imports),
        'glb_bones':len(armatures[0].data.bones),'glb_materials':len(obj.data.materials),
        'triangles':source_triangles,'all_vertices_weighted':True,'roundtrip_bounds_match':True,
        'studio_excluded_from_glb':True}
(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('BLACKGUARD_VERIFIED',json.dumps(report))
