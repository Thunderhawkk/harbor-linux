#!/usr/bin/env python3
"""Refresh fixed-output Nix package metadata from verified Linux releases."""
import argparse
import base64
import json
import re
import subprocess
import tempfile
from pathlib import Path

REPOSITORY = "Thunderhawkk/harbor-linux"
VERSION_FILE = Path(__file__).resolve().with_name("version.json")
TAG = re.compile(r"(?P<beta>beta-)?v(?P<version>\d+\.\d+\.\d+)(?:-[0-9a-f]{7,40})?")
DIGEST = re.compile(r"sha256:([0-9a-f]{64})")
CHECKSUM = re.compile(r"([0-9a-f]{64}) [ *](.+)")


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True, encoding="utf-8")


def candidates(releases, channel):
    """Choose the highest version with an uploaded amd64 DEB, not latest flag."""
    out = []
    for release in releases:
        tag = release["tag_name"]
        match = TAG.fullmatch(tag)
        if not match or release.get("draft"):
            continue
        if bool(match["beta"]) != (channel == "beta"):
            continue
        if channel == "stable" and release.get("prerelease"):
            continue
        version = match["version"]
        asset_name = re.compile(r"Harbor_" + re.escape(version) + r"(?:-([1-9]\d*))?_amd64\.deb")
        for asset in release["assets"]:
            asset_match = asset_name.fullmatch(asset["name"])
            if asset_match and asset.get("state") == "uploaded":
                revision = int(asset_match[1] or 0)
                out.append((tuple(map(int, version.split("."))), revision,
                            release.get("published_at") or "", tag, version, asset))
    return sorted(out, key=lambda row: row[:4], reverse=True)


def metadata(candidate, manifest):
    _, revision, _, tag, version, asset = candidate
    digest = DIGEST.fullmatch(asset.get("digest") or "")
    if not digest:
        raise ValueError(f"{tag}: no SHA-256 digest for {asset['name']}")
    hashes = [m[1] for line in manifest.splitlines()
              if (m := CHECKSUM.fullmatch(line)) and m[2] == asset["name"]]
    if hashes != [digest[1]]:
        raise ValueError(f"{tag}: published manifest and asset digest disagree for {asset['name']}")
    expected_url = f"https://github.com/{REPOSITORY}/releases/download/{tag}/{asset['name']}"
    if asset["browser_download_url"] != expected_url:
        raise ValueError(f"{tag}: unexpected asset URL")
    return {
        "version": f"{version}-{revision}" if revision else version,
        "url": expected_url,
        "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest[1])).decode("ascii"),
    }


def manifest_for(candidate):
    _, _, _, tag, version, _ = candidate
    name = f"SHA256SUMS-{version}.txt"
    with tempfile.TemporaryDirectory() as directory:
        gh("release", "download", tag, "--repo", REPOSITORY, "--pattern", name, "--dir", directory)
        return (Path(directory) / name).read_text(encoding="utf-8")


def refresh(releases, previous):
    updated = {}
    for channel in ("beta", "stable"):
        matches = candidates(releases, channel)
        if not matches:
            raise ValueError(f"No published {channel} amd64 DEB found")
        candidate = matches[0]
        info = metadata(candidate, manifest_for(candidate))
        old = previous.get(channel, {}).get("version")
        def version_key(value):
            parts = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:-(\d+))?", value)
            if not parts:
                raise ValueError(f"Invalid package version: {value}")
            return tuple(int(p or 0) for p in parts.groups())
        if old and version_key(info["version"]) < version_key(old):
            raise ValueError(f"Refusing to downgrade {channel}: {old} -> {info['version']}")
        updated[channel] = info
        print(f"{channel}: {info['version']} ({'unchanged' if info == previous.get(channel) else 'updated'})")
    return updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if metadata differs; do not write")
    args = parser.parse_args()
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{REPOSITORY}/releases?per_page=100"))
    releases = [release for page in pages for release in page]
    previous = json.loads(VERSION_FILE.read_text(encoding="utf-8")) if VERSION_FILE.exists() else {}
    updated = refresh(releases, previous)
    if args.check:
        if previous != updated:
            raise SystemExit("Nix release metadata needs refreshing")
    elif updated != previous:
        temp = VERSION_FILE.with_suffix(".json.tmp")
        temp.write_text(json.dumps(updated, indent=2) + "\n", encoding="utf-8")
        temp.replace(VERSION_FILE)


if __name__ == "__main__":
    main()
