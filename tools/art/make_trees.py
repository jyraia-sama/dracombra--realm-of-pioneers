from pixel_grid import *
import json
def snap_colors(im, n=12):
    a=np.asarray(im).copy(); m=a[...,3]>0
    q=Image.fromarray(a[...,:3]).quantize(n, method=Image.Quantize.MEDIANCUT, kmeans=2).convert('RGB')
    a[...,:3]=np.where(m[...,None],np.asarray(q),0)
    return Image.fromarray(a)
def clean_edges(im):
    # retire les pixels isolés et rosés du bord
    a=np.asarray(im).copy()
    r,g,b=a[...,0].astype(int),a[...,1].astype(int),a[...,2].astype(int)
    pink=(r>150)&(b>120)&(g<r*0.7)
    a[pink,3]=0
    al=a[...,3]>0
    nb=ndimage.convolve(al.astype(int),np.ones((3,3),int),mode='constant')-al
    a[al&(nb<=1),3]=0
    return Image.fromarray(a)
specs={'pines.png':[('pine_a',12.75),('pine_b',13.0)],'oaks.png':[('oak_a',6.5),('oak_b',6.5),('oak_big',6.5)]}
out={}
for f,names in specs.items():
    objs=objects(f)
    for (name,p),(a,bgm,o) in zip(names,objs):
        best=None
        for ox in np.arange(0,p,p/8):
            for oy in np.arange(0,p,p/8):
                e=err_for(a,bgm,p,ox,oy)
                if best is None or e<best[0]: best=(e,ox,oy)
        im=clean_edges(snap_colors(sample(a,bgm,p,best[1],best[2])))
        ys,xs=np.where(np.asarray(im)[...,3]>0); im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
        im.save(name+'.png'); out[name]=im.size; print(name,im.size)
# oak_c : variante, le petit chêne retourné
Image.open('oak_a.png').transpose(Image.FLIP_LEFT_RIGHT).save('oak_c.png')
