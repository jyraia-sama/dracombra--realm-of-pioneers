extends Node
## Mises à jour du jeu (version .exe).
##
## Le .exe contient le moteur et une version du jeu. Les nouvelles versions sont publiées
## sur la branche « updates » du dépôt GitHub : latest.json (numéro de version, notes,
## empreinte) et Dracombra.pck (tout le contenu du jeu, sans le moteur).
##
## À l'écran titre, le jeu compare sa version à latest.json. Si elle est plus ancienne, le
## joueur peut télécharger le .pck, rangé dans son dossier utilisateur. Au lancement
## suivant (ou en redémarrant tout de suite), le .exe relance le moteur sur ce .pck
## (option --main-pack) au lieu de la version qu'il contient.

signal status_changed(text: String)
signal update_available(version: String, notes: String)
signal progress(ratio: float)
signal ready_to_restart

const BASE_URL := "https://raw.githubusercontent.com/jyraia-sama/dracombra--realm-of-pioneers/updates/"
const MANIFEST := BASE_URL + "latest.json"
const DIR := "user://update/"
const PACK := DIR + "Dracombra.pck"
const PACK_VERSION := DIR + "version.txt"

var manifest: Dictionary = {}
var busy := false
var _download: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not can_update():
		return
	# Une version plus récente a déjà été téléchargée : on relance le jeu dessus.
	var installed := installed_version()
	if not running_update() and installed != "" and is_newer(installed, version()):
		_relaunch()
		return
	# Vérification automatique de bout en bout (outil de test : « -- --update-selftest »).
	if OS.get_cmdline_user_args().has("--update-selftest"):
		print("UPDATER version=%s update=%s" % [version(), running_update()])
		if running_update():
			get_tree().quit()
			return
		update_available.connect(func(_v: String, _n: String) -> void: download())
		ready_to_restart.connect(restart)
		status_changed.connect(func(t: String) -> void: print("UPDATER ", t))
		check.call_deferred()


## Les mises à jour ne concernent que le jeu exporté (.exe), pas l'éditeur Godot.
func can_update() -> bool:
	return OS.has_feature("template") and OS.has_feature("pc")


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func running_update() -> bool:
	return OS.get_cmdline_args().has("--main-pack")


func installed_version() -> String:
	if not FileAccess.file_exists(PACK) or not FileAccess.file_exists(PACK_VERSION):
		return ""
	return FileAccess.get_file_as_string(PACK_VERSION).strip_edges()


## a est-elle plus récente que b ? (« 0.3.10 » > « 0.3.9 »)
static func is_newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


## Demande la dernière version publiée.
func check() -> void:
	if busy:
		return
	if not can_update():
		status_changed.emit("Version %s (mises à jour : seulement dans le .exe)" % version())
		return
	busy = true
	status_changed.emit("Recherche de mises à jour...")
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		busy = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			status_changed.emit("Version %s (impossible de vérifier les mises à jour)" % version())
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or not data.has("version"):
			status_changed.emit("Version %s" % version())
			return
		manifest = data
		var latest := str(data["version"])
		if is_newer(latest, version()):
			if installed_version() == latest:
				status_changed.emit("Version %s téléchargée : redémarrez pour en profiter." % latest)
				ready_to_restart.emit()
			else:
				status_changed.emit("Nouvelle version disponible : %s" % latest)
				update_available.emit(latest, str(data.get("notes", "")))
		else:
			status_changed.emit("Version %s — le jeu est à jour." % version()))
	req.request(MANIFEST, PackedStringArray(["Cache-Control: no-cache"]))


## Télécharge la version annoncée par check().
func download() -> void:
	if busy or manifest.is_empty():
		return
	busy = true
	DirAccess.make_dir_recursive_absolute(DIR)
	var part := PACK + ".part"
	_download = HTTPRequest.new()
	_download.download_file = part
	_download.timeout = 600.0
	add_child(_download)
	status_changed.emit("Téléchargement de la version %s..." % manifest["version"])
	_download.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		_download.queue_free()
		_download = null
		busy = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			DirAccess.remove_absolute(part)
			status_changed.emit("Le téléchargement a échoué. Réessayez plus tard.")
			return
		# Le fichier est-il complet et intact ?
		var expected := str(manifest.get("sha256", ""))
		if expected != "" and FileAccess.get_sha256(part) != expected:
			DirAccess.remove_absolute(part)
			status_changed.emit("Le fichier téléchargé est abîmé. Réessayez.")
			return
		DirAccess.remove_absolute(PACK)
		DirAccess.rename_absolute(part, PACK)
		var f := FileAccess.open(PACK_VERSION, FileAccess.WRITE)
		f.store_string(str(manifest["version"]))
		f.close()
		status_changed.emit("Version %s installée." % manifest["version"])
		ready_to_restart.emit())
	_download.request(BASE_URL + str(manifest.get("pack", "Dracombra.pck")))


func _process(_delta: float) -> void:
	if _download and _download.get_body_size() > 0:
		progress.emit(float(_download.get_downloaded_bytes()) / float(_download.get_body_size()))


## Relance le .exe sur la version téléchargée.
func restart() -> void:
	_relaunch()


func _relaunch() -> void:
	var args := PackedStringArray(["--main-pack", ProjectSettings.globalize_path(PACK)])
	if OS.get_cmdline_user_args().has("--update-selftest"):
		args.append_array(["--headless", "--", "--update-selftest"])
	OS.create_process(OS.get_executable_path(), args)
	get_tree().quit()
