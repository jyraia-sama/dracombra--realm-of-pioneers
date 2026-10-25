"""Installe des sprites de décor et recalcule, dans leurs scènes, le décalage du sprite
et les formes de collision (d'après la base visible du dessin)."""
import re, glob, shutil, sys, numpy as np
from PIL import Image
ROOT='/home/claude/dracombra--realm-of-pioneers/'
import os
SRC=os.environ.get('PROPS_SRC','/tmp/claude-0/-home-claude/98826a0e-b8e6-5cf3-abe9-36d613febf38/scratchpad/props2/final/')

def runs(cols, gap=2):
    xs=np.where(cols)[0]; out=[]
    if len(xs)==0: return out
    s=p=xs[0]
    for x in xs[1:]:
        if x-p>gap+1: out.append((s,p)); s=x
        p=x
    out.append((s,p)); return out

def footprint(png):
    a=np.asarray(Image.open(png))[...,3]>0; h,w=a.shape
    band=max(3,min(8,int(h*0.18)))
    bottom=a[h-band:]
    rs=[r for r in runs(bottom.any(0)) if r[1]-r[0]>=3]
    cx=(min(r[0] for r in rs)+max(r[1] for r in rs)+1)/2 if rs else w/2
    return w,h,int(round(cx)),rs,band

def fix_scene(tscn, png, collide=True):
    w,h,cx,rs,band=footprint(png)
    s=open(tscn).read()
    old=re.search(r'offset = Vector2\(([-\d.]+), ([-\d.]+)\)', s)
    if 'z_index = -1' in s:
        # à plat sur le sol : centré
        new=(-(w // 2), -(h // 2)); collide=False
    elif old and float(old.group(2)) == -12 and '/roots_' in s:
        # pend du haut de la paroi
        new=(-(w // 2), -12); collide=False
    else:
        new=(-cx, -h)
    s=re.sub(r'offset = Vector2\([-\d.]+, [-\d.]+\)', f'offset = Vector2({new[0]}, {new[1]})', s, count=1)
    if collide and '[node name="Body"' in s:
        secs=re.split(r'(?m)^(?=\[)', s)
        drop_ids=set(); keep=[]
        for sec in secs:
            if sec.startswith('[node') and 'parent="Body"' in sec and 'CollisionShape2D' in sec:
                m=re.search(r'shape = SubResource\("([^"]+)"\)', sec)
                if m: drop_ids.add(m.group(1))
                continue
            keep.append(sec)
        keep=[sec for sec in keep if not any(f'id="{i}"' in sec.split('\n')[0] for i in drop_ids)]
        hh=max(4,min(8,band))
        subs=''; nodes=''
        for i,(x0,x1) in enumerate(rs):
            sw=max(3,x1-x0+1-2)
            subs+=f'[sub_resource type="RectangleShape2D" id="Foot{i}"]\nsize = Vector2({sw}, {hh})\n\n'
            px=(x0+x1+1)/2-cx
            nodes+=f'[node name="Foot{i}" type="CollisionShape2D" parent="Body"]\nposition = Vector2({px:g}, {-hh/2:g})\nshape = SubResource("Foot{i}")\n\n'
        out=''
        for sec in keep:
            if sec.startswith('[node') and not subs_done(out):
                out+=subs+'\n'
            out+=sec
            if sec.startswith('[node name="Body"'):
                if not out.endswith('\n\n'): out+='\n'
                out+=nodes
        s=re.sub(r'\n{3,}','\n\n',out)
    open(tscn,'w').write(s)
    return (w,h,cx,len(rs))

def subs_done(text): return '[node' in text

if __name__=='__main__':
    MAP={}  # chemin de texture -> fichier source
    for p in glob.glob(SRC+'*/*.png'):
        rel=p[len(SRC):]
        if rel=='sylve/gem_rock_new.png':
            rel='sylve/gem_rock.png'
        MAP['res://assets/sprites/props/'+rel]=p
        shutil.copy(p, ROOT+'assets/sprites/props/'+rel)
    for f in glob.glob(ROOT+'scenes/props/**/*.tscn', recursive=True):
        s=open(f).read()
        m=re.search(r'path="(res://assets/sprites/props/[^"]+\.png)"', s)
        if m and m.group(1) in MAP:
            print(f[len(ROOT):], fix_scene(f, MAP[m.group(1)]))
