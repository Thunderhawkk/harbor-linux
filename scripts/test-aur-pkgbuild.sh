#!/usr/bin/env bash
set -euo pipefail
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat > "$work/bin/dpkg-deb" <<'SH'
#!/usr/bin/env bash
printf '%s\n' './usr/lib/harbor-hdr/libharbor-linux-hdr.so'
SH
chmod +x "$work/bin/dpkg-deb"
export PATH="$work/bin:$PATH"
export VERSION=1.0.4 PACKAGE_REVISION=2 CHANNEL=beta AUR_PACKAGE=harbor-stremio-beta-bin
export DEB_ASSET=Harbor_1.0.4-2_amd64.deb DEB_PATH="$work/Harbor_1.0.4-2_amd64.deb"
printf '%s' 'fixture only' > "$DEB_PATH"
export DEB_SHA256="$(sha256sum "$DEB_PATH" | awk '{print $1}')"
export REPOSITORY=Thunderhawkk/harbor-linux TAG=beta-v1.0.4
bash scripts/generate-aur-pkgbuild.sh "$work/local" local
bash scripts/generate-aur-pkgbuild.sh "$work/remote" remote
bash -n "$work/local" "$work/remote"
grep -F 'source=("Harbor_${pkgver}-${pkgrel}_amd64.deb")' "$work/local"
grep -F 'source=("Harbor_${pkgver}-${pkgrel}_amd64.deb::https://github.com/Thunderhawkk/harbor-linux/releases/download/beta-v1.0.4/Harbor_1.0.4-2_amd64.deb")' "$work/remote"
for dep in libxss slang libbsd; do grep -F "'$dep'" "$work/local"; done
if DEB_SHA256="$(printf '%064d' 0)" bash scripts/generate-aur-pkgbuild.sh "$work/bad" local; then
  echo 'Checksum mismatch was incorrectly accepted' >&2
  exit 1
fi
echo "AUR local and remote fixture checks passed"
