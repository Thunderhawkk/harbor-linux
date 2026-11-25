#!/usr/bin/env bash
# Exercise the publication PKGBUILD using a checksum-verified local DEB.
set -euo pipefail
: "${VERSION:?}" "${PACKAGE_REVISION:?}" "${CHANNEL:?}" "${AUR_PACKAGE:?}"
export DEB_ASSET="Harbor_${VERSION}-${PACKAGE_REVISION}_amd64.deb"
export DEB_PATH="$(realpath "dist/$DEB_ASSET")"
export DEB_SHA256="$(sha256sum "$DEB_PATH" | awk '{print $1}')"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$DEB_PATH" "$work/"
bash scripts/generate-aur-pkgbuild.sh "$work/PKGBUILD" local
docker run --rm -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" -v "$work:/work" -w /work archlinux:base-devel bash -lc '
  set -euo pipefail
  trap "chown -R $HOST_UID:$HOST_GID /work" EXIT
  pacman -Syu --noconfirm --needed sudo libarchive
  useradd -m builder
  printf "builder ALL=(ALL) NOPASSWD: ALL\n" > /etc/sudoers.d/builder
  chmod 440 /etc/sudoers.d/builder
  chown -R builder:builder /work
  runuser -u builder -- makepkg --syncdeps --noconfirm --cleanbuild
  pacman -U --noconfirm ./*.pkg.tar.zst
  ldd /usr/bin/harbor | tee /tmp/harbor-ldd.txt
  if grep -q "not found" /tmp/harbor-ldd.txt; then exit 1; fi
  if [[ -d /usr/lib/harbor-hdr ]]; then
    /usr/bin/harbor --verify-linux-hdr-runtime
  fi
'
