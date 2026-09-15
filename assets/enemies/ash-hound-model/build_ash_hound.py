"""Rebuild the Ash Hound mesh, rig, Blender file, GLB and studio render."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import model_tools as m
from mathutils import Vector

m.setup('ash-hound','Ash Hound')
hide=m.material('Hide | ash blue charcoal','333e51',.16,.68)
hide_light=m.material('Hide | raised facets','3d485d',.16,.66)
hide_dark=m.material('Hide | shadow facets','293141',.14,.74)
armor=m.material('Carapace | dark slate','343440',.53,.42)
armor_light=m.material('Carapace | beveled edges','505361',.57,.4)
bone=m.material('Bone | aged ivory','cbbb8c',.03,.56)
bone_light=m.material('Bone | pale facets','dfd1a6',.03,.52)
bone_dark=m.material('Bone | dark roots','91835d',.03,.64)
ear_inner=m.material('Ears | muted oxblood','432c3c',.04,.84)
claws=m.material('Claws | dark horn','747075',.28,.43)
alt=(hide_light,hide_dark)

# Continuous, low-slung body with a heavy chest and tucked-up abdomen.
body_weights=lambda p:m.blend_axis(p.y,[(-.48,'chest'),(.04,'spine'),(.57,'pelvis')])
m.yloft('Body | faceted ribcage',[
 (-.79,0,1.06,.23,.29),(-.56,0,1.02,.355,.36),(-.27,0,.98,.36,.35),
 (.06,0,.965,.28,.25),(.35,0,.955,.255,.245),(.60,0,.95,.29,.29),(.84,0,.9,.19,.22),
 (.955,0,.905,.11,.145),(1.025,0,.91,0,0)],
 hide,body_weights,12,alt)
m.yloft('Neck | raised hunting ruff',[
 (-1.015,0,1.265,.22,.225),(-.79,0,1.18,.26,.275),(-.52,0,1.08,.285,.31)],
 hide,lambda p:m.blend_axis(p.y,[(-.98,'neck'),(-.55,'chest')]),10,alt)
for s,label in [(-1,'R'),(1,'L')]:
    m.facets(m.ellipsoid('Chest '+label+' | shoulder muscle',(s*.23,-.50,1.01),(.205,.30,.33),
             hide,'chest',10,6),*alt)
    m.facets(m.ellipsoid('Haunch '+label+' | hind muscle',(s*.245,.55,.88),(.23,.285,.30),
             hide,'pelvis',10,6),*alt)
    # Angular cheek-ruff plates stop at the neck instead of introducing fur.
    m.panel('Ruff '+label+' | sweeping cheek plane',[(s*.13,-1.12,1.31),(s*.31,-.98,1.23),
       (s*.36,-.79,1.07),(s*.23,-.97,1.04)],.10,hide_dark,'neck',.008)

# Broad lupine skull, tapering muzzle, dark nose and a separate lower jaw.
m.yloft('Head | angular skull',[
 (-1.35,0,1.265,.188,.159),(-1.17,0,1.305,.254,.205),
 (-.965,0,1.29,.255,.212),(-.84,0,1.24,.185,.178)],hide,'head',12,alt)
m.yloft('Muzzle | tapering upper snout',[
 (-1.665,0,1.157,.107,.075),(-1.57,0,1.169,.15,.101),
 (-1.35,0,1.203,.187,.113),(-1.23,0,1.215,.15,.14)],hide_dark,'head',8)
m.yloft('Jaw | lower mandible',[
 (-1.61,0,1.047,.101,.057),(-1.42,0,1.052,.147,.068),(-1.16,0,1.10,.177,.09)],
 armor,'jaw',8)
m.panel('Mouth | recessed dark opening',[(-.12,-1.642,1.107),(.12,-1.642,1.107),
     (.137,-1.435,1.111),(-.137,-1.435,1.111)],.022,m.black,'jaw',0)
m.panel('Nose | triangular dark leather',[(-.105,-1.675,1.203),(.105,-1.675,1.203),
     (.076,-1.687,1.132),(0,-1.701,1.113),(-.076,-1.687,1.132)],.035,m.black,'head',.006)
for s,label in [(-1,'R'),(1,'L')]:
    m.ellipsoid('Nose '+label+' | nostril',(s*.062,-1.697,1.168),(.023,.008,.012),hide_dark,'head',8,4)
    socket=m.ellipsoid('Eye '+label+' | deep socket',(s*.178,-1.338,1.32),(.081,.021,.047),m.black,'head',8,4)
    socket.rotation_euler.y=-s*.23
    eye=m.ellipsoid('Eye '+label+' | ember',(s*.178,-1.356,1.322),(.034,.005,.018),m.eyes,'head',10,5)
    eye.rotation_euler.y=-s*.23
    m.ellipsoid('Eye '+label+' | hot slit',(s*.178,-1.361,1.322),(.004,.0015,.011),m.eye_core,'head',8,4)
    m.panel('Brow '+label+' | aggressive upper ridge',[(s*.071,-1.348,1.331),(s*.105,-1.331,1.379),
         (s*.248,-1.257,1.423),(s*.273,-1.277,1.369)],.07,armor,'head',.005)
    # Tall pointed ears with inset oxblood inner surfaces.
    ear=[(s*.104,-.994,1.405),(s*.286,-.93,1.367),(s*.288,-.903,1.772),
         (s*.176,-.914,1.651)]
    m.panel('Ear '+label+' | pointed outer shell',ear,.083,hide,'head',.005)
    m.panel('Ear '+label+' | inset inner face',[(s*.15,-1.001,1.429),(s*.249,-.956,1.409),
         (s*.267,-.931,1.709),(s*.199,-.946,1.591)],.015,ear_inner,'head',.002)
    m.tube('Fang '+label+' | long upper canine',[
        ((s*.145,-1.471,1.114),.047,.041),((s*.149,-1.497,1.043),.039,.035),
        ((s*.135,-1.524,.947),.022,.02),((s*.115,-1.543,.903),0,0)],
        bone,'head',7,(bone_light,bone_dark))

# Exactly five ivory dorsal spines, each with a dark socket.
for i,(y,z,length) in enumerate([(-.46,1.337,.35),(-.205,1.317,.32),(.07,1.205,.32),
                                (.335,1.188,.31),(.60,1.214,.26)],1):
    parent='chest' if i<3 else ('spine' if i==3 else 'pelvis')
    m.ellipsoid('Spine %02d | dark root'%i,(0,y,z-.025),(.105,.108,.056),armor,parent,8,4)
    m.tube('Dorsal spike %02d | ivory'%i,[((0,y,z-.016),.079,.074),
        ((0,y+.04,z+length*.57),.056,.049),((0,y+.10,z+length),0,0)],
        bone,parent,7,(bone_light,bone_dark))

specs={
 'root':((0,0,0),(0,0,.22),None),
 'pelvis':((0,.57,.91),(0,.25,.98),'root'),
 'spine':((0,.25,.98),(0,-.18,1.035),'pelvis'),
 'chest':((0,-.18,1.035),(0,-.58,1.12),'spine'),
 'neck':((0,-.58,1.12),(0,-.95,1.26),'chest'),
 'head':((0,-.95,1.26),(0,-1.54,1.19),'neck'),
 'jaw':((0,-1.17,1.115),(0,-1.57,1.05),'head'),
}

# Digitigrade rear legs and planted front legs: continuous hide around the joints.
for s,label in [(-1,'R'),(1,'L')]:
    for front in [True,False]:
        tag=('Front ' if front else 'Hind ')+label
        prefix=('front_' if front else 'hind_')
        upper=prefix+'upper.'+label; lower=prefix+'lower.'+label; foot=prefix+'paw.'+label
        if front:
            a=(s*.275,-.555,1.04); b=(s*.338,-.405,.645)
            c=(s*.37,-.70,.20); d=(s*.373,-.785,.09)
            sections=[(a,.135,.16),((s*.32,-.485,.83),.151,.151),(b,.108,.11),
                      ((s*.355,-.555,.412),.074,.079),(c,.062,.067),(d,.085,.092)]
            weights=lambda p,u=upper,l=lower,f=foot:m.blend_axis(p.z,[(.14,f),(.32,l),(.58,l),(.78,u)])
            parent='chest'
        else:
            a=(s*.275,.585,.955); b=(s*.365,.326,.58)
            c=(s*.39,.742,.263); d=(s*.399,.565,.095)
            sections=[(a,.175,.19),((s*.34,.455,.735),.167,.175),(b,.119,.117),
                      ((s*.379,.585,.399),.078,.084),(c,.066,.071),(d,.072,.08)]
            weights=lambda p,u=upper,l=lower,f=foot:m.blend_axis(p.z,[(.17,f),(.32,l),(.5,l),(.70,u)])
            parent='pelvis'
        m.tube(tag+' leg | continuous faceted hide',sections,hide,weights,10,alt)
        specs[upper]=(a,b,parent); specs[lower]=(b,c,upper); specs[foot]=(c,(d[0],d[1]-.17,.08),lower)
        # Narrow overlapping armor plates follow the shin's forward surface.
        bx,by,bz=b; cx,cy,cz=c
        m.panel(tag+' leg | angular front carapace',[(bx-.089,by-.097,bz+.018),
           (bx+.089,by-.097,bz+.018),(cx+.07,cy-.068,cz+.011),
           (cx,cy-.085,cz-.025),(cx-.07,cy-.068,cz+.011)],.047,armor,lower,.009)
        m.strip(tag+' leg | carapace ridge',[(bx,by-.125,bz),(cx,cy-.09,cz+.07)],.007,armor_light,lower)
        # Four distinct toes and short tapered claws per paw.
        px,py,pz=d
        m.facets(m.ellipsoid(tag+' paw | broad pad',(px,py-.035,.106),(.157,.183,.097),armor,foot,10,5),armor_light,hide_dark)
        for j in range(4):
            xx=px+(j-1.5)*.074
            yy=py-.145+abs(j-1.5)*.017
            m.ellipsoid(tag+' paw | toe '+str(j+1),(xx,yy,.075),(.046,.09,.058),armor,foot,8,4)
            m.tube(tag+' paw | claw '+str(j+1),[((xx,yy-.048,.075),.026,.025),
                    ((xx,yy-.107,.056),.017,.017),((xx,yy-.13,.033),0,0)],claws,foot,6)

m.finish(specs,camera=(3.8,-5.5,2.7),target=(0,-.24,.84),ortho=3.06,resolution=(1400,1100),
    pose_object='Head | angular skull',
    landmarks={'dorsal_spikes':{'prefix':'Dorsal spike ','count':5},
               'fangs':{'prefix':'Fang ','count':2},'paws':{'suffix':'paw | broad pad','count':4}},
    back_camera=(-3.8,5.2,2.7))
