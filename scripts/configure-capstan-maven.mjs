// Patch only the disposable Harbor checkout used by Linux CI.
// Maven Central can rate-limit shared GitHub Actions runner IP addresses.
import { readFileSync, writeFileSync } from "node:fs";

const path = process.argv[2];
if (!path) throw new Error("Usage: node scripts/configure-capstan-maven.mjs <tools/deps.sh>");

const old = 'maven() { get "$1" "$2" "$M/$1"; }';
const source = readFileSync(path, "utf8");
if (source.split(old).length !== 2) {
  throw new Error("Unknown Capstan Maven downloader; refusing to patch the script");
}

const replacement = `maven() {
  artifact=$1
  dir=$2
  out="$dir/$(basename "$artifact")"
  if [ -s "$out" ]; then
    echo "  have $(basename "$artifact")"
    return 0
  fi

  for mirror in \\
    https://maven-central.storage-download.googleapis.com/maven2 \\
    https://repo.maven.apache.org/maven2 \\
    https://maven.aliyun.com/repository/central
  do
    url="$mirror/$artifact"
    echo "  Maven download URL: $url"
    if curl -fLsS --retry 2 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 180 -o "$out" "$url" \\
      && curl -fLsS --retry 2 --retry-all-errors --retry-delay 2 --connect-timeout 20 --max-time 60 -o "$out.sha1" "$url.sha1" \\
      && [ -s "$out" ]; then
      expected=$(head -n 1 "$out.sha1" | cut -c 1-40)
      if [ -n "$expected" ] \\
        && printf '%s  %s\\n' "$expected" "$out" | sha1sum -c - >/dev/null; then
        rm -f "$out.sha1"
        echo "  verified $(basename "$artifact") from $url"
        return 0
      fi
    fi
    echo "  Maven mirror unavailable or checksum mismatch: $url"
    rm -f "$out" "$out.sha1"
  done
  echo "FAILED all Maven mirrors for $artifact" >&2
  exit 1
}`;

const updated = source.replace(old, replacement);
if (!updated.includes('echo "  Maven download URL: $url"') ||
    !updated.includes("sha1sum -c -")) {
  throw new Error("Capstan mirror verification logic was not installed");
}
writeFileSync(path, updated);
console.log("Capstan Maven mirror priority:");
console.log("  https://maven-central.storage-download.googleapis.com/maven2");
console.log("  https://repo.maven.apache.org/maven2");
console.log("  https://maven.aliyun.com/repository/central");
console.log("Each uncached download logs its URL and verifies the published SHA-1.");
