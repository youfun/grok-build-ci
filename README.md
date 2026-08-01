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

### Windows build notes

The release binary is large. On MSVC, default `/DEBUG` PDB generation can fail with:

`LINK : fatal error LNK1318: Unexpected PDB error: LIMIT (12)`

CI builds Windows with **PowerShell** (not Git Bash) so `/DEBUG:NONE` is not
corrupted by MSYS path conversion, and sets:

- `CARGO_PROFILE_RELEASE_DEBUG=0`
- `RUSTFLAGS=-C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/DEBUG:NONE`

(`RUSTFLAGS` replaces target rustflags from upstream `.cargo/config.toml`, so
`crt-static` / unwind tables are restated explicitly.)

Local equivalent (PowerShell):

```powershell
$env:CARGO_PROFILE_RELEASE_DEBUG = "0"
$env:RUSTFLAGS = "-C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/DEBUG:NONE"
cargo build -p xai-grok-pager-bin --release
```

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

Each successful main-branch matrix build publishes its platform asset to GitHub release tag **`latest`**. If a platform build fails, other successful assets are still published and existing assets are retained; the release notes identify the release as partial until all required platform binaries are available.
