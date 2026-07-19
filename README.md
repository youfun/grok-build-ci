# grok-build-ci

Standalone GitHub Actions for building [Grok Build](https://github.com/xai-org/grok-build) on **macOS Apple Silicon**.

Workflows live **here**, not in the source fork, so upstream monorepo syncs (`Synced from monorepo`) cannot overwrite CI config.

## Triggers

- **Manual**: Actions → Build macOS → Run workflow
- **Schedule**: daily (UTC)
- **Push**: when this repo changes

## Inputs

| Input | Default | Meaning |
|-------|---------|---------|
| `source_repo` | `xai-org/grok-build` | Where to checkout source |
| `source_ref` | `main` | Branch / tag / SHA |

Use `youfun/grok-build` as `source_repo` if you want to build your fork instead.

## Artifact

After a green run: **Artifacts** → `grok-macos-aarch64-<sha>` → download `grok`.

```bash
chmod +x grok
./grok --version
```
