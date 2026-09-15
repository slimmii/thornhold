"""Verify generated creature files and render their rear views using Blender.

blender --background --factory-startup --python-exit-code 1 \
  --python assets/enemies/verify_creature_models.py -- ash-hound horned-sentinel
"""
import bpy
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent


def bounds(objects):
    vertices=[obj.matrix_world@v.co for obj in objects for v in obj.data.vertices]
    return [[min(v[i] for v in vertices) for i in range(3)],
            [max(v[i] for v in vertices) for i in range(3)]]


def triangles(objects):
    total=0
    for obj in objects:
        obj.data.calc_loop_triangles()
        total+=len(obj.data.loop_triangles)
    return total


def evaluated_positions(obj):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [evaluated.matrix_world@v.co for v in evaluated.data.vertices]


def verify(slug):
    folder=ROOT/(slug+'-model')
    info=json.loads((folder/'model-info.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(folder/(slug+'.blend')))
    rig=bpy.data.objects[info['rig']]
    meshes=[o for o in bpy.data.collections[info['collection']].objects if o.type=='MESH']
    assert len(rig.data.bones)==info['bones']
    assert len(meshes)==info['mesh_objects']
    assert all(o.data.uv_layers for o in meshes)
    assert all(any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers) for o in meshes)
    assert bpy.data.images['REFERENCE | '+info['name']+' concept'].packed_file
    assert all(v.groups and abs(sum(g.weight for g in v.groups)-1)<.0001 for o in meshes for v in o.data.vertices)
    for landmark,rule in info['landmarks'].items():
        selected=[o for o in meshes if o.name.startswith(rule.get('prefix',''))
                  and o.name.endswith(rule.get('suffix',''))]
        assert len(selected)==rule['count'], (landmark,[o.name for o in selected])
    source_bounds=bounds(meshes)
    source_triangles=triangles(meshes)
    assert source_triangles==info['triangles']

    # Test actual deformation instead of only the existence of a rig modifier.
    head=rig.pose.bones['head']
    target=bpy.data.objects[info['pose_check_object']]
    before=evaluated_positions(target)
    head.rotation_mode='XYZ'; head.rotation_euler.z=.25
    bpy.context.view_layer.update()
    after=evaluated_positions(target)
    # A vertex lying on the rotation axis may correctly remain stationary.
    displacement=max((a-b).length for a,b in zip(after,before))
    assert displacement>.02, ('Head mesh does not follow posing rig',displacement)
    head.rotation_euler.z=0
    bpy.context.view_layer.update()
    scene=bpy.context.scene
    scene.camera.location=info['back_camera']
    scene.camera.rotation_euler=(Vector(info['camera_target'])-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_percentage=70
    scene.cycles.samples=24
    scene.render.filepath=str(folder/(slug+'-back-preview.png'))
    bpy.ops.render.render(write_still=True)

    raw=(folder/(slug+'.glb')).read_bytes()
    assert raw[:4]==b'glTF'
    gltf=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
    assert len(gltf['meshes'])==1
    assert len(gltf['skins'])==1
    assert len(gltf['skins'][0]['joints'])==info['bones']
    assert not gltf.get('animations')
    assert not gltf.get('cameras')
    assert any(max(material.get('emissiveFactor',[0,0,0]))>0 for material in gltf['materials'])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(folder/(slug+'.glb')))
    rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    shapes={b.custom_shape for r in rigs for b in r.pose.bones if b.custom_shape}
    imported=[o for o in bpy.context.scene.objects if o.type=='MESH' and o not in shapes]
    assert len(imported)==1
    assert len(rigs)==1 and len(rigs[0].data.bones)==info['bones']
    assert imported[0].data.uv_layers
    assert any(m.type=='ARMATURE' for m in imported[0].modifiers)
    assert all(v.groups and abs(sum(g.weight for g in v.groups)-1)<.0001 for v in imported[0].data.vertices)
    assert all(math.isfinite(c) for v in imported[0].data.vertices for c in v.co)
    assert triangles(imported)==source_triangles
    assert all(abs(a-b)<.0001 for source,dest in zip(source_bounds,bounds(imported)) for a,b in zip(source,dest))
    assert all(o.type in ('MESH','ARMATURE','EMPTY') for o in bpy.context.scene.objects)
    report={'blender_file_reopened':True,'packed_concept_reference':True,'all_meshes_uv_mapped':True,
      'head_pose_verified':True,'anatomical_landmarks_verified':True,'glb_reimported':True,
      'glb_meshes':1,'glb_bones':info['bones'],'glb_materials':len(imported[0].data.materials),
      'triangles':source_triangles,'all_vertices_weighted':True,'roundtrip_bounds_match':True,
      'emissive_materials_exported':True,'studio_excluded_from_glb':True}
    (folder/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('MODEL_VERIFIED',slug,json.dumps(report))


slugs=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['ash-hound','horned-sentinel']
for slug in slugs:
    verify(slug)
