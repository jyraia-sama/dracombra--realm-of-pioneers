#!/bin/bash
# Usage : ./publier.sh 1.9.0 "notes" [launcher]
# Publie dist/release/* sur la branche atelier-updates (releases.json au format API GitHub).
set -e
V="$1"; NOTES="$2"; L="$3"
R=https://raw.githubusercontent.com/jyraia-sama/dracombra--realm-of-pioneers/atelier-updates
B=/home/claude/upd-branch
cd "$B" && git pull -q --rebase origin atelier-updates || true
cp /home/claude/atelier-exe/dist/release/atelier-index.html "$B/"
[ -n "$L" ] && cp /home/claude/atelier-exe/dist/release/AtelierDracombra.exe "$B/"
BODY="$NOTES"; [ -n "$L" ] && BODY="$NOTES

launcher: $L"
python3 - "$V" "$BODY" "$R" "$B" <<'PY'
import json,sys,os
v,body,r,b=sys.argv[1:]
assets=[{"name":"atelier-index.html","browser_download_url":f"{r}/atelier-index.html?v={v}"}]
if os.path.exists(f"{b}/AtelierDracombra.exe") and "launcher:" in body:
    assets.append({"name":"AtelierDracombra.exe","browser_download_url":f"{r}/AtelierDracombra.exe?v={v}"})
json.dump([{"tag_name":"atelier-v"+v,"name":"Atelier Dracombra "+v,"body":body,"draft":False,"prerelease":False,"assets":assets}],open(f"{b}/releases.json","w"),ensure_ascii=False,indent=1)
PY
git add -A && git -c user.name="jyraia-sama" -c user.email="neoangel21.lb@gmail.com" commit -qm "Atelier $V" && git push -q origin atelier-updates && echo "publié $V"
