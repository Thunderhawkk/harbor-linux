# Harbor Nix packaging

This flake packages the x86_64 Debian binaries published by
[Thunderhawkk/harbor-linux](https://github.com/Thunderhawkk/harbor-linux).
It does not build Harbor from Rust/TypeScript source or submit a package to
nixpkgs. The original community packaging by axioncs is adapted under the
MIT license in [LICENSE](LICENSE).

## Channels

- `default` / `beta`: newest published beta DEB.
- `stable`: newest published stable DEB.

Both packages install the `harbor` executable; select one channel at a time
in a profile or system package list. Harbor's usual per-user data is preserved.
The flake locks nixpkgs; overriding it via `inputs.nixpkgs.follows` can change
dependency compatibility.

## Maintenance

From the repository root, with Python 3 and GitHub CLI installed:

```bash
python3 -m unittest discover -s nix -p 'test_*.py'
python3 nix/update.py
python3 nix/update.py --check
nix flake check --no-update-lock-file --no-write-lock-file
nix build .#beta .#stable --no-link --no-update-lock-file --no-write-lock-file
```

Track the flake files in Git before running Nix, because flakes inside Git
repositories ignore untracked files. Review metadata changes before committing.
The updater selects channels using versioned release tags, ignores drafts,
checks the published DEB's GitHub SHA-256 digest against its release checksum
manifest, and refuses downgrades. It rechecks unchanged URLs for rebuilds.
The CI build verifies the fixed-output hash against the actual downloaded DEB.

The release workflow invokes the Nix update job after successful Debian
publication; a six-hour scheduled check and manual dispatch also cover missed
updates. Metadata is committed only if both Nix packages build successfully.
PRs changing Nix packaging also build both channels.

## Limitations

- x86_64 Linux only; real graphical playback requires a Linux desktop session.
- A successful package build does not establish that MPV/WebKit playback works
  on every GPU or desktop. A manual NixOS smoke test is still required.
- Linux rebuilds can replace an existing release asset or remove its older
  package revision. The updater tracks the new hash and URL, but older pinned
  flake revisions may no longer fetch their original bytes unless they are
  already cached. Long-term reproducibility would require retaining immutable
  release assets or an independent binary cache.
- The nixpkgs lock is deliberately not updated during each Harbor release;
  update it separately and validate both channels.
