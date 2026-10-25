import numpy as np, glob, os, json
from PIL import Image
from scipy import ndimage
def half(im):
    a=np.asarray(im).astype(np.float32)
    h,w=a.shape[:2]; a=np.pad(a,((0,h%2),(0,w%2),(0,0)))
    al=a[...,3]>0
    blocks=a.reshape(a.shape[0]//2,2,a.shape[1]//2,2,4)
    m=al.reshape(al.shape[0]//2,2,al.shape[1]//2,2)
    cnt=m.sum((1,3))
    rgb=(blocks[...,:3]*m[...,None]).sum((1,3))/np.maximum(cnt,1)[...,None]
    # palette de l'original : chaque pixel prend la couleur la plus proche (pas de teintes nouvelles)
    pal=np.unique(a[al][:,:3],axis=0)
    d=((rgb[...,None,:]-pal[None,None])**2).sum(-1); rgb=pal[d.argmin(-1)]
    # le contour sombre l'emporte : un bloc qui contient du contour reste sombre au bord
    out=np.zeros(rgb.shape[:2]+(4,),np.uint8); out[...,:3]=rgb; out[...,3]=np.where(cnt>=2,255,0)
    o=out[...,3]>0; edge=o&~ndimage.binary_erosion(o)
    darkest=pal[np.argmin(pal.sum(1))]
    out[edge,:3]=darkest
    return Image.fromarray(out)
names=['city/rubble_small','city/rubble_blocks','city/rubble_column','city/rubble_pillar','city/rubble_slab','city/rubble_wing','city/rubble_dragon',
 'sylve/bush','sylve/bush_berries','sylve/tall_grass','sylve/tall_grass_b','sylve/flowers_yellow','sylve/flowers_white','sylve/flowers_pink','sylve/flax_plant',
 'ruins/pillar','ruins/pillar_broken','city/ruin_arch','city/ruin_wall','city/ruin_arch_dragon']
os.makedirs('final/city',exist_ok=True); os.makedirs('final/sylve',exist_ok=True); os.makedirs('final/ruins',exist_ok=True)
for n in names:
    im=half(Image.open('out/'+n+'.png')); im.save('final/'+n+'.png'); print(n,im.size)
for n in ['sylve/rock_grey','sylve/rock_grey_big','sylve/gem_rock_new','sylve/stump','sylve/log','sylve/pebbles']:
    Image.open('out/'+n+'.png').save('final/'+n+'.png')
# planche de contrôle
allp=sorted(glob.glob('final/*/*.png'))
ims=[Image.open(p) for p in allp]
W=sum(i.width+6 for i in ims)+6; H=max(i.height for i in ims)+12
bg=Image.new('RGBA',(W,H),(134,151,62,255)); x=6
for i in ims: bg.alpha_composite(i,(x,H-6-i.height)); x+=i.width+6
bg.resize((W*3,H*3),Image.NEAREST).save('check.png'); print(W,H)
