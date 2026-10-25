extends Node
## Test du tutoriel d'Ysolde : chaque étape, de la cueillette au village.
var failures := 0
func _ready() -> void:
	_start.call_deferred()
func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	await _run()
	print("TOTAL FAILURES: %d" % failures)
	get_tree().quit()
func _check(cond: bool, label: String) -> void:
	print(("OK   " if cond else "FAIL ") + label)
	if not cond:
		failures += 1
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func _talk(ys: Node) -> void:
	var choice := get_tree().root.get_node("Choice")
	ys.talk()
	for i in 600:
		await get_tree().process_frame
		if choice.is_open:
			choice._picked.emit(0)
		elif not ys._talking:
			break
	await _frames(3)
func _run() -> void:
	var G := get_tree().root.get_node("Game")
	var Inv := get_tree().root.get_node("Inventory")
	var Q := get_tree().root.get_node("Quests")
	var TownA := get_tree().root.get_node("Town")
	G.reset(); G.set_flag(&"prologue_done")
	get_tree().change_scene_to_file("res://scenes/levels/dracombra/dracombra.tscn")
	await get_tree().create_timer(1.0).timeout
	var city := get_tree().current_scene
	var ys := city.get_node("Ysolde")
	_check(ys != null and Q.step == 0 and Q.objective_text().contains("Ysolde"), "tuto : objectif « Parler à Ysolde »")
	await _talk(ys)
	_check(Q.step == 1, "tuto : Ysolde demande des herbes (étape %d)" % Q.step)
	Inv.add_item(Inv.item_by_id(&"herb"), 3)
	await _frames(5)
	_check(Q.step == 2, "tuto : 3 herbes, étape suivante automatique")
	Inv.add_item(Inv.item_by_id(&"wood"), 6); Inv.add_item(Inv.item_by_id(&"stone"), 5)
	await _frames(5)
	_check(Q.ready_to_report and Q.objective_text().contains("Ysolde"), "tuto : bois et pierre, retourner voir Ysolde")
	await _talk(ys)
	_check(Q.step == 3 and Q.objective_text().contains("hache"), "tuto : objectif hache et pioche")
	var Cr := get_tree().root.get_node("Crafting")
	for r in Cr.recipes_for(&"camp"):
		_check(Cr.craft(r), "feu de camp : fabrique %s" % r["out"])
	await _frames(5)
	await _talk(ys)
	_check(Q.step == 4, "tuto : outils en main, il faut réunir de quoi bâtir")
	Inv.add_item(Inv.item_by_id(&"wood"), 30); Inv.add_item(Inv.item_by_id(&"stone"), 10)
	await _frames(5)
	_check(Q.step == 5, "tuto : objectif tente")
	var t: Dictionary = TownA.add_site(&"tent", TownA.center + Vector2i(-6, 4)); t["built"] = true; TownA.changed.emit()
	await _frames(5)
	_check(Q.step == 6, "tuto : objectif établi")
	var w: Dictionary = TownA.add_site(&"workbench", TownA.center + Vector2i(6, 4)); w["built"] = true; TownA.changed.emit()
	await _frames(5)
	await _talk(ys)
	_check(Q.step == 7 and Inv.get_count(&"flax") >= 4, "tuto : Ysolde donne du lin, objectif baume")
	Inv.add_item(Inv.item_by_id(&"balm"), 1)
	await _frames(5)
	await _talk(ys)
	_check(Q.step == 8 and G.has_flag(&"ysolde_joined"), "tuto : Ysolde rejoint le camp, objectif village")
	TownA.tier = 1
	await _frames(5)
	await _talk(ys)
	_check(not Q.active() and Q.objective_text() == "", "tuto : terminé")
	# Hache : deux fois moins de coups
	var tree: Node2D = null
	for p in city.get_node("Props").get_children():
		var h := p.get_node_or_null("Harvest")
		if h and h.item_id == &"wood" and p.visible:
			tree = p
			break
	_check(tree.get_node("Harvest").hits_needed() == tree.get_node("Harvest").hits, "hache : nombre de coups normal avec la hache")
