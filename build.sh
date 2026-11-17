#!/usr/bin/env bash
# Builds every package under packages/ whose current version is not yet in the
# repo, signs it, adds it to the pacman database and publishes the result as
# assets of the GitHub release "$TAG" (served to pacman as
# https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/).
#
# Runs as an unprivileged user with passwordless sudo (makepkg -s needs it).
# Env: GH_TOKEN, GITHUB_REPOSITORY, GPGKEY. Set FORCE=1 to rebuild everything.
set -euo pipefail

REPO_NAME=yutani
TAG=x86_64
ROOT=$(cd "$(dirname "$0")" && pwd)
OUT=$ROOT/out
export PKGDEST=$OUT SRCDEST=$ROOT/.srcdest
mkdir -p "$OUT" "$SRCDEST"

gh release view "$TAG" >/dev/null 2>&1 ||
  gh release create "$TAG" --title "Yutani pacman repo ($TAG)" \
    --notes "Package repository for pacman. See README.md for setup."

mapfile -t ASSETS < <(gh release view "$TAG" --json assets --jq '.assets[].name')
have() { local a; for a in "${ASSETS[@]}"; do [[ $a == "$1" ]] && return 0; done; return 1; }

# Pull the current database so new packages are added to it, not replace it.
cd "$OUT"
for db in db files; do
  if have "$REPO_NAME.$db"; then
    gh release download "$TAG" -p "$REPO_NAME.$db" --clobber
    mv "$REPO_NAME.$db" "$REPO_NAME.$db.tar.gz"
  fi
done

# Tarball packages: follow the upstream's latest release tag.
"$ROOT/bump-tarballs.sh"

built=()
for dir in "$ROOT"/packages/*/; do
  name=$(basename "$dir")
  cd "$dir"
  # Fetch sources and run pkgver() so VCS packages report their new version.
  makepkg --nobuild --nodeps --noprepare --skipinteg --noconfirm >/dev/null
  mapfile -t files < <(makepkg --packagelist)
  missing=0
  for f in "${files[@]}"; do have "$(basename "$f")" || missing=1; done
  if [[ $missing == 0 && ${FORCE:-0} != 1 ]]; then
    echo "== $name: up to date ($(basename "${files[0]}"))"
    continue
  fi
  echo "== $name: building"
  makepkg --syncdeps --cleanbuild --clean --rmdeps --force --noconfirm --sign --key "$GPGKEY"
  built+=("${files[@]}")
  # Runner disk is small: drop what the next build doesn't need.
  rm -rf "$HOME/.cargo/registry" "$dir/pkg"
  sudo pacman -Scc --noconfirm >/dev/null
done

if [[ ${#built[@]} == 0 ]]; then
  echo "Nothing to publish."
  exit 0
fi

cd "$OUT"
repo-add --sign --key "$GPGKEY" "$REPO_NAME.db.tar.gz" "${built[@]}"
# pacman fetches $repo.db / $repo.files; release assets cannot be symlinks.
for db in db files; do
  rm -f "$REPO_NAME.$db" "$REPO_NAME.$db.sig"
  cp "$REPO_NAME.$db.tar.gz" "$REPO_NAME.$db"
  cp "$REPO_NAME.$db.tar.gz.sig" "$REPO_NAME.$db.sig"
done

uploads=()
for f in "${built[@]}"; do uploads+=("$f" "$f.sig"); done
gh release upload "$TAG" --clobber "${uploads[@]}"
gh release upload "$TAG" --clobber \
  "$REPO_NAME.db" "$REPO_NAME.db.sig" "$REPO_NAME.files" "$REPO_NAME.files.sig"

# Drop package files the database no longer references.
mapfile -t keep < <(tar -xOzf "$REPO_NAME.db.tar.gz" --wildcards '*/desc' |
  awk '/^%FILENAME%$/{getline; print}')
mapfile -t ASSETS < <(gh release view "$TAG" --json assets --jq '.assets[].name')
for a in "${ASSETS[@]}"; do
  [[ $a == *.pkg.tar.* ]] || continue
  base=${a%.sig}
  printf '%s\n' "${keep[@]}" | grep -qxF "$base" && continue
  echo "Removing stale $a"
  gh release delete-asset "$TAG" "$a" --yes
done
