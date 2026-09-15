"""Build the Thornhold Blackguard. Run with Blender --background --python this_file.

Original mesh construction from the Blackguard concept; no downloaded assets.
Blender coordinates: Z up, character faces -Y. One Blender unit is one metre.
"""
import bpy
import math
import json
import random
from pathlib import Path
from mathutils import Vector, Quaternion

OUT = Path(__file__).resolve().parent
random.seed(14)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name != 'Collection':
        bpy.data.collections.remove(collection)
parts = bpy.data.collections.get('Collection')
parts.name = 'BLACKGUARD | Character'
stage = bpy.data.collections.new('STUDIO | Excluded from GLB')
bpy.context.scene.collection.children.link(stage)
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


def rivet(name, loc, radius=.012, bone='chest', mat=bronze):
    return ellipsoid(name, loc, (radius,radius*.55,radius), mat, bone, 8, 4)


def front_plate(name, outline, y, mat, bone, rim=.012):
    coords = [(x,y,z) for x,z in outline]
    obj = panel(name, coords, .045, mat, bone, .006)
    strip(name+' bronze seam', coords+[coords[0]], rim, bronze, bone)
    return obj


# The neck opening, breastplate, narrow waist and segmented skirt.
loft('Gambeson | torso beneath plates', [(1.02,0,.035,.245,.16),(1.5,0,.025,.33,.19),
     (1.79,0,.025,.27,.16)], black, 'chest', 12)
loft('Cuirass | faceted breast and back', [(1.1,0,0,.255,.175),(1.28,0,0,.29,.21),
     (1.57,0,.015,.37,.225),(1.73,0,.015,.33,.2),(1.82,0,.025,.225,.155)],
     steel,'chest',12,.006,True)
loft('Cuirass | bottom bronze welt',[(1.09,0,0,.258,.177),(1.118,0,0,.263,.18)],bronze,'chest',12)
cylinder_between('Neck | dark flexible collar',(0,0,1.76),(0,0,1.97),.128,black,'head',sides=12)
loft('Gorget | steel collar',[(1.715,0,-.01,.25,.186),(1.765,0,0,.245,.186),
      (1.87,0,.025,.17,.14)],steel,'chest',12,.004)
loft('Gorget | bronze lip',[(1.852,0,.025,.18,.149),(1.879,0,.025,.179,.149)],bronze,'chest',12)
front_plate('Gorget | pointed front', [(-.225,1.79),(-.19,1.7),(0,1.655),(.19,1.7),(.225,1.79)],
            -.197,steel,'chest',.009)

# Sculpted cloth strips with real folds, front and back.
def tabard(name, rows, back=False):
    verts=[]
    for index,(z,w,y) in enumerate(rows):
        tip = 'hanging' in name and index == len(rows)-1
        verts += [(-w,y,z),(-w*.56,y-.006,z-.05 if tip else z),
                  (0,y-.022,z-.105 if tip else z-.012),
                  (w*.56,y-.005,z-.05 if tip else z),(w,y,z)]
    faces=[]
    for j in range(len(rows)-1):
        for i in range(4):
            a=j*5+i
            faces.append((a,a+1,a+6,a+5))
    obj=mesh(name,verts,faces,cloth,'chest' if 'chest' in name else 'pelvis')
    obj.data.materials.append(cloth_lite)
    obj.data.materials.append(cloth_dark)
    for i,p in enumerate(obj.data.polygons):
        p.material_index=[2,0,1,0][i%4]
    solid=obj.modifiers.new('Fabric thickness','SOLIDIFY')
    solid.thickness=.009
    return obj

tabard('Tabard | chest folds',[(1.68,.105,-.218),(1.49,.098,-.22),(1.28,.093,-.207),(1.1,.105,-.181)])
tabard('Tabard | hanging pointed front',[(1.08,.11,-.19),(.92,.13,-.213),(.63,.16,-.255),(.51,.16,-.262)])
strip('Tabard | narrow hem',[(-.11,-.193,1.08),(-.13,-.216,.92),(-.16,-.265,.51),(0,-.278,.405),
      (.16,-.265,.51),(.13,-.216,.92),(.11,-.193,1.08)],.0045,bronze_dark,'pelvis')
tabard('Tabard | rear cloth',[(1.08,.13,.19),(.84,.155,.21),(.56,.17,.25)],True)

loft('Belt | heavy dark leather',[(1.05,0,0,.28,.195),(1.135,0,0,.277,.2)],black,'pelvis',12,.005)
for height in (1.05,1.135):
    loft('Belt | piping '+str(height),[(height,0,0,.281,.197),(height+.009,0,0,.281,.197)],bronze_dark,'pelvis',12)
front_plate('Belt | buckle',[(-.053,1.135),(.033,1.135),(.055,1.115),(.055,1.064),(.031,1.045),
                           (-.034,1.045),(-.055,1.066),(-.055,1.114)],-.217,bronze,'pelvis',.004)
box('Belt | buckle inset',(0,-.244,1.091),(.062,.012,.057),black,'pelvis',.004)
for x in [-.20,-.13,.13,.2]:
    rivet('Belt | stud', (x,-.188,1.09),.01,'pelvis',bronze_dark)

# Helm built from separate upper/lower closed shells, with an actual open eye slit.
loft('Helm | lower face shell',[(1.935,0,0,.178,.167),(2.075,0,.004,.17,.158),
                             (2.096,0,.006,.168,.156)],steel,'head',12,.002,True)
loft('Helm | brow and crown',[(2.122,0,.007,.167,.156),(2.26,0,.011,.155,.148),
                            (2.295,0,.014,.14,.13),(2.322,0,.012,.025,.025)],steel,'head',12,.002,True)
loft('Helm | recessed black interior',[(2.04,0,.022,.15,.13),(2.2,0,.023,.148,.129)],black,'head',12)
loft('Helm | lower bronze rim',[(1.932,0,0,.18,.169),(1.951,0,0,.18,.169)],bronze,'head',12)
for z in [2.095,2.123]:
    coords=[]
    for a in [-math.pi/2,-math.pi/3,-math.pi/6,0,math.pi/6,math.pi/3,math.pi/2]:
        coords.append((math.sin(a)*.169,.006-math.cos(a)*.158,z))
    strip('Helm | slit rim',coords,.0045,bronze_dark,'head')
panel('Helm | bronze nasal',[(-.014,-.174,1.945),(.014,-.174,1.945),(.014,-.153,2.285),
      (-.014,-.153,2.285)],.012,bronze,'head',.002)
for s in [-1,1]:
    ellipsoid('Eye | ember '+str(s),(s*.063,-.133,2.109),(.016,.006,.009),eyes,'head',12,6)
    ellipsoid('Eye | hot pupil '+str(s),(s*.063,-.139,2.109),(.004,.002,.004),eye_core,'head',10,5)
    for x,z in [(.043,1.967),(.043,2.063),(.041,2.157),(.126,1.971),(.122,2.158)]:
        y=-math.sqrt(max(0,1-(x/.18)**2))*.17-.002
        rivet('Helm | fastening',(s*x,y,z),.0055,'head',bronze_dark)
    # Low-key breathing slots are separate inset-looking dark plates.
    for i in range(3):
        x=s*(.05+i*.028)
        y=-math.sqrt(max(0,1-(x/.18)**2))*.169-.002
        vent=box('Helm | breathing vent',(x,y,2.017),(.008,.003,.023),black,'head',.002)
        vent.rotation_euler.z=-s*(.15+i*.10)

# Back seam establishes a finished rear view.
box('Cuirass | rear central ridge',(0,.222,1.52),(.035,.023,.40),steel_lite,'chest',.009)
for z in [1.35,1.51,1.67]:
    ellipsoid('Back | bronze rivet',(0,.24,z),(.009,.004,.009),bronze_dark,'chest',8,4)

# Legs: overlapping thigh lames, shaped knee cops, greaves and articulated sabatons.
for s,label in [(-1,'R'),(1,'L')]:
    thigh, shin, foot = 'thigh.'+label, 'shin.'+label, 'foot.'+label
    x=s*.22
    cylinder_between('Leg '+label+' | underlayer',(s*.15,0,1.03),(x,.006,.26),.098,black,thigh,sides=10)
    loft('Leg '+label+' | thigh plate',[(.58,x,.014,.137,.127),(.87,s*.185,.012,.16,.151),
         (1.01,s*.153,0,.154,.145)],steel,thigh,10,.005,True)
    for i in range(2):
        z=.86+i*.135
        loft('Tasset '+label+' | overlapping skirt '+str(i),[(z-.075,s*.18,0,.204,.18),
             (z+.075,s*.168,0,.168,.16)],steel,'pelvis',10,.004,True)
        loft('Tasset '+label+' | bronze edge '+str(i),[(z-.085,s*.18,0,.207,.183),
             (z-.067,s*.18,0,.207,.183)],bronze,'pelvis',10)
    ellipsoid('Knee '+label+' | flexible joint',(x,-.01,.575),(.125,.13,.11),black,shin)
    outline=[(x-.12,.625),(x-.135,.57),(x-.09,.497),(x,.465),(x+.09,.497),(x+.135,.57),(x+.12,.625),(x,.669)]
    front_plate('Knee '+label+' | octagonal cop',outline,-.128,steel,shin,.008)
    ellipsoid('Knee '+label+' | raised central facet',(x,-.157,.572),(.108,.05,.083),steel_lite,shin,8,4)
    loft('Greave '+label+' | shaped shin',[(.15,x,.005,.093,.092),(.25,x,.017,.113,.106),
         (.45,x,.016,.126,.116),(.501,x,0,.105,.109)],steel,shin,10,.004,True)
    strip('Greave '+label+' | central ridge',[(x,-.092,.17),(x,-.106,.29),(x,-.105,.46)],.007,steel_lite,shin)
    loft('Greave '+label+' | ankle rim',[(.153,x,.005,.099,.097),(.177,x,.005,.102,.10)],bronze,shin,10)
    loft('Boot '+label+' | faceted sabaton',[(.015,x,-.094,.123,.224),(.05,x,-.098,.126,.23),
         (.12,x,-.087,.119,.21),(.19,x,-.034,.086,.135)],steel,foot,10,.004,True)
    loft('Boot '+label+' | dark sole',[(.009,x,-.094,.125,.225),(.034,x,-.096,.126,.229)],black,foot,10)
    for i in range(3):
        y=-.08-i*.059
        z=.178-i*.025
        strip('Boot '+label+' | articulated seam '+str(i),[(x-.094,y,z-.017),(x,y-.01,z),(x+.094,y,z-.017)],
              .006,steel_lite,foot)
    for z in [.3,.425]:
        box('Greave '+label+' | rear strap',(x,.123,z),(.16,.021,.026),black,shin,.003)

# Broad layered shoulders and full plate arms in a relaxed combat-ready pose.
hands={}
for s,label in [(-1,'R'),(1,'L')]:
    upper='upper_arm.'+label
    fore='forearm.'+label
    hand='hand.'+label
    shoulder=Vector((s*.385,.01,1.727))
    elbow=Vector((s*.55,-.018,1.405))
    wrist=Vector((s*.66,-.104,1.129))
    palm=Vector((s*.682,-.135,1.065))
    hands[label]=palm
    ellipsoid('Shoulder '+label+' | joint',shoulder,(.137,.135,.145),black,upper)
    cylinder_between('Arm '+label+' | upper sleeve',shoulder,elbow,.112,black,upper,sides=10)
    loft('Pauldron '+label+' | main layered shell',[(1.607,s*.439,.017,.202,.2),
         (1.733,s*.424,.025,.197,.19),(1.843,s*.373,.031,.13,.151),
         (1.867,s*.363,.037,.034,.082)],steel,upper,10,.006,True)
    loft('Pauldron '+label+' | bronze perimeter',[(1.602,s*.439,.017,.205,.203),
         (1.626,s*.436,.018,.206,.204)],bronze,upper,10)
    for i in range(2):
        z=1.50-i*.105
        cx=s*(.481+i*.037)
        loft('Arm '+label+' | shoulder lame '+str(i),[(z-.041,cx,0,.154,.164),
             (z+.075,cx-s*.018,.013,.159,.159)],steel,upper,10,.005,True)
        loft('Arm '+label+' | lame bronze lip '+str(i),[(z-.045,cx,0,.157,.167),
             (z-.03,cx,0,.157,.167)],bronze_dark,upper,10)
    rivet('Pauldron '+label+' | round clasp',(s*.272,-.161,1.752),.044,upper)
    rivet('Pauldron '+label+' | clasp center',(s*.272,-.186,1.752),.029,upper,bronze_dark)
    ellipsoid('Elbow '+label+' | couter',elbow,(.125,.134,.105),steel,fore,10,5)
    cylinder_between('Arm '+label+' | elbow gap',elbow,wrist,.074,black,fore,sides=10)
    direction=(wrist-elbow).normalized()
    cylinder_between('Vambrace '+label+' | steel shell',elbow+direction*.062,wrist,.115,steel,fore,.084,8)
    for t,r in [(.23,.12),(.96,.092)]:
        center=elbow.lerp(wrist,t)
        cylinder_between('Vambrace '+label+' | bronze cuff',center-direction*.011,center+direction*.011,r,bronze,fore,sides=8)
    ellipsoid('Hand '+label+' | leather grip',palm,(.075,.076,.09),black,hand,10,5)
    front_plate('Gauntlet '+label+' | hand plate',[(palm.x-.063,palm.z+.065),(palm.x+.061,palm.z+.064),
        (palm.x+.067,palm.z-.024),(palm.x+.034,palm.z-.053),(palm.x-.06,palm.z-.043)],
        palm.y-.066,steel,hand,.005)
    for i in range(4):
        xx=palm.x+(i-1.5)*.031
        ellipsoid('Gauntlet '+label+' | knuckle '+str(i),(xx,palm.y-.071,palm.z-.041),
                  (.019,.027,.024),steel_lite,hand,8,4)
        finger=box('Gauntlet '+label+' | finger '+str(i),(xx,palm.y-.013,palm.z-.074),
                   (.027,.095,.03),steel,hand,.006)
    ellipsoid('Gauntlet '+label+' | thumb',(palm.x-s*.071,palm.y-.023,palm.z-.007),
              (.027,.06,.038),steel,hand,8,4)

# Single-handed sword, separate meshes bound to a dedicated weapon bone.
sword_palm=hands['R']
blade_direction=Vector((-.55,-.09,-.83)).normalized()
blade_width=Vector((.83,0,-.55)).normalized()
blade_thickness=blade_direction.cross(blade_width).normalized()
guard=sword_palm+blade_direction*.115
cylinder_between('Sword | leather-bound grip',sword_palm-blade_direction*.095,guard-blade_direction*.024,
                 .025,black,'weapon.R',sides=10)
for i in range(7):
    p=sword_palm+blade_direction*(-.087+i*.023)
    cylinder_between('Sword | grip winding '+str(i),p,p+blade_direction*.008,.027,bronze_dark,'weapon.R',sides=10)
pommel=sword_palm-blade_direction*.12
ellipsoid('Sword | faceted pommel',pommel,(.044,.033,.044),bronze,'weapon.R',8,4)
g=box('Sword | crossguard',guard,(.32,.055,.053),bronze,'weapon.R',.012)
g.rotation_euler.y=math.atan2(-blade_width.z,blade_width.x)
for sign in [-1,1]:
    ellipsoid('Sword | guard end',guard+blade_width*.158*sign,(.035,.034,.035),bronze_dark,'weapon.R',6,4)
start=guard+blade_direction*.029
verts=[]
for distance,width in [(0,.052),(.11,.053),(.72,.036)]:
    p=start+blade_direction*distance
    verts += [tuple(p-blade_width*width),tuple(p+blade_thickness*.013),
              tuple(p+blade_width*width),tuple(p-blade_thickness*.013)]
faces=[(3,2,1,0)]
for k in range(2):
    for i in range(4):
        faces.append((k*4+i,k*4+(i+1)%4,(k+1)*4+(i+1)%4,(k+1)*4+i))
verts.append(tuple(start+blade_direction*.91))
faces += [(8+i,8+(i+1)%4,12) for i in range(4)]
blade=mesh('Sword | tapered diamond-section blade',verts,faces,blade_mat,'weapon.R')
blade.data.materials.append(edge)
for p in blade.data.polygons:
    if p.index%4 in (0,1):
        p.material_index=1

# Thick six-sided shield with a shallow central ridge, metal border and rear straps.
shield_center=Vector((.726,-.332,1.183))
shield_outline=[(0,.565),(.344,.342),(.323,-.22),(0,-.575),(-.323,-.22),(-.344,.342)]
n=len(shield_outline)
outer=[tuple(shield_center+Vector((x,0,z))) for x,z in shield_outline]
inner=[tuple(shield_center+Vector((x*.866,-.027,z*.89))) for x,z in shield_outline]
back=[tuple(shield_center+Vector((x,.069,z))) for x,z in shield_outline]
verts=outer+inner+back
faces=[]
for i in range(n):
    j=(i+1)%n
    faces += [(i,j,j+n,i+n),(i,i+2*n,j+2*n,j)]
faces.append(tuple(range(2*n,3*n)))
mesh('Shield | thick bronze perimeter',verts,faces,bronze,'shield.L',.003)
center=tuple(shield_center+Vector((0,-.08,.006)))
verts=inner+[center]
faces=[(i,(i+1)%n,n) for i in range(n)]
face=mesh('Shield | ridged burgundy face',verts,faces,shield_red,'shield.L')
face.data.materials.append(shield_red_lite)
for i,p in enumerate(face.data.polygons):
    p.material_index=i%2
panel('Shield | vertical bronze device',[(shield_center.x-.019,shield_center.y-.083,shield_center.z-.49),
     (shield_center.x+.019,shield_center.y-.083,shield_center.z-.49),
     (shield_center.x+.023,shield_center.y-.079,shield_center.z+.496),
     (shield_center.x-.023,shield_center.y-.079,shield_center.z+.496)],.016,bronze,'shield.L',.002)
boss=ellipsoid('Shield | central diamond boss',shield_center+Vector((0,-.098,.008)),(.052,.026,.075),bronze,'shield.L',4,3)
for i in range(n):
    a=Vector(outer[i]); b=Vector(outer[(i+1)%n])
    for t in [.2,.65]:
        p=a.lerp(b,t).lerp(shield_center,.055)
        p.y-=.015
        rivet('Shield | border rivet',p,.012,'shield.L',bronze_dark)
panel('Shield | dark wooden rear',[(x,shield_center.y+.066,z) for x,_,z in inner],.014,black,'shield.L')
for z in [1.09,1.32]:
    cylinder_between('Shield | rear leather strap',(.53,-.213,z),(.86,-.213,z),.019,black,'shield.L',sides=8)
cylinder_between('Shield | hand grip',(.66,-.18,1.045),(.66,-.18,1.18),.025,bronze_dark,'shield.L',sides=8)

# Apply constructive modifiers, correct face normals and create portable UV maps.
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
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02)
    bpy.ops.object.mode_set(mode='OBJECT')

# Rigid armor rig: each piece is fully weighted to its anatomical bone.
arm_data=bpy.data.armatures.new('Blackguard | skeleton')
rig=bpy.data.objects.new('Blackguard_Rig',arm_data)
parts.objects.link(rig)
rig.show_in_front=True
rig.display_type='WIRE'
bpy.context.view_layer.objects.active=rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bone_specs={
 'root':((0,0,0),(0,0,.22),None),
 'pelvis':((0,0,.97),(0,0,1.19),'root'),
 'chest':((0,0,1.19),(0,0,1.79),'pelvis'),
 'head':((0,0,1.79),(0,0,2.29),'chest'),
}
for s,label in [(-1,'R'),(1,'L')]:
    bone_specs.update({
      'thigh.'+label:((s*.15,0,1.04),(s*.22,0,.575),'pelvis'),
      'shin.'+label:((s*.22,0,.575),(s*.22,0,.16),'thigh.'+label),
      'foot.'+label:((s*.22,0,.16),(s*.22,-.25,.07),'shin.'+label),
      'upper_arm.'+label:((s*.385,.01,1.727),(s*.55,-.018,1.405),'chest'),
      'forearm.'+label:((s*.55,-.018,1.405),(s*.66,-.104,1.129),'upper_arm.'+label),
      'hand.'+label:((s*.66,-.104,1.129),(s*.682,-.135,1.01),'forearm.'+label),
    })
bone_specs['weapon.R']=(tuple(sword_palm),tuple(sword_palm+blade_direction*.4),'hand.R')
bone_specs['shield.L']=(tuple(hands['L']),tuple(hands['L']+Vector((0,0,.25))),'hand.L')
for name,(head,tail,parent) in bone_specs.items():
    bone=arm_data.edit_bones.new(name)
    bone.head=head
    bone.tail=tail
    if parent:
        bone.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for obj_name,bone in bindings.items():
    obj=bpy.data.objects[obj_name]
    group=obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
    mod=obj.modifiers.new('Blackguard armor rig','ARMATURE')
    mod.object=rig
    obj.parent=rig
rig['description']='Editable rigid armor rig. Rest pose is the reference guard stance. No animation clips.'
rig['forward']='-Y in Blender; -Z in exported glTF/Godot'
rig['units']='metres'

# Display stage stays out of the game export.
floor=material('Studio | slate', '182830',.12,.65)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.018))
ground=bpy.context.object
ground.name='STUDIO | ground'
ground.data.materials.append(floor)
place_in(ground,stage)
world=bpy.data.worlds.new('Studio | blue-gray world')
bpy.context.scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.16,.22,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45


def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def area(name,loc,power,color,size,target=(0,0,1.2)):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.color=color
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    stage.objects.link(obj)
    obj.location=loc
    aim(obj,target)


area('STUDIO | warm key',(-3,-4,5),650,(1,.85,.69),4)
area('STUDIO | cool fill',(3,-2,3.3),420,(.67,.81,1),3)
area('STUDIO | teal rim',(-2,2,3.3),850,(.37,.83,.86),2.2)
area('STUDIO | upper softbox',(1,1,5.4),650,(1,.89,.72),2.6)
cam_data=bpy.data.cameras.new('Blackguard portrait camera')
cam=bpy.data.objects.new('STUDIO | camera',cam_data)
stage.objects.link(cam)
cam.location=(3.5,-7,3.1)
aim(cam,(-.045,0,1.18))
cam_data.type='ORTHO'
cam_data.ortho_scale=2.91
scene=bpy.context.scene
scene.camera=cam
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1200
scene.render.resolution_y=1400
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(OUT/'blackguard-preview.png')

# Pack the completed concept reference in the .blend for convenient comparison.
ref=OUT.parent/'blackguard.png'
if ref.exists():
    im=bpy.data.images.load(str(ref),check_existing=True)
    im.name='REFERENCE | Blackguard concept'
    im.use_fake_user=True
    im.pack()

# Set a clean, framed startup viewport.
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=3.8
            a.spaces.active.region_3d.view_location=(0,0,1.2)
            a.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            a.spaces.active.shading.type='MATERIAL'
            a.spaces.active.overlay.show_floor=False
            a.spaces.active.overlay.show_extras=False

# GLB: one joined skinned mesh, preserving the separate source pieces in Blender.
export_collection=bpy.data.collections.new('TEMP | Export combined mesh')
scene.collection.children.link(export_collection)
bpy.ops.object.select_all(action='DESELECT')
copies=[]
for obj in parts.objects:
    if obj.type=='MESH':
        copy=obj.copy()
        copy.data=obj.data.copy()
        export_collection.objects.link(copy)
        copy.select_set(True)
        copies.append(copy)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
combined=bpy.context.object
combined.name='Blackguard | skinned game mesh'
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'blackguard.glb'),export_format='GLB',use_selection=True,
                          export_apply=False,export_animations=False,export_yup=True,
                          export_skins=True,export_all_influences=False)
bpy.data.objects.remove(combined,do_unlink=True)
bpy.data.collections.remove(export_collection)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
scene['asset']='Thornhold Blackguard'
scene['notes']='Character collection exports to GLB. Studio collection is presentation only. Packed concept image in Image Editor.'
meshes=[o for o in parts.objects if o.type=='MESH']
for obj in meshes:
    obj.data.calc_loop_triangles()
bounds=[obj.matrix_world@Vector(corner) for obj in meshes for corner in obj.bound_box]
stats={'mesh_objects':len(meshes),'vertices':sum(len(o.data.vertices) for o in meshes),
       'triangles':sum(len(o.data.loop_triangles) for o in meshes),'bones':len(arm_data.bones),
       'materials':len({m.name for o in meshes for m in o.data.materials}),
       'height_metres':round(max(v.z for v in bounds)-min(v.z for v in bounds),3),
       'dimensions_metres':[round(max(v[i] for v in bounds)-min(v[i] for v in bounds),3) for i in range(3)],
       'uv_mapped':all(bool(o.data.uv_layers) for o in meshes),
       'rig_type':'Rigid component weights; no animation clips',
       'glb_mesh_objects':1,
       'source':'Original mesh construction based on packed Blackguard concept'}
(OUT/'model-info.json').write_text(json.dumps(stats,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'blackguard.blend'))
bpy.ops.render.render(write_still=True)
print('BLACKGUARD_COMPLETE',json.dumps(stats))
