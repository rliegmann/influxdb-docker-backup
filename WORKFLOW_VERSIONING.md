# 🧩 Workflow & Versionierung – InfluxDB Docker Backup

Dieses Dokument beschreibt den automatisierten GitHub Actions Workflow, der für Tests, Versionierung, Build und Push von Docker-Images zur GitHub Container Registry (GHCR) verantwortlich ist.

---

## ⚙️ Übersicht des Workflows

**Workflow-Datei:** `.github/workflows/build.yml`  
**Workflow-Name:** `Test, Version, Build, Push`

Der Workflow wird automatisch ausgeführt, wenn:

- ein Commit in einen Branch mit `feature/*` oder `bug/*` gepusht wird  
- ein Tag im Format `vX.Y.Z` erstellt und gepusht wird  

### 🔁 Ablaufdiagramm

```text
Push → Tests → Versionierung → Docker Build & Push
```

| Typ | Beschreibung | Beispiel | Ergebnis |
|-----|---------------|-----------|-----------|
| Branch Push | Testet neue Features | `feature/add-logging` | Image mit Branch-Tag |
| Tag Push | Release mit Version | `v1.2.0` | Image mit Version + `latest` |

---

## 🧪 1. Tests (`test`)

- Führt Skript `./test/run-test.sh` aus  
- Bei **Feature-/Bug-Branches** läuft der Workflow weiter, auch wenn Tests fehlschlagen  
- Bei **Release-Tags (`v*`)** wird der Workflow bei Testfehlern **abgebrochen**

---

## 🏷️ 2. Versionierung (`bump-version`)

- Liest den aktuellen Git-Tag (z. B. `v1.2.0`) aus  
- Prüft, ob das Format gültig ist (`vX.Y.Z` oder `vX.Y.Z-suffix`)  
- Vergleicht mit dem vorherigen Tag, um sicherzustellen, dass die Version erhöht wurde  
- Schreibt den Wert (ohne führendes „v“) automatisch in das Skript `influxdb-to-file.sh`:
  ```bash
  readonly VERSION="1.2.0"
  ```

Wenn `CURRENT_TAG` und `PREVIOUS_TAG` identisch sind, schlägt der Build fehl (kein Re-Release erlaubt).

---

## 🐳 3. Docker Build & Push (`docker-build`)

### 🔹 Umgebungserkennung

Wenn der Workflow lokal mit [`act`](https://github.com/nektos/act) ausgeführt wird:
- Keine Pushes zur Registry  
- Plattform momentan auf `linux/amd64` begrenzt (MacOS)
- Beispiel:
  ```bash
  act push -j docker-build --artifact-server-path ".act/temp"
  ```

### 🔹 Docker Buildx Setup
Multiarch-Builds für:
```bash
linux/amd64, linux/arm64
```

### 🔹 Tags für Images

| Quelle | Beispiel | Ergebnis |
|---------|-----------|-----------|
| Git Tag | `v1.2.0` | `ghcr.io/rliegmann/influxdb-docker-backup:1.2.0` |
| Latest | `v1.2.0` | `ghcr.io/rliegmann/influxdb-docker-backup:latest` |
| Branch | `feature/add-logging` | `ghcr.io/rliegmann/influxdb-docker-backup:feature-add-logging` |

Das `v` wird automatisch entfernt, damit Docker-Tags sauber bleiben.

---

## 🧩 Umgebungsvariablen

| Variable | Beschreibung |
|-----------|---------------|
| `REGISTRY` | Zielregistry (`ghcr.io`) |
| `IMAGE_NAME` | Name des Images (z. B. `rliegmann/influxdb-docker-backup`) |
| `PLATFORMS` | Zielarchitekturen |
| `LOCAL` | `true` bei lokalem Build mit `act`, sonst `false` |

---


## 🚀 Release-Prozess

1. Neues Release-Tag erstellen:
   ```bash
   git tag v1.3.0
   git push origin v1.3.0
   ```

2. Der Workflow führt automatisch aus:
   - Tests
   - Versionsprüfung
   - Update der Skript-Version
   - Docker Build & Push (`1.3.0` + `latest`)

3. Image ist anschließend verfügbar unter:
   ```
   ghcr.io/rliegmann/influxdb-docker-backup:1.3.0
   ghcr.io/rliegmann/influxdb-docker-backup:latest
   ```

---

## 🧠 Tipps

- Verwende **Feature-/Bug-Branches** für Test-Builds  
- Nur **Tags im Format `vX.Y.Z`** lösen offizielle Releases aus  
- Lokale Tests mit [`act`](https://github.com/nektos/act):
  ```bash
  act push -j docker-build
  ```

---

## 📜 Lizenz

Dieses Dokument und die zugehörigen Workflows stehen unter der MIT-Lizenz.