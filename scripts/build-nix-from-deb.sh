#!/usr/bin/env bash
# Build the production flake against the new, already verified release DEB.
set -euo pipefail
export HARBOR_NIX_DEB="$(realpath "${1:?DEB path}")"
export HARBOR_NIX_CHANNEL="${2:?channel}"
export HARBOR_NIX_VERSION="${3:?version and revision}"
out="${4:-nix-result}"
test -s "$HARBOR_NIX_DEB"
[[ "$HARBOR_NIX_CHANNEL" == beta || "$HARBOR_NIX_CHANNEL" == stable ]]
# Use the tracked checkout, not a path flake that would copy large dist artifacts.
nix build --impure --no-update-lock-file --no-write-lock-file --out-link "$out" --expr '
  let
    f = builtins.getFlake ("git+file:" + toString ./.);
    deb = builtins.path { path = builtins.getEnv "HARBOR_NIX_DEB"; name = "harbor-release.deb"; };
    package = f.packages.x86_64-linux.${builtins.getEnv "HARBOR_NIX_CHANNEL"};
  in package.overrideAttrs (_: { src = deb; version = builtins.getEnv "HARBOR_NIX_VERSION"; })
'
test -x "$out/bin/harbor"
if [[ -d "$out/lib/harbor-hdr" ]]; then
  "$out/bin/harbor" --verify-linux-hdr-runtime
fi
