from hero_fix_lib import *
import os
os.makedirs('out',exist_ok=True)
def erase_mask(a,rect,fn):
    x0,y0,x1,y1=rect; s=a[y0:y1,x0:x1]; m=fn(s)&~bg(s); s[m]=MAG
# Clerc : masse en trop (rangée face, image 5)
a=load('cleric'); erase(a,668,270,711,326); Image.fromarray(a.astype('uint8')).save('out/cleric.png')
# Guerrier
a=load('warrior')
erase(a,674,276,707,328); erase_mask(a,(670,255,712,330),purple)
# Dernière image (retour au repos) sans épée : on reprend l'image de repos avec épée.
d=align(a,(876,85,986,330),(1380,85,1490,330)); erase(a,1356,60,1536,340); paste(a,(850,60,1000,340),d)
d=align(a,(520,660,640,917),(1355,660,1475,917)); erase(a,1372,640,1536,930); erase(a,1352,830,1372,930); paste(a,(515,640,700,930),d); erase(a,1498,846,1536,930)
Image.fromarray(a.astype('uint8')).save('out/warrior.png')
# Mage : bout de bâton sans cristal (face, image 1) -> vrai bâton
a=load('mage')
erase(a,38,250,60,314)
d=align(a,(236,70,340,332),(82,70,186,332)); print('m',d); paste(a,(193,140,234,316),d)
Image.fromarray(a.astype('uint8')).save('out/mage.png')
Image.open('archer.png').convert('RGB').save('out/archer.png')
