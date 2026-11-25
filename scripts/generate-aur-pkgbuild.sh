#!/usr/bin/env bash
# Generate one PKGBUILD for both local CI validation and AUR publication.
set -euo pipefail
output="$(realpath -m "${1:?PKGBUILD output path required}")"
mode="${2:-remote}"
[[ "$mode" == local || "$mode" == remote ]]
: "${VERSION:?}" "${PACKAGE_REVISION:?}" "${CHANNEL:?}" "${AUR_PACKAGE:?}" "${DEB_ASSET:?}" "${DEB_SHA256:?}"
[[ "$VERSION" =~ ^[0-9][A-Za-z0-9._]*$ && "$PACKAGE_REVISION" =~ ^[0-9]+$ ]]
[[ "$AUR_PACKAGE" =~ ^[a-z0-9][a-z0-9._+-]*$ ]]
[[ "$CHANNEL" == beta || "$CHANNEL" == stable ]]
[[ "$DEB_ASSET" == "Harbor_${VERSION}-${PACKAGE_REVISION}_amd64.deb" ]]
[[ "$DEB_SHA256" =~ ^[a-fA-F0-9]{64}$ ]]
deb_path="${DEB_PATH:-dist/$DEB_ASSET}"
mkdir -p "$(dirname "$output")"
if [ "${CHANNEL}" = beta ]; then
  package_desc='A Stremio client built for adventure (beta binary release)'
  provides="provides=('harbor-stremio-beta' 'harbor')"
  conflicts="conflicts=('harbor-stremio-bin' 'harbor-stremio' 'harbor' 'harbor-stremio-git')"
else
  package_desc='A Stremio client built for adventure (binary release)'
  provides="provides=('harbor-stremio' 'harbor')"
  conflicts="conflicts=('harbor-stremio' 'harbor' 'harbor-stremio-git')"
fi
# The AUR payload is the verified Debian asset. Only newer HDR-enabled
# payloads need the additional host libraries.
hdr_depends=""
test -f "$deb_path"
actual_sha="$(sha256sum "$deb_path" | awk '{print $1}')"
test "$actual_sha" = "$DEB_SHA256"
contents="$(dpkg-deb -c "$deb_path")"
if grep -q 'usr/lib/harbor-hdr/libharbor-linux-hdr.so' <<< "$contents"; then
  hdr_depends=" 'gnutls' 'dav1d' 'libass' 'libdrm' 'libva' 'libvdpau' 'luajit' 'shaderc' 'lcms2' 'xxhash' 'libffi' 'expat' 'alsa-lib' 'libpulse' 'pipewire' 'libxkbcommon' 'libx11' 'libxext' 'libxrandr' 'libxpresent' 'libxss' 'libxinerama' 'libxv' 'slang' 'libbsd' 'libxfixes' 'libxcb' 'mesa' 'libdisplay-info' 'libjpeg-turbo' 'uchardet' 'zimg' 'vulkan-icd-loader' 'zlib' 'wayland>=1.23'"
fi
pkgrel="${PACKAGE_REVISION}"
source_spec="Harbor_\${pkgver}-\${pkgrel}_amd64.deb"
if [[ "$mode" == remote ]]; then
  : "${REPOSITORY:?}" "${TAG:?}"
  [[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && "$TAG" =~ ^[A-Za-z0-9_.-]+$ ]]
  source_spec="$source_spec::https://github.com/$REPOSITORY/releases/download/$TAG/$DEB_ASSET"
fi
cat > "$output" <<EOF
# Maintainer: Thunderhawkk <thunderhawkk@users.noreply.github.com>
pkgname=${AUR_PACKAGE}
_pkgname=harbor
pkgver=${VERSION}
pkgrel=${pkgrel}
pkgdesc='${package_desc}'
arch=('x86_64')
url='https://github.com/HarborCommunity/Harbor'
license=('MIT')
depends=('ffmpeg' 'gst-libav' 'gst-plugins-bad' 'gst-plugins-good' 'gtk3' 'libayatana-appindicator' 'mpv' 'systemd-libs' 'webkit2gtk-4.1' 'yt-dlp'${hdr_depends})
makedepends=('libarchive')
${provides}
${conflicts}
source=("$source_spec")
sha256sums=('${DEB_SHA256}')
package() {
  local extract="\$srcdir/deb-extract"
  rm -rf "\$extract"; mkdir -p "\$extract"
  bsdtar --no-same-owner -xf "\$srcdir/Harbor_\${pkgver}-\${pkgrel}_amd64.deb" -C "\$extract"
  bsdtar --no-same-owner -xf "\$(find "\$extract" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)" -C "\$pkgdir"
  rm -f "\$pkgdir/usr/bin/ffmpeg" "\$pkgdir/usr/bin/ffprobe" "\$pkgdir/usr/bin/yt-dlp"
  if [[ -d "\$pkgdir/usr/lib/harbor-hdr" ]]; then
    # Arch's GTK/Mesa should use Arch's current Wayland client family.
    rm -f "\$pkgdir/usr/lib/harbor-hdr"/libwayland-*.so.* "\$pkgdir/usr/lib/harbor-hdr"/libvulkan.so.*
    # Report the entire unresolved set, not just the first loader error.
    missing="\$(ldd "\$pkgdir/usr/bin/harbor" | grep 'not found' || true)"
    if [[ -n "\$missing" ]]; then
      printf '%s\n' "\$missing" >&2
      exit 1
    fi
    "\$pkgdir/usr/bin/harbor" --verify-linux-hdr-runtime
  fi
  if [[ -x "\$pkgdir/usr/bin/harbor" && ! -e "\$pkgdir/usr/bin/harbor-stremio" ]]; then ln -s harbor "\$pkgdir/usr/bin/harbor-stremio"; fi
}
EOF
