from PIL import Image
import numpy as np
MAG=np.array([255,0,255])
def load(n): return np.array(Image.open(n+'.png').convert('RGB')).astype(int)
def bg(a): return (a[...,0]>200)&(a[...,2]>200)&(a[...,1]<80)
def erase(a,x0,y0,x1,y1): 
    a[y0:y1,x0:x1]=MAG
def align(a,src,dst):
    # src/dst: (x0,y0,x1,y1) boxes of same size around the body; returns dx,dy so dst = src+d
    sx0,sy0,sx1,sy1=src
    s=~bg(a[sy0:sy1,sx0:sx1])
    best=None
    for dy in range(-8,9):
        for dx in range(-8,9):
            dx0,dy0=dst[0]+dx,dst[1]+dy
            t=~bg(a[dy0:dy0+sy1-sy0,dx0:dx0+sx1-sx0])
            sc=(s^t).sum()
            if best is None or sc<best[0]: best=(sc,dx,dy)
    return dst[0]-src[0]+best[1], dst[1]-src[1]+best[2]
def paste(a,rect,d,mask_fn=None,only_bg=False):
    x0,y0,x1,y1=rect; dx,dy=d
    s=a[y0:y1,x0:x1].copy()
    m=~bg(s)
    if mask_fn is not None: m&=mask_fn(s)
    t=a[y0+dy:y1+dy,x0+dx:x1+dx]
    if only_bg: m&=bg(t)
    t[m]=s[m]
def purple(s):
    r,g,b=s[...,0],s[...,1],s[...,2]
    p=(b>r+15)&(b>110)&(g<r)
    # 2px de contour sombre autour
    from scipy.ndimage import binary_dilation
    d=binary_dilation(p,iterations=2)
    return p|(d&(s.sum(-1)<150))
