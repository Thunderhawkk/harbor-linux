#!/usr/bin/env bash
set -euo pipefail
store="$(readlink -f "${1:?Nix result path required}")"
out="${2:?Output directory required}"
[[ "$store" == /nix/store/* && -x "$store/bin/harbor" ]]
mkdir -p "$out"
nix-store --query --requisites "$store" > "$out/closure-paths.txt"
mapfile -t paths < "$out/closure-paths.txt"
test "${#paths[@]}" -gt 0
printf '%s\n' "$store" > "$out/store-path.txt"
nix-store --export "${paths[@]}" | zstd -T2 -3 -o "$out/harbor-nixos-x86_64.closure.zst"
cat > "$out/README.txt" <<'EOF'
Harbor runtime closure for x86_64 NixOS.
This archive contains the Nix runtime closure, including Harbor's dependencies.
Only import artifacts from a CI run you trust. SHA256SUMS checks integrity,
not publisher identity. Import requires a trusted Nix user (normally root).

From the extracted artifact directory:
  sha256sum -c SHA256SUMS
  zstd -dc harbor-nixos-x86_64.closure.zst | sudo nix-store --import
  # For HDR-enabled builds, verify the bundled renderer:
  "$(cat store-path.txt)/bin/harbor" --verify-linux-hdr-runtime
  nix profile install "$(cat store-path.txt)"

No rebuild is needed. An installed profile keeps the store paths alive.
Hardware acceleration and HDR require a compatible desktop and GPU.
EOF
(
 cd "$out"
 sha256sum harbor-nixos-x86_64.closure.zst store-path.txt closure-paths.txt README.txt > SHA256SUMS
 sha256sum -c SHA256SUMS
)
du -sh "$out"
