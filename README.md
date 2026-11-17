# yutani-repo

A pacman repository for:

| Package | From |
|---|---|
| `yutani` | [dc9090-web/yutani](https://github.com/dc9090-web/yutani) (latest commit) |
| `whatsapp-cosmic-git` | [dc9090-web/whatsapp](https://github.com/dc9090-web/whatsapp) (latest commit) |
| `yutani-sysmon`, `yutani-net-traffic`, `yutani-ai-usage`, `yutani-weather`, `yutani-vpn` | [dc9090-web/yutani-sysmon](https://github.com/dc9090-web/yutani-sysmon) (latest release) |

Once it is set up, `sudo pacman -Syu` updates these packages along with the rest of the system.

## Add the repo (Arch / CachyOS)

```bash
curl -fsSL https://raw.githubusercontent.com/dc9090-web/yutani-repo/main/setup.sh | sudo bash
sudo pacman -S yutani whatsapp-cosmic-git yutani-sysmon
```

Or by hand:

```bash
curl -fsSLO https://raw.githubusercontent.com/dc9090-web/yutani-repo/main/yutani-repo.asc
sudo pacman-key --add yutani-repo.asc
sudo pacman-key --lsign-key 0839A301A0D74BF69A1CF2F6513E4FFAAE611ADF
```

then append to `/etc/pacman.conf`:

```ini
[yutani]
SigLevel = Required
Server = https://github.com/dc9090-web/yutani-repo/releases/download/$arch
```

## How it updates

`.github/workflows/build.yml` runs every hour, on every push here, and on demand (Actions → Build repo → Run workflow, with an option to force a rebuild of everything). For each package under `packages/`:

- **git packages** (`yutani`, `whatsapp-cosmic-git`): `pkgver()` is computed from the upstream's latest commit, so a new commit gives a new version.
- **tarball packages** (`yutani-applets`): `bump-tarballs.sh` moves `pkgver` to the upstream's latest GitHub release and commits the change.

A package is rebuilt only when its version isn't already published. Packages and the database are signed with the repo key (secret `GPG_PRIVATE_KEY`) and uploaded as assets of the `x86_64` release. Package files the database no longer references are deleted.

To change how a package is built, edit its PKGBUILD here and bump `pkgrel`.
