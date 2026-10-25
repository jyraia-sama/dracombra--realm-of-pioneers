from frames import *
import json
info={}
def save(name,res):
    sheet,cell,cols,rows=res; sheet.save('chars/'+name+'.png'); info[name]={'cell':cell,'cols':cols,'rows':rows}; print(name,cell,cols,rows)
import os; os.makedirs('chars',exist_ok=True)
sb=source_rows('slimeboar.png',p=3.0)
# slime : idle 4, hop 4, hurt 2, death 4 (5 colonnes comme avant)
save('slime',build(sb,[[(0,i) for i in range(4)],[(1,i) for i in range(4)],[(2,0),(2,1)],[(2,1),(2,2),(2,3),(2,3)]]))
# sanglier : walk 6, charge 6, hurt 2, death 4
save('boar',build(sb,[[(3,i) for i in range(6)],[(4,i) for i in range(6)],[(5,0),(5,1)],[(6,i) for i in range(4)]]))
gs=source_rows('gobspider.png',p=3.0)
# gobelin : idle 4, run 6, throw 5, charge 4 (= course), death 4
save('rock_goblin',build(gs,[[(0,i) for i in range(4)],[(1,i) for i in range(6)],[(2,i) for i in range(5)],[(1,i) for i in range(4)],[(3,i) for i in range(4)]]))
# araignée : idle 4, run 6, leap 5 (= course), hurt 2, death 4
save('obsidian_spider',build(gs,[[(4,i) for i in range(4)],[(5,i) for i in range(6)],[(5,i) for i in range(5)],[(6,0),(6,1)],[(6,i) for i in range(4)]]))
gs[7][0].save('chars/thrown_rock.png')
ys=source_rows('ysolde.png',p=3.0)
save('ysolde',build(ys,[[(r,i) for i in range(len(ys[r]))] for r in range(8)]))
dr=source_rows('dragon.png',p=2.0)
# dragon : idle 4, griffe 5, cabré 4, rugissement 3
save('solakor',build(dr,[[(r,i) for i in range(len(dr[r]))] for r in range(4)]))
json.dump(info,open('chars/info.json','w'))
