import sys, os, json; sys.path.insert(0,'../trees'); sys.path.insert(0,'../props2')
from grid import *
from make_trees import snap_colors, clean_edges
from extract import objects_rows
from half import half

SHEETS={
 'mouth.png':[('sylve/cave_mouth',64),('cave/cave_rubble',48)],
 'crys_a.png':[('cave/crystal_blue_large',30),('cave/crystal_blue',22),('cave/crystal_blue_small',14),('cave/crystal_purple_large',30),('cave/crystal_purple',22),('cave/crystal_purple_small',14)],
 'crys_b.png':[('cave/crystal_blue_large_b',30),('cave/crystal_blue_b',22),('cave/crystal_blue_small_b',14),('cave/crystal_purple_large_b',30),('cave/crystal_purple_b',22),('cave/crystal_purple_small_b',14)],
 'cave.png':[('cave/mushrooms',14),('cave/mushrooms_large',22),('cave/stalagmite_small',12),('cave/stalagmite',16),('cave/stalagmite_large',24),('cave/rocks_small',14),('cave/rocks',20),('cave/boulder',28),('cave/roots_a',20),('cave/roots_wide',32)],
 'lair.png':[('lair/embers_small',12),('lair/embers',18),('lair/embers_large',26),('lair/lava_crack',28),('lair/lava_crack_small',14),('lair/claw_marks_a',22),('lair/dragon_nest',96),('lair/dragon_scales',18),('lair/melted_armor',22),('lair/fallen_banner',24)],
 'misc.png':[('cave/skull_bones',18),('cave/fallen_adventurer',28),('cave/dark_pool',30),('cave/rock_fragments',16)],
}
os.makedirs('final/cave',exist_ok=True); os.makedirs('final/lair',exist_ok=True); os.makedirs('final/sylve',exist_ok=True)
for f,names in SHEETS.items():
    objs=objects_rows(f, dil=8, min_area=1500)
    print(f,len(objs),'objets pour',len(names))
    if len(objs)!=len(names):
        for a,bgm,o in objs: print('   ',o)
        continue
    ps=[detect_pixel(a,bgm,5.0,14.0,0.25) for a,bgm,o in objs]
    p=float(np.median(ps))
    for (name,target),(a,bgm,o) in zip(names,objs):
        best=None
        for ox in np.arange(0,p,p/8):
            for oy in np.arange(0,p,p/8):
                e=err_for(a,bgm,p,ox,oy)
                if best is None or e<best[0]: best=(e,ox,oy)
        im=clean_edges(snap_colors(sample(a,bgm,p,best[1],best[2]),12))
        al=np.asarray(im)[...,3]>0; ys,xs=np.where(al); im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
        k=im.width/target
        if k>1.5: im=half(im)
        im.save('final/'+name+'.png'); print('  ',name,'pixel',p,'->',im.size,'(cible',target,')')
