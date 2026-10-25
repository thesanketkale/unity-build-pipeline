# Unity Library Caching Architecture & Strategy

This document details the caching architecture employed by `unity-build-pipeline`, explaining how the persistent workspace model achieves sub-3-minute build times while maintaining cache integrity.

---

## The Unity Library Problem

In Unity projects, the `Assets/` and `Packages/` folders represent source code and raw assets. The `Library/` directory is the engine's internal cache containing:
- Processed textures compressed for target platforms (ASTC, DXT, ETC2).
- Compiled shader variant blobs.
- Serialized metadata and asset database indexes.
- Script assembly binaries.

When starting from an empty or missing `Library/` folder, Unity must re-import and re-process every asset in the project. For mid-sized games (10–30 GB), this re-import takes between **30 and 90 minutes**.

---

## Strategy Comparison

| Strategy | Incremental Build Time | Clean Build Time | Network Overhead | Disk Requirement |
|---|---|---|---|---|
| **Persistent Workspace + Hash Guard (Default)** | **2–4 minutes** | 35–45 minutes | **Zero** | ~50–100 GB local NVMe |
| **Hosted Runner + `actions/cache`** | 15–30 minutes | 45–60 minutes | High (tarball upload/download) | Ephemeral |
| **Clean Workspace (`clean: true`)** | 35–45 minutes | 35–45 minutes | Zero | Minimal |

---

## Deterministic Cache Guard (`Guard-LibraryCache.ps1`)

A naive persistent workspace risks cache corruption when developers upgrade Unity versions, update package dependencies, or modify project manifest settings.

`scripts/Guard-LibraryCache.ps1` prevents silent corruption by computing a composite **SHA-256 fingerprint** from:
1. `ProjectSettings/ProjectVersion.txt` (Unity editor version and changeset)
2. `Packages/manifest.json` (Package dependencies)
3. `Packages/packages-lock.json` (Exact resolved package revisions)

```text
Fingerprint = SHA256( ProjectVersion.txt + manifest.json + packages-lock.json )
```

### Eviction Rules:
1. **Match:** If the calculated fingerprint matches the signature stored in `.library-cache-hash`, `Library/` is preserved intact.
2. **Mismatch:** If any dependency or engine version changes, the cache signature changes. `Library/` is pruned immediately, forcing a clean re-import for that run and updating `.library-cache-hash`.
3. **Manual Override:** Invoking with `-ForceClean` forces eviction regardless of fingerprint match.

---

## Concurrency & File Locking

Unity's Editor acquires an exclusive write lock on the project directory. If two CI jobs attempt to build the same project simultaneously, Unity crashes or exits with error code 1.

Workflows enforce single-job concurrency per project and runner:
```yaml
concurrency:
  group: unity-build-${{ github.repository }}-${{ inputs.project-path }}-${{ matrix.build-target }}
  cancel-in-progress: false
```
`cancel-in-progress: false` ensures running builds finish cleanly without corrupting the local asset database.
