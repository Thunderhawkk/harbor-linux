# Harbor for Linux

Linux builds of [Harbor](https://github.com/Harborofficial/Harbor), built from its upstream source by GitHub Actions.

<p align="center">
  <a href="https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132"><strong>Download beta</strong></a>
  ·
  <a href="https://github.com/Thunderhawkk/harbor-linux/releases/latest"><strong>Download stable</strong></a>
  ·
  <a href="https://github.com/Harborofficial/Harbor"><strong>Harbor upstream</strong></a>
</p>

> **x86_64 only.** Choose the package that fits your distribution below. Every package download below follows the current [beta release](https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132).

> **Beta is recommended.** Harbor development currently moves through the beta channel; stable releases are less frequent and can lag behind the current beta version.

## Install beta

### <img src="https://cdn.simpleicons.org/archlinux/1793D1" width="20" height="20" align="absmiddle" alt="" /> Arch Linux

Not published to the AUR from this repository yet. Use one of the prebuilt packages below, or
build [Harbor](https://github.com/Harborofficial/Harbor) from source.

---

### <img src="https://cdn.simpleicons.org/ubuntu/E95420" width="20" height="20" align="absmiddle" alt="" /> Ubuntu 24.04

Package repository hosting is not configured for this repository yet.

[Download the latest .deb directly instead →](https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132)

---

### <img src="https://cdn.simpleicons.org/fedora/51A2DA" width="20" height="20" align="absmiddle" alt="" /> Fedora 44

Package repository hosting is not configured for this repository yet.

[Download the latest .rpm directly instead →](https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132)

---

### <img src="https://cdn.simpleicons.org/nixos/5277C3" width="20" height="20" align="absmiddle" alt="" /> NixOS

Install Harbor using the community Nix flake at [axioncs/harbor-flake](https://github.com/axioncs/harbor-flake).

Run directly without installing:

```bash
nix run github:axioncs/harbor-flake
```

Or add it as a flake input:

```nix
{
  inputs.harbor = {
    url = "github:axioncs/harbor-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

See [axioncs/harbor-flake](https://github.com/axioncs/harbor-flake) for Home Manager setup and further options.

---

### <img src="https://cdn.simpleicons.org/flatpak/4A90D9" width="20" height="20" align="absmiddle" alt="" /> Flatpak

[Download the latest .flatpak bundle →](https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132)

```bash
flatpak install --user ./Harbor_*.flatpak
```

The bundle installs the beta branch as `site.harbor.Harbor.Beta`.

---

### <img src="https://avatars.githubusercontent.com/u/16617932?s=200&amp;v=4" width="20" height="20" align="absmiddle" alt="" /> AppImage (experimental)

[Download the latest .AppImage →](https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132)

```bash
chmod +x Harbor_*.AppImage
./Harbor_*.AppImage
```

For automatic updates, open the downloaded AppImage with [Gear Lever](https://github.com/mijorus/gearlever) and choose **Integrate**.

A portable x86_64 build using Tauri's experimental AppImage bundler, pending [upstream PR #12491](https://github.com/tauri-apps/tauri/pull/12491).

## Verify a download

Each release includes a SHA-256 checksum file for the core package assets. [Get SHA256SUMS from the current beta →](https://github.com/Thunderhawkk/harbor-linux/releases/tag/beta-v0.9.132)

```bash
sha256sum -c SHA256SUMS-*.txt
```

## Stable releases

Stable packages follow upstream Harbor release tags and publish as `Harbor` (`harbor` packages) for the stable channel.

Dispatch **Build Harbor Linux Release** from the [Actions tab](https://github.com/Thunderhawkk/harbor-linux/actions) — it resolves the upstream `latest` release tag by default, or accepts a specific tag. Its schedule is off by default.

## How it works

Beta is the primary channel. Each beta release is built from an exact `beta-branch` commit of [Harborofficial/Harbor](https://github.com/Harborofficial/Harbor) and published once per Harbor version; later commits with the same version do not create another release. Releases provide `.deb`, `.rpm`, a Flatpak bundle, and an experimental AppImage. Flatpak and AppImage build separately, so either can fail without blocking the core packages.

The workflow and the exact upstream source ref for each build are visible in the [Actions tab](https://github.com/Thunderhawkk/harbor-linux/actions).

## Maintainer setup

- **Beta builds** work with the repository token alone: dispatch *Build Harbor Linux Beta* or let the 5-hour schedule run. The workflow resolves the current `Harborofficial/Harbor@beta-branch` version and publishes `beta-v<version>`.
- **Cloudsmith** (optional): set the `CLOUDSMITH_BETA_REPOSITORY` repository variable (for example `Thunderhawkk/harbor-beta`) and the `CLOUDSMITH_API_KEY` secret. The Cloudsmith job is skipped until the variable exists.
- **AUR** (optional): set the `AUR_SSH_PRIVATE_KEY` secret and point `aur_package` in `build-linux-beta.yml` at your own AUR package. The AUR step never blocks native packages.
- **Stable builds**: re-enable the schedule in `build-linux-release.yml` once upstream publishes stable releases.
- The build runs `pnpm run setup` in the source checkout, which fetches the pinned Linux dependencies (yt-dlp, ffmpeg, fonts, extension layer). Those downloads must stay reachable from the upstream repository.

## Package repository hosting

Package repository hosting for the `.deb` and `.rpm` channels is planned through [Cloudsmith](https://cloudsmith.com) once configured above.
