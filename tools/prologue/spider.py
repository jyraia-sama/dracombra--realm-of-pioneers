import sys; sys.path.insert(0,'.')
import slice as S
from slice import *
from scipy import ndimage
SRC=A+'05fc862f-image.png'
base=S.load_rgba(SRC)
w=base[...,:3].min(2)>185; base[w,3]=0
# Les rangées "touché" et "mort" se chevauchent (pattes) : on sépare par composante.
lab,n=ndimage.label(base[...,3]>0)
cent=ndimage.center_of_mass(np.ones_like(lab),lab,range(1,n+1))
top=base.copy(); bot=base.copy()
for k,(cy,cx) in enumerate(cent,1):
    m=lab==k
    if cy<800: bot[m]=0
    else: top[m]=0
top[810:]=0; bot[:630]=0
# On remplace l'image : hurt dans sa bande, death décalée plus bas.
H=base.shape[0]
canvas=np.zeros((H+200,)+base.shape[1:],np.uint8)
canvas[:H]=top; canvas[200:H+200]=np.maximum(canvas[200:H+200],bot)
S.load_rgba=lambda p: canvas
exec(open('run1.py').read().split("info={}")[0].replace("from slice import *",""))
cw,ch=process('spider','x',[4,6,5,2,4],17,24,gap=8,clean=True,top=0.2,bottom=0.8)
im=Image.open('spider.png'); b=Image.new('RGBA',im.size,(104,92,92,255)); b.alpha_composite(im)
b.resize((im.width*6,im.height*6),Image.NEAREST).save('spider_prev.png')
al=canvas[...,3]>0
bands=[b for b in runs(al.any(1),8) if b[1]-b[0]>20]
print(bands)
y0,y1=bands[3]; print(runs(al[y0:y1].any(0),2))
