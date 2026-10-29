package main

// Mises à jour automatiques.
// Canal principal : branche « atelier-updates » du dépôt du jeu (releases.json au format de
// l'API Releases GitHub). Canal de secours : Releases GitHub dont l'étiquette commence par
// « atelier-v ». Fichiers : atelier-index.html (la page, presque toutes les mises à jour) et
// AtelierDracombra.exe (le lanceur, seulement si la description contient « launcher: X.Y.Z »).
// La page téléchargée est rangée dans %APPDATA%\AtelierDracombra\app et servie à la place
// de la page intégrée. Le .exe est remplacé sur place (l'ancien est renommé en .old).

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	launcherVersion = version // version du .exe
	defaultFeed     = "https://raw.githubusercontent.com/jyraia-sama/dracombra--realm-of-pioneers/atelier-updates/releases.json"
	releasesFeed    = "https://api.github.com/repos/jyraia-sama/dracombra--realm-of-pioneers/releases?per_page=30"
	tagPrefix       = "atelier-v"
)

type updState struct {
	State    string `json:"state"`    // aucune, verification, a_jour, telechargement, pret, relancer, erreur
	Message  string `json:"message"`  // texte pour l'utilisateur
	Latest   string `json:"latest"`   // dernière version publiée
	Notes    string `json:"notes"`    // description de la release
	Checked  string `json:"checked"`  // date de la vérification
	Launcher string `json:"launcher"` // version du lanceur
	Page     string `json:"page"`     // version de la page servie
}

var (
	updMu  sync.Mutex
	upd    = updState{State: "aucune", Launcher: launcherVersion}
	pageMu sync.RWMutex
	pageV  = version
	pageB  []byte
)

func appDir() string { return filepath.Join(dataDir, "app") }

// parseV transforme "1.8.0" en nombres comparables.
func parseV(s string) [3]int {
	var v [3]int
	for i, p := range strings.SplitN(strings.TrimPrefix(strings.TrimSpace(s), "v"), ".", 3) {
		n, _ := strconv.Atoi(strings.TrimFunc(p, func(r rune) bool { return r < '0' || r > '9' }))
		v[i] = n
	}
	return v
}
func newer(a, b string) bool { // a > b ?
	x, y := parseV(a), parseV(b)
	for i := 0; i < 3; i++ {
		if x[i] != y[i] {
			return x[i] > y[i]
		}
	}
	return false
}

// loadPage choisit la page la plus récente : intégrée au .exe ou téléchargée.
func loadPage() {
	pageMu.Lock()
	defer pageMu.Unlock()
	pageB, pageV = page, version
	vb, err1 := os.ReadFile(filepath.Join(appDir(), "version.txt"))
	hb, err2 := os.ReadFile(filepath.Join(appDir(), "index.html"))
	if err1 == nil && err2 == nil && len(hb) > 1000 && newer(string(vb), version) {
		pageB, pageV = hb, strings.TrimSpace(string(vb))
	}
}
func currentPage() ([]byte, string) {
	pageMu.RLock()
	defer pageMu.RUnlock()
	return pageB, pageV
}

func setUpd(f func(*updState)) {
	updMu.Lock()
	f(&upd)
	updMu.Unlock()
}
func getUpd() updState {
	updMu.Lock()
	defer updMu.Unlock()
	s := upd
	_, s.Page = currentPage()
	return s
}

type release struct {
	Tag    string `json:"tag_name"`
	Body   string `json:"body"`
	Draft  bool   `json:"draft"`
	Pre    bool   `json:"prerelease"`
	Assets []struct {
		Name string `json:"name"`
		URL  string `json:"browser_download_url"`
	} `json:"assets"`
}

var launcherRe = regexp.MustCompile(`(?i)launcher\s*:\s*v?(\d+\.\d+\.\d+)`)
var updClient = &http.Client{Timeout: 90 * time.Second}

func fetch(url string, max int64) ([]byte, error) {
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", "AtelierDracombra/"+launcherVersion)
	req.Header.Set("Accept", "application/vnd.github+json")
	res, err := updClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return nil, fmt.Errorf("réponse %d", res.StatusCode)
	}
	return io.ReadAll(io.LimitReader(res.Body, max))
}

var checking sync.Mutex

// checkUpdate cherche la dernière version publiée et l'installe si elle est plus récente.
func checkUpdate() {
	if !checking.TryLock() {
		return
	}
	defer checking.Unlock()
	setUpd(func(u *updState) { u.State, u.Message = "verification", "Recherche d'une mise à jour…" })
	err := doUpdate()
	if err != nil {
		setUpd(func(u *updState) {
			u.State, u.Message = "erreur", "Mise à jour impossible pour l'instant : "+err.Error()
		})
	}
	setUpd(func(u *updState) { u.Checked = time.Now().Format(time.RFC3339) })
}

func doUpdate() error {
	feed := defaultFeed
	if v := os.Getenv("ATELIER_UPDATE_URL"); v != "" {
		feed = v
	}
	feeds := []string{feed}
	if os.Getenv("ATELIER_UPDATE_URL") == "" {
		feeds = append(feeds, releasesFeed)
	}
	var rels []release
	var lastErr error
	ok := false
	for _, f := range feeds {
		b, err := fetch(f+cacheBust(f), 4<<20)
		if err != nil {
			lastErr = err
			continue
		}
		var part []release
		if err := json.Unmarshal(b, &part); err != nil {
			lastErr = errors.New("réponse illisible")
			continue
		}
		ok = true
		rels = append(rels, part...)
	}
	if !ok {
		return errors.New("pas de connexion au serveur des mises à jour (" + lastErr.Error() + ")")
	}
	var best *release
	for i := range rels {
		r := &rels[i]
		if r.Draft || r.Pre || !strings.HasPrefix(r.Tag, tagPrefix) {
			continue
		}
		if best == nil || newer(strings.TrimPrefix(r.Tag, tagPrefix), strings.TrimPrefix(best.Tag, tagPrefix)) {
			best = r
		}
	}
	_, curPage := currentPage()
	if best == nil {
		setUpd(func(u *updState) { u.State, u.Message = "a_jour", "Aucune mise à jour publiée pour l'instant." })
		return nil
	}
	latest := strings.TrimPrefix(best.Tag, tagPrefix)
	setUpd(func(u *updState) { u.Latest, u.Notes = latest, best.Body })
	asset := func(name string) string {
		for _, a := range best.Assets {
			if strings.EqualFold(a.Name, name) {
				return a.URL
			}
		}
		return ""
	}
	needLauncher := false
	if m := launcherRe.FindStringSubmatch(best.Body); m != nil && newer(m[1], launcherVersion) {
		needLauncher = true
	}
	if !newer(latest, curPage) && !needLauncher {
		setUpd(func(u *updState) { u.State, u.Message = "a_jour", "L'Atelier est à jour (version "+curPage+")." })
		return nil
	}
	setUpd(func(u *updState) {
		u.State, u.Message = "telechargement", "Téléchargement de la version "+latest+"…"
	})
	_ = os.MkdirAll(appDir(), 0o755)
	// 1. la page
	if newer(latest, curPage) {
		u := asset("atelier-index.html")
		if u == "" {
			return errors.New("la version " + latest + " ne contient pas atelier-index.html")
		}
		html, err := fetch(u, 64<<20)
		if err != nil {
			return errors.New("téléchargement interrompu (" + err.Error() + ")")
		}
		if len(html) < 1000 || !strings.Contains(string(html[:min(len(html), 20000)]), "Atelier Dracombra") {
			return errors.New("fichier reçu incorrect")
		}
		tmp := filepath.Join(appDir(), "index.html.tmp")
		if err := os.WriteFile(tmp, html, 0o644); err != nil {
			return err
		}
		if err := os.Rename(tmp, filepath.Join(appDir(), "index.html")); err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(appDir(), "version.txt"), []byte(latest), 0o644); err != nil {
			return err
		}
		loadPage()
	}
	// 2. le lanceur, si la release le demande
	if needLauncher {
		u := asset("AtelierDracombra.exe")
		if u == "" {
			return errors.New("la version " + latest + " ne contient pas le nouveau lanceur")
		}
		bin, err := fetch(u, 128<<20)
		if err != nil {
			return errors.New("téléchargement du lanceur interrompu (" + err.Error() + ")")
		}
		if err := replaceSelf(bin); err != nil {
			return errors.New("remplacement du programme impossible (" + err.Error() + ")")
		}
		setUpd(func(u *updState) {
			u.State, u.Message = "relancer", "Version "+latest+" installée. Ferme l'Atelier et rouvre-le pour terminer la mise à jour."
		})
		return nil
	}
	setUpd(func(u *updState) {
		u.State, u.Message = "pret", "Version "+latest+" installée. Recharge l'Atelier pour l'utiliser."
	})
	return nil
}

// replaceSelf remplace le .exe en cours d'exécution : Windows autorise à le renommer.
func replaceSelf(bin []byte) error {
	if len(bin) < 100000 {
		return errors.New("fichier trop petit")
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	exe, _ = filepath.EvalSymlinks(exe)
	old := exe + ".old"
	_ = os.Remove(old)
	tmp := exe + ".new"
	if err := os.WriteFile(tmp, bin, 0o755); err != nil {
		return err
	}
	if err := os.Rename(exe, old); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, exe); err != nil {
		_ = os.Rename(old, exe)
		return err
	}
	return nil
}

// cleanupOld supprime l'ancien .exe laissé par une mise à jour précédente.
func cleanupOld() {
	if exe, err := os.Executable(); err == nil {
		exe, _ = filepath.EvalSymlinks(exe)
		_ = os.Remove(exe + ".old")
	}
}

func updateRoutes(m *http.ServeMux) {
	m.HandleFunc("/api/update", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			go checkUpdate()
			time.Sleep(150 * time.Millisecond)
		}
		writeJSON(w, getUpd())
	})
}

// cacheBust évite qu'un proxy ou le cache de raw.githubusercontent.com serve un vieux releases.json.
func cacheBust(u string) string {
	if !strings.Contains(u, "raw.githubusercontent.com") {
		return ""
	}
	sep := "?"
	if strings.Contains(u, "?") {
		sep = "&"
	}
	return sep + "t=" + strconv.FormatInt(time.Now().Unix(), 10)
}
