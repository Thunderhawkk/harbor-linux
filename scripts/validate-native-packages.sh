#!/usr/bin/env bash
# Install actual package artifacts in clean supported distributions.
set -euo pipefail
dist="$(realpath "${1:?artifact directory}")"
version="${2:?version}"
revision="${3:?package revision}"
target="${4:?target}"
fedora_release="${5:-}"
# The CI matrix tests each Fedora release independently. Manual validation
# keeps its existing default of testing both in one invocation.
releases=(43 44)
if [[ -n "$fedora_release" ]]; then
  [[ "$target" == rpm && ( "$fedora_release" == 43 || "$fedora_release" == 44 ) ]]
  releases=("$fedora_release")
fi
[[ "$version" =~ ^[0-9][A-Za-z0-9._]*$ && "$revision" =~ ^[0-9]+$ ]]
case "$target" in all|native|deb|rpm) ;; *) exit 2 ;; esac
# Do not install extra media libraries to hide missing package requirements.
if [[ "$target" != rpm ]]; then
  asset="Harbor_${version}-${revision}_amd64.deb"
  test -s "$dist/$asset"
  docker run --rm -v "$dist:/dist:ro" ubuntu:24.04 bash -ec '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y "/dist/$1"
    ldd /usr/bin/harbor | tee /tmp/harbor-ldd.txt
    if grep -q "not found" /tmp/harbor-ldd.txt; then exit 1; fi
    if [[ -d /usr/lib/harbor-hdr ]]; then
      /usr/lib/harbor-hdr/check-api /usr/lib/harbor-hdr/libharbor-linux-hdr.so
      /usr/bin/harbor --verify-linux-hdr-runtime
    fi
  ' bash "$asset"
fi
if [[ "$target" != deb ]]; then
  asset="Harbor-${version}-${revision}.x86_64.rpm"
  test -s "$dist/$asset"
  for release in "${releases[@]}"; do
    docker run --rm -v "$dist:/dist:ro" "fedora:$release" bash -ec '
      set -euo pipefail
      dnf -y install "/dist/$1"
      ldd /usr/bin/harbor | tee /tmp/harbor-ldd.txt
      if grep -q "not found" /tmp/harbor-ldd.txt; then exit 1; fi
      if [[ -d /usr/lib/harbor-hdr ]]; then
        test -n "$(rpm -qp --qf "%{LICENSE}" "/dist/$1")"
        test "$(rpm -qp --qf "%{LICENSE}" "/dist/$1")" != "(none)"
        /usr/lib/harbor-hdr/check-api /usr/lib/harbor-hdr/libharbor-linux-hdr.so
        /usr/bin/harbor --verify-linux-hdr-runtime
      fi
    ' bash "$asset"
  done
fi
