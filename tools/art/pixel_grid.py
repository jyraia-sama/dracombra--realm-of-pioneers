import numpy as np
from PIL import Image
from scipy import ndimage

def objects(path, min_area=20000):
    a=np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    r,g,b=a[...,0],a[...,1],a[...,2]
    bg=(r>110)&(b>110)&(g<0.5*np.minimum(r,b))
    lab,k=ndimage.label(ndimage.binary_dilation(~bg,iterations=6))
    out=[]
    for o in ndimage.find_objects(lab):
        if (o[0].stop-o[0].start)*(o[1].stop-o[1].start)>min_area:
            out.append((a[o],bg[o],o))
    out.sort(key=lambda t:t[2][1].start)
    return out

def err_for(a, bgm, p, ox, oy):
    h,w=a.shape[:2]
    ys=np.arange(oy+p/2,h,p).astype(int); xs=np.arange(ox+p/2,w,p).astype(int)
    small=a[ys][:,xs]
    # reconstruit
    yi=np.clip(((np.arange(h)-oy)//p).astype(int),0,len(ys)-1); xi=np.clip(((np.arange(w)-ox)//p).astype(int),0,len(xs)-1)
    rec=small[yi][:,xi]
    m=~bgm
    return np.abs(rec-a)[m].mean()

def best_grid(a,bgm):
    best=None
    for p in np.arange(8.0,16.01,0.25):
        for ox in np.arange(0,p,p/4):
            for oy in np.arange(0,p,p/4):
                e=err_for(a,bgm,p,ox,oy)
                if best is None or e<best[0]: best=(e,p,ox,oy)
    return best

def sample(a,bgm,p,ox,oy):
    h,w=a.shape[:2]
    ys=np.arange(oy+p/2,h,p).astype(int); xs=np.arange(ox+p/2,w,p).astype(int)
    # vote majoritaire dans le carré central de chaque bloc pour éviter le flou
    out=np.zeros((len(ys),len(xs),4),np.uint8)
    for j,y in enumerate(ys):
        for i,x in enumerate(xs):
            r=max(1,int(p*0.25))
            blk=a[max(0,y-r):y+r+1,max(0,x-r):x+r+1].reshape(-1,3)
            bb=bgm[max(0,y-r):y+r+1,max(0,x-r):x+r+1].reshape(-1)
            if bb.mean()>0.5: continue
            col=np.median(blk[~bb],axis=0)
            out[j,i,:3]=col; out[j,i,3]=255
    # recadre
    ys_,xs_=np.where(out[...,3]>0)
    return Image.fromarray(out[ys_.min():ys_.max()+1, xs_.min():xs_.max()+1])

if __name__=='__main__':
    import sys
    for f in ['pines.png','oaks.png']:
        for i,(a,bgm,o) in enumerate(objects(f)):
            e,p,ox,oy=best_grid(a,bgm)
            im=sample(a,bgm,p,ox,oy)
            print(f,i,'pixel',p,'err',round(e,1),'size',im.size)
            im.save(f'{f[:-4]}_{i}.png')
