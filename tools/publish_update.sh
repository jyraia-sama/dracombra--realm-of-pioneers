#!/bin/bash
# Publie une mise à jour du jeu sur la branche « updates » :
#   tools/publish_update.sh 0.3.0 "Nouvelles animations du héros."
# 1. écrit la version dans project.godot (et la committe sur main),
# 2. exporte le .exe Windows et le zippe (Dracombra.zip),
# 3. remplace latest.json et Dracombra.zip sur la branche updates (une seule version gardée).
set -e
VERSION="$1"; NOTES="$2"
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
ROOT="$PWD"
sed -i "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot
git add project.godot && git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit -q -m "Version $VERSION" || true
mkdir -p build && rm -f build/Dracombra.exe build/Dracombra.zip
"$GODOT" --headless --path . --export-release "Windows" build/Dracombra.exe >/dev/null
(cd build && zip -q -9 Dracombra.zip Dracombra.exe)
SHA=$(sha256sum build/Dracombra.zip | cut -d' ' -f1)
SIZE=$(stat -c %s build/Dracombra.zip)
TMP=$(mktemp -d)
cd "$TMP" && git init -q && git checkout -q -b updates
cp "$ROOT/build/Dracombra.zip" .
python3 -c "import json,sys; json.dump({'version':sys.argv[1],'notes':sys.argv[2],'file':'Dracombra.zip','sha256':sys.argv[3],'size':int(sys.argv[4])},open('latest.json','w'),ensure_ascii=False,indent=1)" "$VERSION" "$NOTES" "$SHA" "$SIZE"
git add . && git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit -q -m "Mise à jour $VERSION"
git push -q -f "$(cd "$ROOT" && git remote get-url origin)" updates
echo "Publié : $VERSION ($SIZE octets)"
