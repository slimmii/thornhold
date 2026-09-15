"""Shared low-poly modeling helpers, derived from the Blackguard builder.
Blender Python module used by the Ash Hound and Horned Sentinel builders.
"""
import bpy
import math
import json
import random
import sys
from pathlib import Path
from mathutils import Vector

parts = None
stage = None
bindings = {}

def material(name, color, metallic=0, roughness=.5, emission=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    rgb = tuple(((int(color[i:i+2], 16) / 255 + .055) / 1.055) ** 2.4
                if int(color[i:i+2], 16) / 255 > .04045
                else int(color[i:i+2], 16) / 255 / 12.92 for i in (0, 2, 4))
    m.diffuse_color = (*rgb, 1)
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*rgb, 1)
        bsdf.inputs['Emission Strength'].default_value = emission
    return m


steel = material('Armor | blue charcoal steel', '424e60', .82, .38)
steel_lite = material('Armor | lighter planes', '4d5b6b', .82, .4)
steel_dark = material('Armor | shadow planes', '303949', .78, .46)
bronze = material('Trim | aged bronze', 'a9956c', .78, .36)
bronze_dark = material('Trim | dark bronze', '756246', .8, .43)
black = material('Joints | black leather', '161b24', .12, .76)
cloth = material('Tabard | oxblood cloth', '572637', 0, .92)
cloth_lite = material('Tabard | raised folds', '713447', 0, .9)
cloth_dark = material('Tabard | fold shadows', '421f2b', 0, .96)
shield_red = material('Shield | burgundy lacquer', '562b3c', .25, .46)
shield_red_lite = material('Shield | alternate facets', '633246', .25, .48)
edge = material('Blade | honed steel', 'b4c3cb', .94, .25)
blade_mat = material('Blade | blue steel', '788b9d', .9, .33)
eyes = material('Eyes | ember glow', 'ff4926', .15, .26, 5)
eye_core = material('Eyes | hot cores', 'ffb26b', 0, .3, 7)


def place_in(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)


def bind(obj, bone):
    if bone:
        bindings[obj.name] = bone
    return obj


def mesh(name, verts, faces, mat, bone=None, bevel=0):
    data = bpy.data.meshes.new(name + ' mesh')
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    parts.objects.link(obj)
    obj.data.materials.append(mat)
    bind(obj, bone)
    if bevel:
        mod = obj.modifiers.new('Small forged edge bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
    return obj


def box(name, loc, size, mat, bone=None, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bind(obj, bone)
    if bevel:
        mod = obj.modifiers.new('Forged bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
    return obj


def ellipsoid(name, loc, scale, mat, bone=None, segments=10, rings=5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                      radius=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bind(obj, bone)
    return obj


def cylinder_between(name, a, b, radius, mat, bone=None, radius_end=None, sides=10):
    direction = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius,
                                    radius2=radius if radius_end is None else radius_end,
                                    depth=direction.length,
                                    location=(Vector(a) + Vector(b)) * .5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = direction.to_track_quat('Z', 'Y')
    obj.data.materials.append(mat)
    bind(obj, bone)
    return obj


def loft(name, sections, mat, bone=None, sides=10, bevel=0, facet=False):
    # Each elliptical section is (z, center_x, center_y, radius_x, radius_y).
    verts = []
    for z, x, y, rx, ry in sections:
        for i in range(sides):
            angle = 2 * math.pi * i / sides
            verts.append((x + math.sin(angle) * rx, y - math.cos(angle) * ry, z))
    faces = [tuple(reversed(range(sides)))]
    for j in range(len(sections)-1):
        for i in range(sides):
            a, b = j*sides+i, j*sides+(i+1)%sides
            c, d = b+sides, a+sides
            if facet and (j+i)%3 == 0:
                faces.extend([(a,b,c), (a,c,d)])
            else:
                faces.append((a,b,c,d))
    faces.append(tuple(range((len(sections)-1)*sides, len(sections)*sides)))
    obj = mesh(name, verts, faces, mat, bone, bevel)
    if facet:
        obj.data.materials.append(steel_lite)
        obj.data.materials.append(steel_dark)
        for face in obj.data.polygons:
            face.material_index = random.choices([0,1,2], [.78,.16,.06])[0]
    return obj


def panel(name, coords, depth, mat, bone=None, bevel=.002):
    # Front-facing outline; volume extrudes toward +Y.
    n = len(coords)
    verts = list(coords) + [(x,y+depth,z) for x,y,z in coords]
    faces = [tuple(reversed(range(n))), tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name, verts, faces, mat, bone, bevel)


def strip(name, points, radius, mat, bone):
    for i in range(len(points)-1):
        cylinder_between(f'{name} {i+1:02}', points[i], points[i+1], radius, mat, bone, sides=6)


def rivet(name, loc, radius=.012, bone='chest', mat=None):
    return ellipsoid(name, loc, (radius,radius*.55,radius), mat or bronze, bone, 8, 4)


def front_plate(name, outline, y, mat, bone, rim=.012):
    coords = [(x,y,z) for x,z in outline]
    obj = panel(name, coords, .045, mat, bone, .006)
    strip(name+' bronze seam', coords+[coords[0]], rim, bronze, bone)
    return obj


def setup(slug, title):
    global parts, stage, bindings, OUT, SLUG, TITLE
    SLUG, TITLE = slug, title
    OUT = Path(__file__).resolve().parent / (slug+'-model')
    OUT.mkdir(exist_ok=True)
    random.seed(15)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    parts=bpy.data.collections.new(title.upper()+' | Character')
    stage=bpy.data.collections.new('STUDIO | Excluded from GLB')
    bpy.context.scene.collection.children.link(parts)
    bpy.context.scene.collection.children.link(stage)
    bpy.context.view_layer.active_layer_collection=bpy.context.view_layer.layer_collection.children[parts.name]
    bindings={}
    return OUT


def facets(obj, lighter, darker, amounts=(.84,.11,.05)):
    obj.data.materials.append(lighter)
    obj.data.materials.append(darker)
    for face in obj.data.polygons:
        face.material_index=random.choices([0,1,2],amounts)[0]
    return obj


def tube(name, sections, mat, bone, sides=10, alternate=None):
    """Continuous curved tube. Sections are ((x,y,z), radius_u, radius_v).
    A zero-radius final section becomes a single tip vertex.
    """
    verts=[]
    centers=[Vector(s[0]) for s in sections]
    tipped=sections[-1][1]==0
    rings=sections[:-1] if tipped else sections
    for i,(center,ru,rv) in enumerate(rings):
        tangent=(centers[min(i+1,len(centers)-1)]-centers[max(i-1,0)]).normalized()
        ref=Vector((1,0,0)) if abs(tangent.x)<.85 else Vector((0,1,0))
        u=(ref-tangent*ref.dot(tangent)).normalized()
        v=tangent.cross(u).normalized()
        for j in range(sides):
            angle=2*math.pi*j/sides
            verts.append(tuple(Vector(center)+u*math.cos(angle)*ru+v*math.sin(angle)*rv))
    faces=[tuple(reversed(range(sides)))]
    for i in range(len(rings)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides
            if (i+j)%4==1 and alternate:
                faces.extend([(a,b,b+sides),(a,b+sides,a+sides)])
            else:
                faces.append((a,b,b+sides,a+sides))
    last=(len(rings)-1)*sides
    if tipped:
        tip=len(verts)
        verts.append(tuple(centers[-1]))
        faces.extend((last+j,last+(j+1)%sides,tip) for j in range(sides))
    else:
        faces.append(tuple(range(last,last+sides)))
    obj=mesh(name,verts,faces,mat,bone)
    if alternate:
        facets(obj,*alternate)
    return obj


def yloft(name, sections, mat, bone, sides=12, alternate=None):
    # (y, center_x, center_z, horizontal_radius, vertical_radius)
    return tube(name,[((x,y,z),rx,rz) for y,x,z,rx,rz in sections],mat,bone,sides,alternate)


def blend_axis(value, stops):
    """Linear normalized weights between sorted (coordinate,bone) stops."""
    if value<=stops[0][0]:
        return {stops[0][1]:1.0}
    for (a,bone_a),(b,bone_b) in zip(stops,stops[1:]):
        if value<=b:
            if bone_a==bone_b:
                return {bone_a:1.0}
            t=(value-a)/(b-a)
            return {bone_a:1-t,bone_b:t}
    return {stops[-1][1]:1.0}


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def finish(bone_specs, camera, target, ortho, resolution=(1200,1400), pose_object=None,
           landmarks=None, back_camera=None):
    """Finalize UVs/weights; save editable source, single-mesh GLB and previews."""
    for obj in list(parts.objects):
        if obj.type!='MESH':
            continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=.000001)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02)
        bpy.ops.object.mode_set(mode='OBJECT')
    arm_data=bpy.data.armatures.new(TITLE+' | skeleton')
    rig=bpy.data.objects.new(TITLE.replace(' ','_')+'_Rig',arm_data)
    parts.objects.link(rig)
    rig.show_in_front=True
    rig.display_type='WIRE'
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name,(head,tail,parent) in bone_specs.items():
        bone=arm_data.edit_bones.new(name)
        bone.head=head; bone.tail=tail
        if parent:
            bone.parent=arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj_name,binding in bindings.items():
        obj=bpy.data.objects[obj_name]
        if isinstance(binding,str):
            group=obj.vertex_groups.new(name=binding)
            group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        else:
            for vertex in obj.data.vertices:
                weights=binding(obj.matrix_world@vertex.co)
                assert abs(sum(weights.values())-1.0)<.00001, (obj.name,vertex.index,weights)
                for bone,weight in weights.items():
                    if weight>0.00001:
                        group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                        group.add([vertex.index],weight,'REPLACE')
        mod=obj.modifiers.new(TITLE+' posing rig','ARMATURE')
        mod.object=rig
        obj.parent=rig
    rig['description']='Basic posing rig: blended creature body weights, rigid armor and accessories. No animation clips or IK.'
    rig['forward']='Blender -Y, exported glTF +Z using standard Y-up conversion'
    rig['units']='metres'
    scene=bpy.context.scene
    scene.unit_settings.system='METRIC'
    scene.unit_settings.scale_length=1
    floor=material('Studio | slate','182830',.12,.65)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.018))
    ground=bpy.context.object
    ground.name='STUDIO | ground'
    ground.data.materials.append(floor)
    place_in(ground,stage)
    world=bpy.data.worlds.new('Studio | blue-gray world')
    scene.world=world
    world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.16,.22,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
    light_scale=max(1,ortho/2.91)
    for name,loc,power,color,size in [
        ('warm key',(-3,-4,5),650,(1,.85,.69),4),
        ('cool fill',(3,-2,3.3),420,(.67,.81,1),3),
        ('teal rim',(-2,2,3.3),850,(.37,.83,.86),2.2),
        ('upper softbox',(1,1,5.4),650,(1,.89,.72),2.6)]:
        data=bpy.data.lights.new('STUDIO | '+name,'AREA')
        data.energy=power*light_scale**2
        data.color=color; data.shape='DISK'; data.size=size*light_scale
        obj=bpy.data.objects.new(data.name,data)
        stage.objects.link(obj)
        obj.location=Vector(loc)*light_scale
        aim(obj,target)
    data=bpy.data.cameras.new(TITLE+' portrait camera')
    cam=bpy.data.objects.new('STUDIO | camera',data)
    stage.objects.link(cam)
    cam.location=camera
    aim(cam,target)
    data.type='ORTHO'; data.ortho_scale=ortho
    scene.camera=cam
    scene.render.engine='CYCLES'
    scene.cycles.device='CPU'; scene.cycles.samples=40; scene.cycles.use_denoising=True
    scene.render.resolution_x,scene.render.resolution_y=resolution
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='AgX'
    scene.render.filepath=str(OUT/(SLUG+'-preview.png'))
    ref=OUT.parent/(SLUG+'.png')
    im=bpy.data.images.load(str(ref),check_existing=True)
    im.name='REFERENCE | '+TITLE+' concept'
    im.use_fake_user=True
    im.pack()
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active
                space.region_3d.view_distance=ortho*1.3
                space.region_3d.view_location=target
                space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
                space.shading.type='MATERIAL'
                space.overlay.show_floor=False
                space.overlay.show_extras=False
    temp=bpy.data.collections.new('TEMP | Joined export')
    scene.collection.children.link(temp)
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for obj in parts.objects:
        if obj.type=='MESH':
            duplicate=obj.copy(); duplicate.data=obj.data.copy()
            temp.objects.link(duplicate)
            duplicate.select_set(True)
            copies.append(duplicate)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.join()
    combined=bpy.context.object
    combined.name=TITLE+' | skinned game mesh'
    rig.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(SLUG+'.glb')),export_format='GLB',use_selection=True,
          export_apply=False,export_animations=False,export_yup=True,export_skins=True,export_all_influences=False)
    bpy.data.objects.remove(combined,do_unlink=True)
    bpy.data.collections.remove(temp)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True); bpy.context.view_layer.objects.active=rig
    meshes=[o for o in parts.objects if o.type=='MESH']
    for obj in meshes:
        obj.data.calc_loop_triangles()
    bounds=[obj.matrix_world@v.co for obj in meshes for v in obj.data.vertices]
    stats={'name':TITLE,'slug':SLUG,'rig':rig.name,'collection':parts.name,'mesh_objects':len(meshes),
      'vertices':sum(len(o.data.vertices) for o in meshes),
      'triangles':sum(len(o.data.loop_triangles) for o in meshes),'bones':len(arm_data.bones),
      'materials':len({m.name for o in meshes for m in o.data.materials}),
      'dimensions_metres':[round(max(v[i] for v in bounds)-min(v[i] for v in bounds),3) for i in range(3)],
      'uv_mapped':all(bool(o.data.uv_layers) for o in meshes),'glb_mesh_objects':1,
      'rig_type':rig['description'],'pose_check_object':pose_object,
      'landmarks':landmarks or {},'back_camera':back_camera or [-camera[0],-camera[1],camera[2]],
      'camera_target':list(target),'source':'Original low-poly geometry based on packed enemy concept'}
    (OUT/'model-info.json').write_text(json.dumps(stats,indent=2)+'\n')
    scene['asset']='Thornhold '+TITLE
    scene['notes']='Character exports to GLB; studio is presentation only. Packed concept in Image Editor.'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(SLUG+'.blend')))
    if '--skip-render' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    print('MODEL_COMPLETE',json.dumps(stats))
