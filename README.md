# grok-build-ci

Standalone GitHub Actions for building [Grok Build](https://github.com/xai-org/grok-build) for **all major platforms**.

Workflows live **here**, not in the source fork, so upstream monorepo syncs (`Synced from monorepo`) cannot overwrite CI config.

## Platforms

| Artifact | OS | Arch | Runner |
|----------|----|------|--------|
| `grok-macos-aarch64` | macOS | Apple Silicon | `macos-14` |
| `grok-macos-x86_64` | macOS | Intel (cross) | `macos-14` + `x86_64-apple-darwin` |
| `grok-linux-x86_64` | Linux | x86_64 | `ubuntu-22.04` |
| `grok-linux-aarch64` | Linux | ARM64 | `ubuntu-24.04-arm` |
| `grok-windows-x86_64` | Windows | x86_64 | `windows-latest` |

## Triggers

- **Manual**: Actions → Build all platforms → Run workflow
- **Schedule**: daily 06:00 UTC
- **Push**: when this repo changes

## Inputs

| Input | Default | Meaning |
|-------|---------|---------|
| `source_repo` | `xai-org/grok-build` | Where to checkout source |
| `source_ref` | `main` | Branch / tag / SHA |

Use `youfun/grok-build` as `source_repo` if you want to build your fork instead.

## Download

After a green run: **Artifacts** → pick your platform → download `grok` (or `grok.exe` on Windows).

```bash
chmod +x grok   # Unix
./grok --version
```
