#!/bin/bash
# Reconstruit tileset + niveaux du prologue dans le projet, puis nettoie les scènes.
set -e
S=/tmp/claude-0/-home-claude/98826a0e-b8e6-5cf3-abe9-36d613febf38/scratchpad
G=$S/godot/Godot_v4.7-stable_linux.x86_64
P=/home/claude/dracombra--realm-of-pioneers
cd $S/cave
python3 make_tileset2.py $P/assets/tilesets/cave_tiles.png /tmp/claude-0/-home-claude/98826a0e-b8e6-5cf3-abe9-36d613febf38/scratchpad/cave/tileset2.png >/dev/null
cp tileset2.png $P/assets/tilesets/cave_tiles.png
cd $P
cp $S/cave/build_prologue.gd _build.gd
$G --headless --path . --import >/dev/null 2>&1 || true
$G --headless --path . -s res://_build.gd -- $S/cave/layout.txt $S/cave/lair.txt $S/cave/tunnel.txt $S/cave/tunnel_path.json $S/props/props.json $S/cave/passage.txt $S/sylve/sylve.txt $S/sylve/props_sylve.json $S/city/props_extra.json $S/city/dracombra.txt 2>&1 | grep -E "BUILD|ERROR|SCRIPT" 
rm -f _build.gd _build.gd.uid
python3 $S/cave/clean_scene.py scenes/levels/prologue/{cave_entrance,horde_tunnel,solakor_lair,wounded_passage}.tscn scenes/levels/sylve/sylve.tscn scenes/levels/dracombra/dracombra.tscn >/dev/null
