import sys; sys.path.insert(0,'../trees'); sys.path.insert(0,'../props2')
from grid import *
from make_trees import snap_colors, clean_edges
from half import half
import os
def objects_merged(path, gap=6, min_area=2500):
    """Composantes (dilatées de `gap`) ; les petites (os, cailloux, étincelles) sont
    rattachées à la grande composante la plus proche."""
    a=np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    r,g,b=a[...,0],a[...,1],a[...,2]
    bg=(r>170)&(b>170)&(g<0.45*np.minimum(r,b))
    lab,k=ndimage.label(ndimage.binary_dilation(~bg,iterations=gap))
    objs=ndimage.find_objects(lab)
    areas=ndimage.sum(~bg,lab,range(1,k+1))
    big=[i for i in range(k) if areas[i]>=min_area]
    boxes={i:[objs[i][1].start,objs[i][0].start,objs[i][1].stop,objs[i][0].stop] for i in big}
    for i in range(k):
        if i in boxes or areas[i]<20: continue
        o=objs[i]; cx=(o[1].start+o[1].stop)/2; cy=(o[0].start+o[0].stop)/2
        def dist(j):
            B=boxes[j]; dx=max(B[0]-cx,0,cx-B[2]); dy=max(B[1]-cy,0,cy-B[3]); return dx*dx+dy*dy
        j=min(boxes,key=dist)
        if dist(j)<60**2:
            B=boxes[j]; boxes[j]=[min(B[0],o[1].start),min(B[1],o[0].start),max(B[2],o[1].stop),max(B[3],o[0].stop)]
    boxes=list(boxes.values())
    # rangées : objets dont les intervalles verticaux se recouvrent
    boxes.sort(key=lambda bx:bx[3])
    rows=[]
    for bx in boxes:
        if rows and bx[1] < rows[-1][0]: rows[-1][1].append(bx); rows[-1][0]=max(rows[-1][0],bx[3])
        else: rows.append([bx[3],[bx]])
    out=[]
    for cy,rs in rows:
        for bx in sorted(rs,key=lambda t:t[0]):
            sl=(slice(bx[1],bx[3]),slice(bx[0],bx[2]))
            out.append((a[sl],bg[sl],bx))
    return out
def extract(a,bgm,p,ncol=16):
    best=min(((err_for(a,bgm,p,ox,oy),ox,oy) for ox in np.arange(0,p,p/6) for oy in np.arange(0,p,p/6)))
    im=clean_edges(snap_colors(sample(a,bgm,p,best[1],best[2]),ncol))
    al=np.asarray(im)[...,3]>0; ys,xs=np.where(al)
    return im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
def run(sheet,names,lo=2.5,hi=14,gap=14,min_area=2500,shared=True,halve_to=None):
    objs=objects_merged(sheet,gap,min_area)
    print(sheet,len(objs),'pour',len(names))
    if len(objs)!=len(names):
        for _,_,bx in objs: print('   ',bx)
        return
    if shared:
        ps=[detect_pixel(a,b,lo,hi,0.25) for a,b,_ in objs]
        p=float(np.median(ps)); ps=[p]*len(objs)
    else:
        ps=[detect_pixel(a,b,lo,hi,0.25) for a,b,_ in objs]
    for n,(a,b,bx),p in zip(names,objs,ps):
        im=extract(a,b,p)
        if halve_to and n in halve_to:
            while im.width>halve_to[n]*1.45: im=half(im)
        os.makedirs('out/'+os.path.dirname(n),exist_ok=True)
        im.save('out/'+n+'.png'); print('  ',n,'p',round(p,2),im.size)
