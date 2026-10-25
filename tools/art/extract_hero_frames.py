import sys; sys.path.insert(0,'../trees'); sys.path.insert(0,'../props2')
from grid import *
from make_trees import snap_colors, clean_edges
from extract import objects_rows
import os, json
os.makedirs('fr',exist_ok=True)
info={}
for f in ['idle','walk','attack','hurt']:
    objs=objects_rows(f+'.png',dil=4,min_area=1500)
    # rangées
    rows=[]
    for a,bgm,o in objs:
        cy=(o[0].start+o[0].stop)/2
        if rows and abs(cy-rows[-1][0][0])<90: rows[-1].append((cy,a,bgm,o))
        else: rows.append([(cy,a,bgm,o)])
    print(f,[len(r) for r in rows])
    est={'idle':7.0,'walk':6.25,'attack':6.4,'hurt':5.15}[f]
    ps=[detect_pixel(a,bgm,est*0.88,est*1.12,0.05) for _,a,bgm,o in rows[0][:3]]
    p=float(np.median(ps)); print('  pixel',ps)
    for ri,r in enumerate(rows):
        r.sort(key=lambda t:t[3][1].start)
        for ci,(_,a,bgm,o) in enumerate(r):
            best=min(((err_for(a,bgm,p,ox,oy),ox,oy) for ox in np.arange(0,p,p/6) for oy in np.arange(0,p,p/6)))
            im=clean_edges(snap_colors(sample(a,bgm,p,best[1],best[2]),20))
            al=np.asarray(im)[...,3]>0; ys,xs=np.where(al); im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
            im.save(f'fr/{f}_{ri}_{ci}.png'); info[f'{f}_{ri}_{ci}']=im.size
json.dump(info,open('sizes.json','w'))
for k,v in info.items(): print(k,v)
