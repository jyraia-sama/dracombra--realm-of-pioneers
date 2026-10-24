import re, sys
for p in sys.argv[1:]:
    s=open(p,encoding='utf-8').read()
    blocks=s.split('\n\n'); out=[]
    for b in blocks:
        if b.startswith('[node') and 'instance=ExtResource' in b:
            lines=b.split('\n')
            head=re.sub(r' type="[^"]+"','',lines[0])
            body=[l for l in lines[1:] if l.startswith('position = ') or l.startswith('scale = ')]
            b='\n'.join([head]+body)
        out.append(b)
    s='\n\n'.join(out)
    for m in re.findall(r'\[ext_resource [^\n]*id="([^"]+)"\]\n', s):
        if 'ExtResource("%s")'%m not in s:
            s=re.sub(r'\[ext_resource [^\n]*id="%s"\]\n'%re.escape(m),'',s)
    open(p,'w',encoding='utf-8').write(s)
    print(p, 'ok')
