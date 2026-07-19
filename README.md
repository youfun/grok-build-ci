# grok-build-ci

Standalone GitHub Actions for building [Grok Build](https://github.com/xai-org/grok-build) for **all major platforms**, plus install scripts.

Workflows live **here**, not in the source fork, so upstream monorepo syncs cannot overwrite CI config.

## Install / update CLI

After a successful CI publish (`latest` release), install or update with:

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.sh | bash
```

Optional:

```bash
# custom install dir
curl -fsSL https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.sh | bash -s -- --dir "$HOME/.local/bin"
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.ps1 | iex
```

Optional:

```powershell
irm https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.ps1 | iex
# or download then:
.\install.ps1 -InstallDir "$env:LOCALAPPDATA\grok\bin"
```

Scripts always pull the rolling **`latest`** release assets (overwrite existing binary = update).

## Platforms

| Release asset | OS | Arch |
|---------------|----|------|
| `grok-macos-aarch64` | macOS | Apple Silicon |
| `grok-macos-x86_64` | macOS | Intel |
| `grok-linux-x86_64` | Linux | x86_64 |
| `grok-linux-aarch64` | Linux | ARM64 |
| `grok-windows-x86_64.exe` | Windows | x86_64 |

## CI triggers

- **Manual**: Actions → Build all platforms → Run workflow
- **Schedule**: daily 06:00 UTC
- **Push**: when this repo changes

### Inputs

| Input | Default | Meaning |
|-------|---------|---------|
| `source_repo` | `xai-org/grok-build` | Source to checkout |
| `source_ref` | `main` | Branch / tag / SHA |

## Releases

Successful main-branch builds publish/replace GitHub release tag **`latest`** with platform binaries for the install scripts.
