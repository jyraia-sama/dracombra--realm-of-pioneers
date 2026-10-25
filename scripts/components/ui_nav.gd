class_name UiNav
extends RefCounted
## Navigation des menus avec les touches du jeu (ZQSD, flèches, manette) :
## haut/bas pour changer de bouton, E / J / Entrée / A pour valider.
## Godot ne gère seul que les flèches et Entrée ; ceci ajoute ZQSD et les touches d'action.


## Renvoie true si l'événement a été utilisé.
static func handle(event: InputEvent, viewport: Viewport) -> bool:
	if event is InputEventMouse:
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused == null:
		return false
	var list := focused as ItemList
	if event.is_action_pressed("move_up") and not event.is_action_pressed("ui_up"):
		if list:
			_move_list(list, -1)
		else:
			_focus(focused.find_prev_valid_focus())
		return true
	if event.is_action_pressed("move_down") and not event.is_action_pressed("ui_down"):
		if list:
			_move_list(list, 1)
		else:
			_focus(focused.find_next_valid_focus())
		return true
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		var button := focused as BaseButton
		if button and not button.disabled:
			button.pressed.emit()
			return true
		if list:
			var sel := list.get_selected_items()
			if not sel.is_empty():
				list.item_activated.emit(sel[0])
			return true
	return false


static func _focus(control: Control) -> void:
	if control != null:
		control.grab_focus()


static func _move_list(list: ItemList, step: int) -> void:
	if list.item_count == 0:
		return
	var sel := list.get_selected_items()
	var i := clampi((sel[0] if not sel.is_empty() else 0) + step, 0, list.item_count - 1)
	list.select(i)
	list.item_selected.emit(i)
	list.ensure_current_is_visible()
