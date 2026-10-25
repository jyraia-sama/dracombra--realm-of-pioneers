extends Node
## Mises à jour du jeu (version .exe).
##
## Les nouvelles versions sont publiées sur la branche « updates » du dépôt GitHub :
## latest.json (version, notes, empreinte) et Dracombra.zip (le nouveau .exe).
##
## À l'écran titre, le jeu compare sa version à latest.json. Si une version plus récente
## existe, le joueur peut la télécharger : le zip est vérifié, l'ancien .exe est renommé
## en .old (Windows autorise à renommer un programme en cours d'exécution), le nouveau
## prend sa place, et le jeu redémarre dessus. L'ancien fichier est effacé au lancement
## suivant.

signal status_changed(text: String)
signal update_available(version: String, notes: String)
signal progress(ratio: float)
signal ready_to_restart

const BASE_URL := "https://raw.githubusercontent.com/jyraia-sama/dracombra--realm-of-pioneers/updates/"
const DIR := "user://update/"

## Adresse des mises à jour (remplaçable pour les tests : « -- --update-url=http://... »).
var base_url := BASE_URL
var manifest: Dictionary = {}
var busy := false
var _download: HTTPRequest
## Chemin du programme, retenu au démarrage : une fois le fichier renommé, le système
## donnerait le nouveau nom de l'ancien programme.
var _exe := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_exe = OS.get_executable_path()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--update-url="):
			base_url = a.trim_prefix("--update-url=")
	if not can_update():
		return
	_remove_old_exe()
	# Vérification de bout en bout (outil de test : « -- --update-selftest »).
	if OS.get_cmdline_user_args().has("--update-selftest"):
		print("UPDATER version=%s" % version())
		DirAccess.make_dir_recursive_absolute(DIR)
		var f := FileAccess.open(DIR.path_join("selftest.txt"), FileAccess.WRITE)
		if f:
			f.store_string(version())
			f.close()
		# Une seule mise à jour par test : après le redémarrage, on s'arrête.
		if OS.get_cmdline_user_args().has("--after-update"):
			get_tree().quit()
			return
		update_available.connect(func(_v: String, _n: String) -> void: download())
		ready_to_restart.connect(restart)
		status_changed.connect(func(t: String) -> void:
			print("UPDATER ", t)
			if t.ends_with("à jour.") or t.contains("impossible") or t.contains("échoué"):
				get_tree().quit())
		check.call_deferred()


## Les mises à jour ne concernent que le jeu exporté (.exe), pas l'éditeur Godot.
func can_update() -> bool:
	return OS.has_feature("template") and OS.has_feature("pc")


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


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
			status_changed.emit("Nouvelle version disponible : %s" % latest)
			update_available.emit(latest, str(data.get("notes", "")))
		else:
			status_changed.emit("Version %s — le jeu est à jour." % version()))
	req.request(base_url + "latest.json", PackedStringArray(["Cache-Control: no-cache"]))


## Télécharge et installe la version annoncée par check().
func download() -> void:
	if busy or manifest.is_empty():
		return
	busy = true
	DirAccess.make_dir_recursive_absolute(DIR)
	var zip_path := DIR.path_join("update.zip")
	_download = HTTPRequest.new()
	_download.download_file = zip_path
	_download.timeout = 900.0
	add_child(_download)
	status_changed.emit("Téléchargement de la version %s..." % manifest["version"])
	_download.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		_download.queue_free()
		_download = null
		busy = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			DirAccess.remove_absolute(zip_path)
			status_changed.emit("Le téléchargement a échoué. Réessayez plus tard.")
			return
		var expected := str(manifest.get("sha256", ""))
		if expected != "" and FileAccess.get_sha256(zip_path) != expected:
			DirAccess.remove_absolute(zip_path)
			status_changed.emit("Le fichier téléchargé est abîmé. Réessayez.")
			return
		var err := _install(zip_path)
		DirAccess.remove_absolute(zip_path)
		if err != "":
			status_changed.emit(err)
			return
		status_changed.emit("Version %s installée." % manifest["version"])
		ready_to_restart.emit())
	_download.request(base_url + str(manifest.get("file", "Dracombra.zip")))


## Remplace le programme : l'ancien est renommé, le nouveau prend sa place.
func _install(zip_path: String) -> String:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return "Le fichier téléchargé est illisible."
	var files := zip.get_files()
	if files.is_empty():
		return "Le fichier téléchargé est vide."
	var data := zip.read_file(files[0])
	zip.close()
	if data.is_empty():
		return "Le fichier téléchargé est vide."
	var exe := _exe
	var old := _old_path()
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(exe, old) != OK:
		return "Impossible de remplacer le jeu (dossier protégé ?). Déplacez le jeu dans Documents."
	var f := FileAccess.open(exe, FileAccess.WRITE)
	if f == null:
		DirAccess.rename_absolute(old, exe)
		return "Impossible d'écrire le nouveau jeu."
	f.store_buffer(data)
	f.close()
	if not OS.has_feature("windows"):
		OS.execute("chmod", ["+x", exe])
	return ""


func _old_path() -> String:
	var exe := _exe
	if exe.get_extension() == "":
		return exe + ".old"
	return exe.get_basename() + ".old." + exe.get_extension()


func _remove_old_exe() -> void:
	var old := _old_path()
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)


func _process(_delta: float) -> void:
	if _download and _download.get_body_size() > 0:
		progress.emit(float(_download.get_downloaded_bytes()) / float(_download.get_body_size()))


## Relance le jeu (le nouveau programme) et ferme celui-ci.
func restart() -> void:
	var args := PackedStringArray()
	if OS.get_cmdline_user_args().has("--update-selftest"):
		args.append_array(["--headless", "--"])
		for a in OS.get_cmdline_user_args():
			args.append(a)
		args.append("--after-update")
	OS.create_process(_exe, args)
	get_tree().quit()
