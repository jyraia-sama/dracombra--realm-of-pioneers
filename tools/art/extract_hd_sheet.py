"""Extrait une planche ChatGPT en sprites HD : grille de pixels retrouvée, puis réduction
par 2 tant que l'objet dépasse nettement sa hauteur cible (pixels HD, héros = 46)."""
import sys, os, json; sys.path.insert(0,'../trees'); sys.path.insert(0,'../props2')
from grid import *
from make_trees import snap_colors, clean_edges
from extract import objects_rows
from half import half

def run(sheet, specs, dil=6, min_area=800):
    objs=objects_rows(sheet,dil=dil,min_area=min_area)
    print(sheet,len(objs),'objets pour',len(specs))
    if len(objs)!=len(specs):
        for a,b,o in objs: print('   ',o[1].start,o[0].start,o[1].stop-o[1].start,o[0].stop-o[0].start)
        return
    ps=[detect_pixel(a,bgm,4.0,14.0,0.25) for a,bgm,o in objs[:4]]
    p=float(np.median(ps))
    for (name,target,key),(a,bgm,o) in zip(specs,objs):
        best=min(((err_for(a,bgm,p,ox,oy),ox,oy) for ox in np.arange(0,p,p/6) for oy in np.arange(0,p,p/6)))
        im=clean_edges(snap_colors(sample(a,bgm,p,best[1],best[2]),16))
        al=np.asarray(im)[...,3]>0; ys,xs=np.where(al); im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
        size=im.width if key=='w' else im.height
        n=0
        while size>target*1.45:
            im=half(im); size=im.width if key=='w' else im.height; n+=1
        os.makedirs('out/'+os.path.dirname(name),exist_ok=True)
        im.save('out/'+name+'.png'); print('  ',name,'p',p,'÷',2**n,im.size,'cible',target)
