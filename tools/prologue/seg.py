import sys; sys.path.insert(0,'../assets2')
from slice import load_rgba, A
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
def segment(file, dilate=10, min_area=400):
    rgba=load_rgba(A+file)
    m=rgba[...,3]>0
    big=ndimage.binary_dilation(m,iterations=dilate)
    lab,n=ndimage.label(big)
    objs=[]
    for k in range(1,n+1):
        ys,xs=np.where((lab==k)&m)
        if len(xs)<min_area: continue
        objs.append((ys.min(),xs.min(),ys.max()+1,xs.max()+1))
    # tri par rangées puis x
    objs.sort(key=lambda b:(round(b[0]/120),b[1]))
    return rgba,objs
if __name__=='__main__':
    for name,f in [('cave','6f8a7666-image.png'),('ruins','5c27de79-image.png'),('lair','8d90410a-image.png')]:
        rgba,objs=segment(f)
        im=Image.fromarray(rgba,'RGBA'); bg=Image.new('RGBA',im.size,(60,54,64,255)); bg.alpha_composite(im)
        d=ImageDraw.Draw(bg)
        for i,(y0,x0,y1,x1) in enumerate(objs):
            d.rectangle((x0,y0,x1,y1),outline=(255,255,0,255),width=2)
            d.text((x0+4,y0+4),str(i),fill=(255,255,0,255))
        bg.convert('RGB').resize((im.width//2,im.height//2)).save(name+'_idx.png')
        print(name,len(objs),[(i,b[3]-b[1],b[2]-b[0]) for i,b in enumerate(objs)])
