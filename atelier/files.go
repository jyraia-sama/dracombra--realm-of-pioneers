package main

// Fichiers choisis par l'utilisateur : Ouvrir…, Enregistrer sous…, fichiers récents,
// copies de secours (10 dernières versions dans « sauvegardes » à côté du fichier)
// et ouverture d'un .atelier par double-clic.

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var readExts = map[string]bool{".atelier": true, ".json": true, ".png": true, ".jpg": true, ".jpeg": true, ".webp": true}
var writeExts = map[string]bool{".atelier": true, ".png": true}

const maxBackups = 10

type recentItem struct {
	Path string `json:"path"`
	Name string `json:"name"`
	At   string `json:"at"`
}

type backupItem struct {
	Path string `json:"path"`
	At   string `json:"at"`
	Size int64  `json:"size"`
}

var (
	pendingOpen string
	allowed     = map[string]bool{} // chemins choisis par l'utilisateur pendant cette session
)

func normPath(p string) string { return strings.ToLower(filepath.Clean(p)) }

func allow(p string) { allowed[normPath(p)] = true }

// isAllowed : chemin choisi dans une boîte de dialogue, ouvert par double-clic, récent, ou copie de secours de l'un d'eux.
func isAllowed(p string) bool {
	n := normPath(p)
	if allowed[n] {
		return true
	}
	for _, r := range loadRecents() {
		if normPath(r.Path) == n {
			return true
		}
	}
	for a := range allowed {
		if strings.HasPrefix(n, normPath(backupDir(a))+string(filepath.Separator)) {
			return true
		}
	}
	for _, r := range loadRecents() {
		if strings.HasPrefix(n, normPath(backupDir(r.Path))+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

func recentPath() string { return filepath.Join(dataDir, "recents.json") }

func loadRecents() []recentItem {
	var l []recentItem
	if b, err := os.ReadFile(recentPath()); err == nil {
		_ = json.Unmarshal(b, &l)
	}
	return l
}

func addRecent(p string) {
	l := loadRecents()
	out := []recentItem{{Path: p, Name: filepath.Base(p), At: time.Now().Format(time.RFC3339)}}
	for _, r := range l {
		if normPath(r.Path) != normPath(p) && len(out) < 10 {
			out = append(out, r)
		}
	}
	if b, err := json.MarshalIndent(out, "", " "); err == nil {
		_ = os.WriteFile(recentPath(), b, 0o644)
	}
}

func backupDir(p string) string {
	stem := strings.TrimSuffix(filepath.Base(p), filepath.Ext(p))
	return filepath.Join(filepath.Dir(p), "sauvegardes", stem)
}

func listBackups(p string) []backupItem {
	ents, _ := os.ReadDir(backupDir(p))
	var out []backupItem
	for _, e := range ents {
		if e.IsDir() || !strings.EqualFold(filepath.Ext(e.Name()), ".atelier") {
			continue
		}
		if fi, err := e.Info(); err == nil {
			out = append(out, backupItem{Path: filepath.Join(backupDir(p), e.Name()), At: fi.ModTime().Format(time.RFC3339), Size: fi.Size()})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].At > out[j].At })
	return out
}

// makeBackup copie la version actuelle du fichier avant de l'écraser.
// force = enregistrement à la main ; sinon (sauvegarde automatique) au plus une copie toutes les 5 minutes.
func makeBackup(p string, force bool) {
	old, err := os.ReadFile(p)
	if err != nil {
		return
	}
	l := listBackups(p)
	if !force && len(l) > 0 {
		if t, err := time.Parse(time.RFC3339, l[0].At); err == nil && time.Since(t) < 5*time.Minute {
			return
		}
	}
	bd := backupDir(p)
	if os.MkdirAll(bd, 0o755) != nil {
		return
	}
	stem := strings.TrimSuffix(filepath.Base(p), filepath.Ext(p))
	_ = os.WriteFile(filepath.Join(bd, stem+"_"+time.Now().Format("2006-01-02_15-04-05")+".atelier"), old, 0o644)
	l = listBackups(p)
	for i := maxBackups; i < len(l); i++ {
		_ = os.Remove(l[i].Path)
	}
}

func writeAtomic(p string, b []byte) error {
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}

// guard : seules les requêtes de la page de l'atelier elle-même sont acceptées
// (en-tête X-Atelier, que les autres sites ne peuvent pas envoyer sans autorisation CORS).
func guard(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Atelier") != "1" || !strings.HasPrefix(r.Host, "127.0.0.1:") {
			http.Error(w, "refusé", http.StatusForbidden)
			return
		}
		if o := r.Header.Get("Origin"); o != "" && o != "http://"+r.Host {
			http.Error(w, "refusé", http.StatusForbidden)
			return
		}
		h(w, r)
	}
}

func fileRoutes(m *http.ServeMux) {
	m.HandleFunc("/api/file/dialog", guard(func(w http.ResponseWriter, r *http.Request) {
		var q struct{ Kind, Name, Dir string }
		_ = json.NewDecoder(io.LimitReader(r.Body, 1<<16)).Decode(&q)
		p, err := fileDialog(q.Kind, q.Dir, q.Name)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if p != "" {
			mu.Lock()
			allow(p)
			mu.Unlock()
		}
		writeJSON(w, map[string]any{"path": p})
	}))
	m.HandleFunc("/api/file/read", guard(func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Query().Get("path")
		mu.Lock()
		ok := filepath.IsAbs(p) && readExts[strings.ToLower(filepath.Ext(p))] && isAllowed(p)
		mu.Unlock()
		if !ok {
			http.Error(w, "fichier refusé", http.StatusForbidden)
			return
		}
		b, err := os.ReadFile(p)
		if err != nil {
			http.Error(w, "fichier introuvable : "+p, http.StatusNotFound)
			return
		}
		if e := strings.ToLower(filepath.Ext(p)); (e == ".atelier" || e == ".json") && !strings.Contains(normPath(p), string(filepath.Separator)+"sauvegardes"+string(filepath.Separator)) {
			mu.Lock()
			addRecent(p)
			mu.Unlock()
		}
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write(b)
	}))
	m.HandleFunc("/api/file/write", guard(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST attendu", http.StatusMethodNotAllowed)
			return
		}
		p := r.URL.Query().Get("path")
		ext := strings.ToLower(filepath.Ext(p))
		mu.Lock()
		ok := filepath.IsAbs(p) && writeExts[ext] && isAllowed(p)
		mu.Unlock()
		if !ok {
			http.Error(w, "écriture refusée : choisis le fichier avec « Enregistrer sous… »", http.StatusForbidden)
			return
		}
		b, err := io.ReadAll(io.LimitReader(r.Body, 768<<20))
		if err != nil || len(b) == 0 {
			http.Error(w, "contenu vide", http.StatusBadRequest)
			return
		}
		if ext == ".atelier" && !json.Valid(b) {
			http.Error(w, "projet illisible", http.StatusBadRequest)
			return
		}
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		mu.Lock()
		defer mu.Unlock()
		if ext == ".atelier" {
			makeBackup(p, r.URL.Query().Get("backup") == "1")
		}
		if err := writeAtomic(p, b); err != nil {
			http.Error(w, "écriture impossible : "+err.Error(), http.StatusInternalServerError)
			return
		}
		if ext == ".atelier" {
			addRecent(p)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	m.HandleFunc("/api/file/recent", guard(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		l := loadRecents()
		mu.Unlock()
		out := []recentItem{}
		for _, it := range l {
			if _, err := os.Stat(it.Path); err == nil {
				out = append(out, it)
			}
		}
		writeJSON(w, out)
	}))
	m.HandleFunc("/api/file/backups", guard(func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Query().Get("path")
		out := listBackups(p)
		if out == nil {
			out = []backupItem{}
		}
		writeJSON(w, out)
	}))
	m.HandleFunc("/api/file/reveal", guard(func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Query().Get("path")
		mu.Lock()
		ok := isAllowed(p)
		mu.Unlock()
		if ok {
			revealFile(p)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	// un deuxième lancement (double-clic sur un .atelier) confie le fichier à l'atelier déjà ouvert
	m.HandleFunc("/api/open-request", guard(func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Query().Get("path")
		if p == "" {
			http.Error(w, "chemin manquant", http.StatusBadRequest)
			return
		}
		mu.Lock()
		allow(p)
		pendingOpen = p
		mu.Unlock()
		w.WriteHeader(http.StatusNoContent)
	}))
}

// takePending renvoie (une seule fois) le fichier à ouvrir demandé par un double-clic.
func takePending() string {
	mu.Lock()
	defer mu.Unlock()
	p := pendingOpen
	pendingOpen = ""
	return p
}

// handOff : si un atelier tourne déjà, lui confier le fichier et s'arrêter.
func handOff(path string) bool {
	c := &http.Client{Timeout: 2 * time.Second}
	for p := 47613; p < 47616; p++ {
		base := "http://127.0.0.1:" + itoa(p)
		req, _ := http.NewRequest(http.MethodPost, base+"/api/open-request?path="+urlEscape(path), nil)
		req.Header.Set("X-Atelier", "1")
		resp, err := c.Do(req)
		if err != nil {
			continue
		}
		resp.Body.Close()
		if resp.StatusCode == http.StatusNoContent {
			return true
		}
	}
	return false
}
