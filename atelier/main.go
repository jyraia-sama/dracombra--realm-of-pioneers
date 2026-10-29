// Atelier Dracombra : lanceur Windows.
// Sert l'atelier (page HTML embarquée) sur 127.0.0.1 et l'ouvre dans une fenêtre
// d'application Edge/Chrome. Fournit une petite API locale pour enregistrer le
// projet sur le disque et exporter directement dans le dossier du jeu Godot.
package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

//go:embed index.html
var page []byte

const appName = "AtelierDracombra"

type config struct {
	ExportDir string `json:"exportDir"`
}

var (
	mu       sync.Mutex
	cfg      config
	dataDir  string
	lastPing = time.Now()
)

func cfgPath() string { return filepath.Join(dataDir, "config.json") }
func projDir() string { return filepath.Join(dataDir, "projets") }

var projName = regexp.MustCompile(`^[a-z0-9_-]{1,64}$`)

type projInfo struct {
	Name    string `json:"name"`
	SavedAt string `json:"savedAt"`
	Size    int64  `json:"size"`
	Thumb   string `json:"thumb"`
	Type    string `json:"type"`
}

func sessionPath() string { return filepath.Join(dataDir, "session.json") }

func loadCfg() {
	b, err := os.ReadFile(cfgPath())
	if err == nil {
		_ = json.Unmarshal(b, &cfg)
	}
}
func saveCfg() error {
	b, _ := json.MarshalIndent(cfg, "", "  ")
	return os.WriteFile(cfgPath(), b, 0o644)
}

// resPathFor cherche project.godot en remontant depuis dir et renvoie le chemin res:// équivalent.
func resPathFor(dir string) string {
	d := dir
	for i := 0; i < 12; i++ {
		if _, err := os.Stat(filepath.Join(d, "project.godot")); err == nil {
			rel, err := filepath.Rel(d, dir)
			if err != nil {
				return ""
			}
			rel = filepath.ToSlash(rel)
			if rel == "." {
				return "res://"
			}
			return "res://" + strings.Trim(rel, "/") + "/"
		}
		parent := filepath.Dir(d)
		if parent == d {
			break
		}
		d = parent
	}
	return ""
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(v)
}

func routes() *http.ServeMux {
	m := http.NewServeMux()
	m.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" && r.URL.Path != "/index.html" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		b, _ := currentPage()
		_, _ = w.Write(b)
	})
	m.HandleFunc("/api/info", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		_, pv := currentPage()
		writeJSON(w, map[string]any{"app": true, "version": pv, "launcher": launcherVersion, "exportDir": cfg.ExportDir, "resPath": resPathFor(cfg.ExportDir), "files": true})
	})
	m.HandleFunc("/api/ping", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		lastPing = time.Now()
		mu.Unlock()
		if p := takePending(); p != "" {
			writeJSON(w, map[string]any{"open": p})
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
	m.HandleFunc("/api/session", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			b, err := os.ReadFile(sessionPath())
			if err != nil {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
			_, _ = w.Write(b)
		case http.MethodPut, http.MethodPost:
			b, err := io.ReadAll(io.LimitReader(r.Body, 512<<20))
			if err != nil || !json.Valid(b) {
				http.Error(w, "projet illisible", http.StatusBadRequest)
				return
			}
			tmp := sessionPath() + ".tmp"
			if err := os.WriteFile(tmp, b, 0o644); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			if err := os.Rename(tmp, sessionPath()); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			http.Error(w, "méthode non prise en charge", http.StatusMethodNotAllowed)
		}
	})
	m.HandleFunc("/api/projects", func(w http.ResponseWriter, r *http.Request) {
		entries, _ := os.ReadDir(projDir())
		list := []projInfo{}
		for _, e := range entries {
			n := e.Name()
			if e.IsDir() || !strings.HasSuffix(n, ".json") {
				continue
			}
			name := strings.TrimSuffix(n, ".json")
			if !projName.MatchString(name) {
				continue
			}
			fi, err := e.Info()
			if err != nil {
				continue
			}
			th, _ := os.ReadFile(filepath.Join(projDir(), name+".thumb.txt"))
			ty, _ := os.ReadFile(filepath.Join(projDir(), name+".type.txt"))
			list = append(list, projInfo{Name: name, SavedAt: fi.ModTime().UTC().Format(time.RFC3339), Size: fi.Size(), Thumb: string(th), Type: string(ty)})
		}
		sort.Slice(list, func(i, j int) bool { return list[i].SavedAt > list[j].SavedAt })
		writeJSON(w, list)
	})
	m.HandleFunc("/api/projects/", func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(r.URL.Path, "/api/projects/")
		if !projName.MatchString(name) {
			http.Error(w, "nom de projet refusé : "+name, http.StatusBadRequest)
			return
		}
		file := filepath.Join(projDir(), name+".json")
		switch r.Method {
		case http.MethodGet:
			b, err := os.ReadFile(file)
			if err != nil {
				http.Error(w, "projet introuvable", http.StatusNotFound)
				return
			}
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
			_, _ = w.Write(b)
		case http.MethodPut:
			b, err := io.ReadAll(io.LimitReader(r.Body, 512<<20))
			if err != nil || !json.Valid(b) {
				http.Error(w, "projet illisible", http.StatusBadRequest)
				return
			}
			var meta struct {
				Thumb string `json:"thumb"`
				Type  string `json:"type"`
			}
			_ = json.Unmarshal(b, &meta)
			if err := os.MkdirAll(projDir(), 0o755); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			tmp := file + ".tmp"
			if err := os.WriteFile(tmp, b, 0o644); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			if err := os.Rename(tmp, file); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			if strings.HasPrefix(meta.Thumb, "data:image/") && len(meta.Thumb) < 400000 {
				_ = os.WriteFile(filepath.Join(projDir(), name+".thumb.txt"), []byte(meta.Thumb), 0o644)
			}
			if meta.Type != "" && len(meta.Type) < 32 {
				_ = os.WriteFile(filepath.Join(projDir(), name+".type.txt"), []byte(meta.Type), 0o644)
			}
			w.WriteHeader(http.StatusNoContent)
		case http.MethodDelete:
			_ = os.Remove(filepath.Join(projDir(), name+".thumb.txt"))
			_ = os.Remove(filepath.Join(projDir(), name+".type.txt"))
			if err := os.Remove(file); err != nil {
				http.Error(w, "projet introuvable", http.StatusNotFound)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			http.Error(w, "méthode non prise en charge", http.StatusMethodNotAllowed)
		}
	})
	m.HandleFunc("/api/choose-dir", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST attendu", http.StatusMethodNotAllowed)
			return
		}
		mu.Lock()
		start := cfg.ExportDir
		mu.Unlock()
		dir, err := chooseFolder(start)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if dir == "" {
			writeJSON(w, map[string]any{"dir": ""})
			return
		}
		mu.Lock()
		cfg.ExportDir = dir
		_ = saveCfg()
		mu.Unlock()
		writeJSON(w, map[string]any{"dir": dir, "resPath": resPathFor(dir)})
	})
	m.HandleFunc("/api/open-dir", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		dir := cfg.ExportDir
		mu.Unlock()
		if dir == "" {
			http.Error(w, "aucun dossier choisi", http.StatusBadRequest)
			return
		}
		openFolder(dir)
		w.WriteHeader(http.StatusNoContent)
	})
	m.HandleFunc("/api/write", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST attendu", http.StatusMethodNotAllowed)
			return
		}
		name := r.URL.Query().Get("name")
		if name == "" || name != filepath.Base(name) || strings.ContainsAny(name, `/\:*?"<>|`) || strings.HasPrefix(name, ".") {
			http.Error(w, "nom de fichier refusé : "+name, http.StatusBadRequest)
			return
		}
		ext := strings.ToLower(filepath.Ext(name))
		if ext != ".png" && ext != ".tres" && ext != ".tscn" && ext != ".gd" && ext != ".json" && ext != ".txt" {
			http.Error(w, "type de fichier refusé : "+ext, http.StatusBadRequest)
			return
		}
		mu.Lock()
		dir := cfg.ExportDir
		mu.Unlock()
		if dir == "" {
			http.Error(w, "aucun dossier d'export choisi", http.StatusBadRequest)
			return
		}
		b, err := io.ReadAll(io.LimitReader(r.Body, 256<<20))
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if err := os.MkdirAll(dir, 0o755); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if err := os.WriteFile(filepath.Join(dir, name), b, 0o644); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
	updateRoutes(m)
	fileRoutes(m)
	return m
}

const version = "1.10.0"

func main() {
	base, err := os.UserConfigDir()
	if err != nil {
		base = "."
	}
	dataDir = filepath.Join(base, appName)
	if v := os.Getenv("ATELIER_DATA_DIR"); v != "" {
		dataDir = v
	}
	_ = os.MkdirAll(dataDir, 0o755)
	loadCfg()
	// double-clic sur un .atelier : le confier à l'atelier déjà ouvert s'il y en a un
	if len(os.Args) > 1 {
		if abs, err := filepath.Abs(os.Args[1]); err == nil {
			if handOff(abs) {
				return
			}
			allow(abs)
			pendingOpen = abs
		}
	}
	go registerAssoc()
	cleanupOld()
	loadPage()

	// Port fixe (l'origine reste la même d'un lancement à l'autre), avec repli.
	var ln net.Listener
	for p := 47613; p < 47640; p++ {
		ln, err = net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", p))
		if err == nil {
			break
		}
	}
	if ln == nil {
		fatal("Impossible d'ouvrir un port local pour l'atelier.")
	}
	url := "http://" + ln.Addr().String() + "/"
	srv := &http.Server{Handler: routes()}
	go func() { _ = srv.Serve(ln) }()
	if os.Getenv("ATELIER_NO_UPDATE") == "" {
		go func() { time.Sleep(3 * time.Second); checkUpdate() }()
	}

	if os.Getenv("ATELIER_NO_WINDOW") != "" { // mode test
		fmt.Println(url)
		select {}
	}

	exited := make(chan struct{})
	go func() {
		openWindow(url, dataDir)
		close(exited)
	}()

	// Fermeture : quand la fenêtre est fermée et que la page ne donne plus signe de vie.
	started := time.Now()
	for {
		time.Sleep(2 * time.Second)
		select {
		case <-exited:
		default:
			continue
		}
		mu.Lock()
		idle := time.Since(lastPing)
		mu.Unlock()
		if idle > 15*time.Second && time.Since(started) > 45*time.Second {
			os.Exit(0)
		}
	}
}

func itoa(n int) string         { return strconv.Itoa(n) }
func urlEscape(s string) string { return url.QueryEscape(s) }
