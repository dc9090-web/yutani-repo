#!/usr/bin/env bash
# Points tarball-based PKGBUILDs at their upstream's latest GitHub release and
# commits the bump, so a new tag upstream becomes a new package here.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)

# package dir -> upstream repo
declare -A UPSTREAM=(
  [yutani-applets]=dc9090-web/yutani-sysmon
)

changed=0
for pkg in "${!UPSTREAM[@]}"; do
  f=$ROOT/packages/$pkg/PKGBUILD
  latest=$(gh api "repos/${UPSTREAM[$pkg]}/releases/latest" --jq .tag_name)
  latest=${latest#v}
  current=$(sed -n 's/^pkgver=//p' "$f")
  [[ $latest == "$current" ]] && continue
  echo "== $pkg: $current -> $latest"
  sed -i "s/^pkgver=.*/pkgver=$latest/; s/^pkgrel=.*/pkgrel=1/" "$f"
  (cd "$(dirname "$f")" && updpkgsums)
  changed=1
done

if [[ $changed == 1 && -n ${GITHUB_ACTIONS:-} ]]; then
  cd "$ROOT"
  git config user.name "github-actions[bot]"
  git config user.email "41898283+github-actions[bot]@users.noreply.github.com"
  git commit -am "Bump tarball packages to upstream releases"
  git push
fi
