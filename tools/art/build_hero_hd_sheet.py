import json, numpy as np
from PIL import Image
CW,CH=64,56; AX,BASE=32,54; COLS=6
def load(n): return Image.open(f'fr/{n}.png').convert('RGBA')
def head_x(im):
    a=np.asarray(im)[...,3]>0; top=a[:12]
    ys,xs=np.where(top); return float(xs.mean()) if len(xs) else im.width/2
# rangées de la planche : (animation, direction) -> liste de frames
DIRS=[0,1,2]
rows=[]
for d in DIRS: rows.append(('idle',d,[f'idle_{d}_{i}' for i in range(4)]))
for d in DIRS: rows.append(('walk',d,[f'walk_{d}_{i}' for i in range(6)]))
# roulade provisoire (en attendant la planche) : accroupi
for d in DIRS: rows.append(('roll',d,[f'walk_{d}_0',f'hurt_{3+d}_1',f'hurt_{3+d}_1',f'hurt_{3+d}_1',f'hurt_{3+d}_1',f'idle_{d}_0']))
for d in DIRS: rows.append(('attack',d,[f'attack_{d}_{i}' for i in range(5)]))
for d in DIRS: rows.append(('hurt',d,[f'hurt_{d}_{i}' for i in range(2)]))
for d in DIRS: rows.append(('death',d,[f'hurt_{3+d}_{i}' for i in range(4)]))
# mains (repère de l'image découpée) et angle de l'épée en degrés (0 = vers le haut, sens horaire)
IDLE={0:(6,31,205),1:(25,30,160),2:(18,31,150)}
ATT={0:[(8,10,315),(6,16,290),(22,28,180),(24,31,160),(8,31,205)],
     1:[(11,9,315),(6,22,270),(44,19,30),(32,33,120),(29,30,160)],
     2:[(11,9,300),(8,17,320),(46,22,90),(35,33,135),(28,30,150)]}
sheet=Image.new('RGBA',(CW*COLS,CH*len(rows)),(0,0,0,0))
hands={}
for r,(anim,d,frames) in enumerate(rows):
    base_im=load(f'idle_{d}_0'); base_hx=head_x(base_im)
    for c,n in enumerate(frames):
        im=load(n)
        lying=anim=='death' and c>=2
        ax=im.width/2 if lying else head_x(im)
        x=int(round(AX-ax)); y=BASE-im.height
        sheet.alpha_composite(im,(c*CW+max(0,min(CW-im.width,x)),r*CH+max(0,y)))
        ox=max(0,min(CW-im.width,x)); oy=max(0,y)
        if anim=='attack': hx,hy,ang=ATT[d][c]
        elif anim in ('idle','hurt','roll'):
            hx,hy,ang=IDLE[d]
            # même main que l'image de repos, recalée sur la tête de cette image
            hx=hx-base_hx+ax; hy=hy-base_im.height+im.height
        elif anim=='walk':
            hx,hy,ang=IDLE[d]; hx=hx-base_hx+ax; hy=hy-base_im.height+im.height
        else: hx=hy=ang=None
        key=f'{anim}_{d}'
        hands.setdefault(key,[])
        hands[key].append(None if hx is None or anim=='roll' else [round(ox+hx-AX,1),round(oy+hy-BASE,1),ang])
sheet.save('warrior_hd.png'); json.dump({'cell':[CW,CH],'anchor':[AX,BASE],'hands':hands},open('warrior_hd.json','w'),indent=0)
print(sheet.size)
