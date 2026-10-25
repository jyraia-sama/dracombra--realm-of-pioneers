import sys; sys.path.insert(0,'../trees')
from grid import *
from make_trees import snap_colors, clean_edges

def objects_rows(path, dil=10, min_area=3000):
    a=np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    r,g,b=a[...,0],a[...,1],a[...,2]
    bg=(r>110)&(b>110)&(g<0.5*np.minimum(r,b))
    lab,k=ndimage.label(ndimage.binary_dilation(~bg,iterations=dil))
    objs=[o for o in ndimage.find_objects(lab) if (o[0].stop-o[0].start)*(o[1].stop-o[1].start)>min_area]
    # rangées : regroupe par centre vertical
    objs.sort(key=lambda o:(o[0].start+o[0].stop)/2)
    rows=[]; 
    for o in objs:
        cy=(o[0].start+o[0].stop)/2
        if rows and abs(cy-rows[-1][0])<120: rows[-1][1].append(o)
        else: rows.append([cy,[o]])
    out=[]
    for cy,rs in rows:
        for o in sorted(rs,key=lambda o:o[1].start): out.append((a[o],bg[o],o))
    return out

SHEETS={
 'rubble.png':['city/rubble_small','city/rubble_blocks','city/rubble_column','city/rubble_pillar','city/rubble_slab','city/rubble_wing','city/rubble_dragon'],
 'plants.png':['sylve/bush','sylve/bush_berries','sylve/tall_grass','sylve/tall_grass_b','sylve/flowers_yellow','sylve/flowers_white','sylve/flowers_pink','sylve/flax_plant'],
 'ruins.png':['ruins/pillar','ruins/pillar_broken','city/ruin_arch','city/ruin_wall','city/ruin_arch_dragon'],
 'rocks.png':['sylve/rock_grey','sylve/rock_grey_big','sylve/gem_rock_new','sylve/stump','sylve/log','sylve/pebbles'],
}
import os, json
res={}
for f,names in SHEETS.items():
    objs=objects_rows(f)
    print(f,len(objs),'objets pour',len(names))
    ps=[detect_pixel(a,bgm,5.0,14.0,0.25) for a,bgm,o in objs]
    p=float(np.median(ps)); print('  pixel',ps,'->',p)
    for name,(a,bgm,o) in zip(names,objs):
        best=None
        for ox in np.arange(0,p,p/8):
            for oy in np.arange(0,p,p/8):
                e=err_for(a,bgm,p,ox,oy)
                if best is None or e<best[0]: best=(e,ox,oy)
        im=clean_edges(snap_colors(sample(a,bgm,p,best[1],best[2]),10))
        al=np.asarray(im)[...,3]>0; ys,xs=np.where(al)
        im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
        os.makedirs(os.path.dirname('out/'+name),exist_ok=True)
        im.save('out/'+name+'.png'); res[name]=im.size; print('  ',name,im.size)
json.dump(res,open('sizes.json','w'))
