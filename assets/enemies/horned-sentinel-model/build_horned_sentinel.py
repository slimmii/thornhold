"""Rebuild the Horned Sentinel mesh, rig, Blender file, GLB and render."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import model_tools as m
from mathutils import Vector

m.setup('horned-sentinel','Horned Sentinel')
skin=m.material('Skin | warm stone brown','674a48',.02,.76)
skin_light=m.material('Skin | raised facets','785a54',.02,.73)
skin_dark=m.material('Skin | shadow facets','533d3e',.02,.8)
iron=m.material('Armor | purple charcoal iron','3a3039',.72,.42)
iron_light=m.material('Armor | worn edges','665b63',.76,.4)
iron_dark=m.material('Armor | shadow planes','29272f',.63,.48)
bone=m.material('Horns | aged ivory','cbbb8c',.03,.56)
bone_light=m.material('Horns | pale facets','dfd1a6',.03,.52)
bone_dark=m.material('Horns | darker roots','91835d',.03,.64)
wood=m.material('Axe | aged ashwood','77604b',.02,.68)
wood_dark=m.material('Axe | dark wood grain','594639',.02,.74)
steel=m.material('Axe | forged steel','879398',.87,.34)
steel_edge=m.material('Axe | honed edge','bec8c8',.93,.26)
alt=(skin_light,skin_dark)
metal_alt=(iron_light,iron_dark)

# Heavy tapering torso with broad shoulders and a narrower armored waist.
torso=m.loft('Torso | powerful faceted core',[(1.11,0,0,.34,.245),(1.35,0,0,.39,.26),
    (1.70,0,.012,.475,.30),(2.03,0,.025,.605,.333),(2.22,0,.037,.53,.28),
    (2.36,0,.035,.265,.20)],skin,
    lambda p:m.blend_axis(p.z,[(1.17,'pelvis'),(1.55,'spine'),(1.97,'chest')]),12)
m.facets(torso,*alt)
for s,label in [(-1,'R'),(1,'L')]:
    # Shallow broad pectoral planes merge into the torso at their perimeter.
    outline=[(s*.027,-.281,2.211),(s*.289,-.259,2.219),(s*.509,-.154,2.149),
             (s*.456,-.173,1.944),(s*.09,-.302,1.924),(s*.029,-.302,2.057)]
    verts=outline+[(s*.261,-.362,2.088)]+[(x,y+.12,z) for x,y,z in outline]
    faces=[(i,(i+1)%6,6) for i in range(6)]
    faces += [(i,i+7,(i+1)%6+7,(i+1)%6) for i in range(6)]
    faces.append(tuple(range(7,13)))
    m.facets(m.mesh('Chest '+label+' | broad pectoral',verts,faces,skin,'chest'),*alt)
    m.facets(m.ellipsoid('Back '+label+' | shoulder muscle',(s*.245,.19,2.035),(.30,.16,.22),skin,'chest',10,5),*alt)
m.facets(m.ellipsoid('Neck | thick trapezius',(0,0,2.33),(.263,.223,.26),skin,'neck',10,6),*alt)

# Angular ogre head with heavy brows, narrow glowing eyes and a jaw guard.
m.facets(m.loft('Head | squared ogre skull',[(2.355,0,-.049,.207,.19),
     (2.48,0,-.029,.279,.225),(2.70,0,-.019,.297,.228),
     (2.838,0,.015,.22,.187),(2.88,0,.018,.09,.104)],skin,'head',10,.009),*alt)
for s,label in [(-1,'R'),(1,'L')]:
    m.facets(m.ellipsoid('Cheek '+label+' | heavy cheekbone',(s*.189,-.22,2.55),(.113,.09,.101),skin,'head',8,4),*alt)
    socket=m.ellipsoid('Eye '+label+' | recessed socket',(s*.132,-.232,2.673),(.083,.024,.045),m.black,'head',8,4)
    socket.rotation_euler.y=-s*.18
    eye=m.ellipsoid('Eye '+label+' | ember',(s*.132,-.254,2.667),(.032,.004,.015),m.eyes,'head',10,5)
    eye.rotation_euler.y=-s*.18
    m.ellipsoid('Eye '+label+' | hot core',(s*.132,-.258,2.667),(.006,.0015,.007),m.eye_core,'head',8,4)
    m.panel('Brow '+label+' | brutal brow ridge',[(s*.033,-.251,2.691),(s*.063,-.214,2.76),
       (s*.255,-.166,2.77),(s*.239,-.245,2.713)],.10,skin_dark,'head',.005)
m.panel('Nose | broad angular bridge',[(-.056,-.257,2.718),(.056,-.257,2.718),
      (.098,-.331,2.591),(.047,-.354,2.567),(-.047,-.354,2.567),(-.098,-.331,2.591)],
      .083,skin,'head',.008)
for s in [-1,1]:
    m.ellipsoid('Nose | nostril '+str(s),(s*.047,-.344,2.587),(.025,.008,.011),skin_dark,'head',8,4)
m.panel('Jaw guard | forged iron face',[(-.226,-.249,2.527),(-.11,-.311,2.557),
    (.11,-.311,2.557),(.226,-.249,2.527),(.211,-.24,2.383),(0,-.32,2.348),
    (-.211,-.24,2.383)],.07,iron,'head',.009)
m.strip('Jaw guard | lower worn seam',[(-.205,-.261,2.394),(0,-.328,2.359),(.205,-.261,2.394)],.009,iron_light,'head')
for x in [-.109,0,.109]:
    y=-.325+abs(x)*.14
    m.box('Jaw guard | breathing slot',(x,y,2.474),(.024,.008,.079),m.black,'head',.004)

# Two long, deliberately faceted curved horns, fixed to the head.
for s,label in [(-1,'R'),(1,'L')]:
    path=[((s*.242,.021,2.717),.126,.134),((s*.417,.024,2.759),.131,.132),
          ((s*.61,.026,2.86),.11,.111),((s*.775,.025,3.017),.087,.09),
          ((s*.84,.013,3.196),.053,.057),((s*.754,-.012,3.375),0,0)]
    m.tube('Horn '+label+' | curved ivory',path,bone,'head',8,(bone_light,bone_dark))
    m.cylinder_between('Horn '+label+' | iron socket',(s*.252,.021,2.72),(s*.351,.023,2.745),
                        .15,iron,'head',radius_end=.145,sides=10)
    m.cylinder_between('Horn '+label+' | socket rim',(s*.343,.023,2.743),(s*.361,.024,2.749),
                        .147,iron_light,'head',sides=10)

# Broad belt with overlapping steel skirt plates and a central diamond badge.
m.loft('Belt | heavy leather girdle',[(1.085,0,0,.427,.30),(1.268,0,0,.435,.30)],m.black,'pelvis',12,.009)
for z in [1.085,1.25]:
    m.loft('Belt | worn iron band '+str(z),[(z,0,0,.44,.31),(z+.023,0,0,.44,.31)],iron_light,'pelvis',12)
m.panel('Belt | wide central plate',[(-.137,-.33,1.263),(.137,-.33,1.263),
    (.13,-.342,1.084),(0,-.361,.987),(-.13,-.342,1.084)],.045,iron,'pelvis',.008)
m.panel('Belt | diamond boss',[(0,-.392,1.255),(.083,-.392,1.181),(0,-.41,1.054),
      (-.083,-.392,1.181)],.035,iron_light,'pelvis',.006)
m.panel('Skirt | center hanging iron plate',[(-.095,-.309,1.07),(.095,-.309,1.07),
    (.132,-.356,.779),(0,-.371,.625),(-.132,-.356,.779)],.055,iron,'pelvis',.008)
m.strip('Skirt | center worn edge',[(-.094,-.322,1.056),(-.125,-.371,.783),(0,-.385,.64),
      (.125,-.371,.783),(.094,-.322,1.056)],.008,iron_light,'pelvis')
for s,label in [(-1,'R'),(1,'L')]:
    m.panel('Skirt '+label+' | hip tasset',[(s*.135,-.28,1.09),(s*.388,-.203,1.107),
       (s*.488,-.265,.883),(s*.419,-.322,.752),(s*.2,-.344,.88)],.082,iron,'pelvis',.012)
    m.strip('Skirt '+label+' | tasset worn edge',[(s*.393,-.22,1.103),(s*.475,-.28,.886),
       (s*.415,-.337,.767),(s*.21,-.361,.885)],.009,iron_light,'pelvis')
    m.rivet('Belt '+label+' | fastening',(s*.299,-.283,1.174),.021,'pelvis',iron_light)

specs={
 'root':((0,0,0),(0,0,.26),None),
 'pelvis':((0,0,1.03),(0,0,1.36),'root'),
 'spine':((0,0,1.36),(0,0,1.81),'pelvis'),
 'chest':((0,0,1.81),(0,0,2.25),'spine'),
 'neck':((0,0,2.25),(0,0,2.46),'chest'),
 'head':((0,0,2.46),(0,0,2.84),'neck'),
}

for s,label in [(-1,'R'),(1,'L')]:
    # Thick legs and heavy plated boots.
    thigh='thigh.'+label; shin='shin.'+label; foot='foot.'+label
    hip=(s*.263,0,1.15); knee=(s*.33,-.012,.651); ankle=(s*.363,.01,.235)
    specs[thigh]=(hip,knee,'pelvis'); specs[shin]=(knee,ankle,thigh)
    specs[foot]=(ankle,(s*.363,-.23,.11),shin)
    weights=lambda p,t=thigh,l=shin:m.blend_axis(p.z,[(.45,l),(.58,l),(.75,t)])
    m.tube('Leg '+label+' | continuous thick hide',[(hip,.208,.206),
        ((s*.30,0,.905),.233,.211),(knee,.165,.155),
        ((s*.35,.009,.437),.183,.178),(ankle,.132,.141)],skin,weights,10,alt)
    m.facets(m.ellipsoid('Knee '+label+' | iron cop',(s*.33,-.125,.645),(.196,.104,.157),iron,shin,8,4),*metal_alt)
    m.loft('Greave '+label+' | heavy armor',[(.20,s*.363,.01,.165,.173),
        (.35,s*.36,.012,.205,.204),(.54,s*.345,0,.20,.189)],iron,shin,8,.008)
    for z,rx,ry in [(.215,.175,.18),(.485,.209,.20)]:
        m.loft('Greave '+label+' | wide retaining strap '+str(z),[(z,s*.35,.01,rx,ry),
             (z+.058,s*.35,.01,rx,ry)],iron_light,shin,8,.004)
    m.panel('Greave '+label+' | central diamond',[(s*.35,-.206,.457),(s*.35+.075,-.21,.395),
        (s*.35,-.229,.302),(s*.35-.075,-.21,.395)],.022,iron,'shin.'+label,.004)
    m.loft('Boot '+label+' | dark sole',[(.014,s*.365,-.10,.207,.282),
        (.058,s*.365,-.10,.213,.286)],m.black,foot,10)
    boot=m.loft('Boot '+label+' | broad iron sabaton',[(.053,s*.365,-.10,.213,.285),
         (.139,s*.365,-.106,.211,.274),(.257,s*.365,-.015,.151,.179)],iron,foot,10,.009)
    m.facets(boot,*metal_alt)
    for i in range(3):
        y=-.12-i*.067; z=.211-i*.025
        m.strip('Boot '+label+' | articulated seam '+str(i),[(s*.365-.166,y,z-.027),
            (s*.365,y-.014,z),(s*.365+.166,y,z-.027)],.01,iron_light,foot)

    # Arms have blended skin at elbows and rigid iron pauldrons above them.
    upper='upper_arm.'+label; fore='forearm.'+label; hand='hand.'+label
    shoulder=(s*.62,.025,2.17); elbow=(s*.879,-.005,1.726)
    wrist=(s*.97,-.18,1.395); palm=(s*.997,-.232,1.299)
    specs[upper]=(shoulder,elbow,'chest'); specs[fore]=(elbow,wrist,upper)
    specs[hand]=(wrist,(s*1.004,-.242,1.145),fore)
    weights=lambda p,u=upper,f=fore,h=hand:m.blend_axis(p.z,[(1.35,h),(1.52,f),(1.65,f),(1.89,u)])
    m.tube('Arm '+label+' | muscular faceted hide',[(shoulder,.23,.231),
        ((s*.775,.01,1.965),.265,.245),(elbow,.196,.197),
        ((s*.94,-.096,1.535),.224,.214),(wrist,.139,.136)],skin,weights,10,alt)
    cap=m.loft('Pauldron '+label+' | angular iron shell',[(2.024,s*.724,.033,.315,.30),
       (2.229,s*.70,.04,.302,.28),(2.409,s*.607,.05,.179,.192),
       (2.439,s*.575,.06,.039,.064)],iron,upper,8,.01)
    m.facets(cap,*metal_alt)
    m.loft('Pauldron '+label+' | broad worn rim',[(2.012,s*.724,.033,.327,.312),
         (2.054,s*.721,.033,.33,.312)],iron_light,upper,8,.004)
    m.panel('Pauldron '+label+' | front angular plate',[(s*.422,-.217,2.266),
        (s*.646,-.252,2.341),(s*.97,-.165,2.11),(s*.814,-.278,2.033),
        (s*.532,-.287,2.09)],.058,iron,upper,.008)
    m.panel('Pauldron '+label+' | diamond stud',[(s*.675,-.303,2.253),
       (s*.734,-.303,2.194),(s*.675,-.328,2.13),(s*.616,-.303,2.194)],.028,iron_light,upper,.003)
    # Wrist wrap and substantial hands: right closed on axe; left relaxed.
    m.cylinder_between('Wrist '+label+' | leather wrap',(s*.964,-.162,1.426),
       (s*.979,-.20,1.358),.151,m.black,hand,sides=10)
    m.facets(m.ellipsoid('Hand '+label+' | broad palm',palm,(.16,.119,.156),skin,hand,10,5),*alt)
    for j in range(4):
        if label=='R':
            p=(s*1.002,-.35,1.386-j*.070)
            finger=m.box('Hand R | curled finger '+str(j+1),p,(.205,.119,.066),skin,hand,.022)
            m.facets(finger,*alt)
        else:
            xx=palm[0]+(j-1.5)*.072
            top=(xx,-.255,1.237)
            mid=(xx+.01,-.267,1.12+abs(j-1.5)*.018)
            tip=(xx+.008,-.301,1.064+abs(j-1.5)*.025)
            m.tube('Hand L | finger '+str(j+1),[(top,.045,.047),(mid,.043,.043),
                   (tip,.03,.032)],skin,hand,7,alt)
    m.tube('Hand '+label+' | opposing thumb',[
       ((palm[0]-s*.122,-.244,1.349),.061,.062),
       ((palm[0]-s*.18,-.309,1.281),.051,.052),
       ((palm[0]-s*.117,-.373,1.256),.033,.034)],skin,hand,8,alt)

# Long upright axe gripped by the right hand; blade is complete geometry.
axe_x=-1.013; axe_y=-.298
specs['weapon.R']=((axe_x,axe_y,1.31),(axe_x,axe_y,2.20),'hand.R')
m.cylinder_between('Axe | long ashwood shaft',(axe_x,axe_y,.08),(axe_x,axe_y,2.93),
                    .047,wood,'weapon.R',radius_end=.046,sides=10)
for z in [.12,.57,1.02,1.61,2.32,2.73,2.90]:
    m.cylinder_between('Axe | iron binding '+str(z),(axe_x,axe_y,z-.037),
        (axe_x,axe_y,z+.037),.058,iron,'weapon.R',sides=10)
    m.cylinder_between('Axe | binding lip '+str(z),(axe_x,axe_y,z+.027),
        (axe_x,axe_y,z+.042),.06,iron_light,'weapon.R',sides=10)
for i in range(7):
    z=.68+i*.045
    m.cylinder_between('Axe | lower grip winding '+str(i),(axe_x,axe_y,z),
        (axe_x,axe_y,z+.018),.051,m.black,'weapon.R',sides=10)
outline=[(-1.04,2.838),(-1.295,2.915),(-1.56,3.091),(-1.671,2.819),
         (-1.651,2.478),(-1.449,2.175),(-1.433,2.54),(-1.04,2.608)]
m.panel('Axe | broad forged blade',[(x,axe_y-.067,z) for x,z in outline],.134,steel,'weapon.R',.007)
m.panel('Axe | honed cutting edge',[(-1.56,axe_y-.077,3.091),(-1.671,axe_y-.077,2.819),
    (-1.651,axe_y-.077,2.478),(-1.449,axe_y-.077,2.175),(-1.508,axe_y-.082,2.474),
    (-1.525,axe_y-.082,2.792)],.153,steel_edge,'weapon.R',.002)
m.box('Axe | thick iron eye',(axe_x,axe_y,2.725),(.178,.189,.285),iron,'weapon.R',.016)
m.panel('Axe | eye diamond rivet',[(axe_x,axe_y-.105,2.8),
    (axe_x+.048,axe_y-.105,2.735),(axe_x,axe_y-.12,2.67),(axe_x-.048,axe_y-.105,2.735)],
    .012,iron_light,'weapon.R',.003)

m.finish(specs,camera=(4.2,-8,3.8),target=(-.16,0,1.69),ortho=4.04,
    pose_object='Head | squared ogre skull',
    landmarks={'horns':{'prefix':'Horn ','suffix':'curved ivory','count':2},
               'axe_blade':{'prefix':'Axe | broad forged blade','count':1}},
    back_camera=(-4.3,8,3.9))
