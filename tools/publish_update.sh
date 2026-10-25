#!/bin/bash
# Publie une mise à jour du jeu sur la branche « updates » :
#   tools/publish_update.sh 0.3.0 "Nouvelles animations du héros."
# 1. écrit la version dans project.godot (et la committe sur main),
# 2. exporte le contenu du jeu (Dracombra.pck, sans le moteur),
# 3. remplace latest.json et Dracombra.pck sur la branche updates (une seule version gardée).
set -e
VERSION="$1"; NOTES="$2"
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
sed -i "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot
git add project.godot && git commit -q -m "Version $VERSION" || true
mkdir -p build
"$GODOT" --headless --path . --export-pack "Windows" build/Dracombra.pck >/dev/null
SHA=$(sha256sum build/Dracombra.pck | cut -d' ' -f1)
SIZE=$(stat -c %s build/Dracombra.pck)
TMP=$(mktemp -d)
cd "$TMP" && git init -q && git checkout -q -b updates
cp "$OLDPWD/build/Dracombra.pck" .
python3 -c "import json,sys; json.dump({'version':sys.argv[1],'notes':sys.argv[2],'pack':'Dracombra.pck','sha256':sys.argv[3],'size':int(sys.argv[4])},open('latest.json','w'),ensure_ascii=False,indent=1)" "$VERSION" "$NOTES" "$SHA" "$SIZE"
git add . && git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit -q -m "Mise à jour $VERSION"
git push -q -f "$(cd "$OLDPWD" && git remote get-url origin)" updates
echo "Publié : $VERSION ($SIZE octets)"
