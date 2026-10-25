"""Découpe une planche d'animation (rangées d'images) et reconstruit une planche à cases
régulières pour le jeu. layout : liste de rangées, chaque rangée = liste de (rangée, image)
de la planche source (ou None = case vide)."""
from seg import *
def source_rows(sheet, gap=3, min_area=1500, lo=3.0, hi=14.0, ncol=20, p=None):
    objs=objects_merged(sheet,gap,min_area)
    rows=[]
    for a,b,bx in objs:
        if rows and bx[1] < rows[-1][0]: rows[-1][1].append((a,b,bx)); rows[-1][0]=max(rows[-1][0],bx[3])
        else: rows.append([bx[3],[(a,b,bx)]])
    rows=[sorted(r,key=lambda t:t[2][0]) for _,r in rows]
    print(sheet,'rangées',[len(r) for r in rows])
    if p is None:
        ps=[detect_pixel(a,b,lo,hi,0.25) for a,b,_ in rows[0][:3]]
        p=float(np.median(ps)); print('  pixel',ps)
    out=[[extract(a,b,p,ncol) for a,b,_ in r] for r in rows]
    return out
def build(src, layout, cell=None, halve=0, pad=2):
    frames=[[None if k is None else src[k[0]][k[1]] for k in row] for row in layout]
    for _ in range(halve):
        frames=[[None if f is None else half(f) for f in row] for row in frames]
    W=max(f.width for row in frames for f in row if f)+pad*2
    H=max(f.height for row in frames for f in row if f)+pad
    if cell: W,H=max(W,cell[0]),max(H,cell[1])
    cols=max(len(r) for r in frames)
    sheet=Image.new('RGBA',(W*cols,H*len(frames)),(0,0,0,0))
    for r,row in enumerate(frames):
        for c,f in enumerate(row):
            if f is None: continue
            sheet.alpha_composite(f,(c*W+(W-f.width)//2, r*H+H-f.height))
    return sheet,(W,H),cols,len(frames)
