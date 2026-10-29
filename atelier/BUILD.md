# Atelier Dracombra — sources et fabrication

Version actuelle : 1.10.0 (27/10/2026). Copie de référence des sources, rangée dans le dépôt du jeu
pour que n'importe quelle session Claude Code (Tiamat compris) puisse les lire. Le dossier contient
un `.gdignore` : Godot ne l'importe pas.

## Fichiers de ce dossier
- `src.html` : l'atelier complet (HTML/CSS/JS, un seul fichier). Le texte `__SAMPLE__` est remplacé à la
  fabrication par la planche d'exemple (`exemple_heros.webp` en base64, `data:image/webp;base64,…`).
- `main.go`, `files.go`, `update.go` : lanceur Windows en Go (serveur local 127.0.0.1:47613, fenêtre Edge/Chrome
  en mode `--app`, API projets/fichiers/export/mises à jour).
- **Manquent ici** (non retrouvés dans le Project claude.ai) : `platform_windows.go` / `platform_other.go`
  (fonctions `openWindow`, `chooseFolder`, `fileDialog`, `openFolder`, `revealFile`, `registerAssoc`, `fatal`)
  et `mkicon.py` (icône + `rsrc_windows_amd64.syso`). À réécrire si on doit recompiler le .exe.
- `publier.sh` : publie une version sur la branche `atelier-updates`.
- `GODOT.md` : ce qu'il faut faire côté Godot avec les exports.

## Fabriquer
1. Page publiée : `src.html` avec `__SAMPLE__` remplacé.
2. `index.html` du lanceur : même contenu enveloppé dans `<!doctype html><html lang="fr"><head><meta charset="utf-8">…</head><body>…</body></html>`.
3. `python3 mkicon.py` puis `GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "-H windowsgui -s -w" -o AtelierDracombra.exe .`

## API locale du .exe (http://127.0.0.1:47613, repli jusqu'à 47639)
- `GET /api/info`, `POST /api/ping` (la fenêtre envoie un battement toutes les 4 s ; arrêt 15 s après fermeture)
- `GET /api/projects`, `GET|PUT|DELETE /api/projects/<nom>` (fichiers `%APPDATA%\AtelierDracombra\projets\<nom>.json`,
  nom `^[a-z0-9_-]{1,64}$`). **Pas protégé par X-Atelier** : un outil local (Tiamat) peut s'en servir.
- `POST /api/choose-dir` (dialogue Windows), `POST /api/open-dir`, `POST /api/write?name=` (.png .tres .tscn .gd .json .txt, dans le dossier d'export choisi)
- `GET|POST /api/update` (état / lancer la vérification des mises à jour)
- `/api/file/dialog|read|write|recent|backups|reveal`, `/api/open-request` : exigent l'en-tête `X-Atelier: 1`, l'hôte `127.0.0.1:`
  et un chemin choisi par l'utilisateur (dialogue, double-clic, récents, copies de secours).

## Mises à jour automatiques (depuis 1.8.0)
Canal principal : branche **`atelier-updates`** du dépôt (lue via raw.githubusercontent.com) : `releases.json`
(format API Releases GitHub), `atelier-index.html`, `AtelierDracombra.exe`. Canal de secours : Releases GitHub `atelier-v*`.

Publier X.Y.Z : mettre `APP_VERSION` dans `src.html` (et `const version` dans `main.go` si le lanceur change),
construire `dist/release/atelier-index.html` (+ .exe), puis `./publier.sh X.Y.Z "notes"` (page seule) ou
`./publier.sh X.Y.Z "notes" X.Y.Z` (page + lanceur). Test local : `ATELIER_UPDATE_URL`, `ATELIER_NO_UPDATE`.

## Fichiers .atelier (depuis 1.10.0)
- Copies de secours : `<dossier>\sauvegardes\<nom>\<nom>_AAAA-MM-JJ_hh-mm-ss.atelier`, 10 gardées.
- Double-clic : association HKCU `.atelier` -> `AtelierDracombra.Projet`.
- Tests hors Windows : `ATELIER_TEST_FILE`, `ATELIER_TEST_OPEN`, `ATELIER_TEST_PNG`, `ATELIER_NO_WINDOW`, `ATELIER_DATA_DIR`.
