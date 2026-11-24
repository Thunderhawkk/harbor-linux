import base64
import copy
import hashlib
import unittest
from unittest.mock import patch

import update


def release(tag, revision=1, *, draft=False, prerelease=False, uploaded=True, data=b"deb"):
    version = update.TAG.fullmatch(tag)["version"]
    suffix = f"-{revision}" if revision else ""
    name = f"Harbor_{version}{suffix}_amd64.deb"
    digest = hashlib.sha256(data).hexdigest()
    return {
        "tag_name": tag, "draft": draft, "prerelease": prerelease,
        "published_at": "2026-11-22T00:00:00Z",
        "assets": [{
            "name": name, "state": "uploaded" if uploaded else "new",
            "digest": "sha256:" + digest,
            "browser_download_url": f"https://github.com/{update.REPOSITORY}/releases/download/{tag}/{name}",
        }],
    }


def manifest(candidate):
    asset = candidate[-1]
    return asset["digest"][7:] + "  " + asset["name"] + "\n"


class ReleaseTests(unittest.TestCase):
    def test_channels_use_tags_not_prerelease_flag_and_semantic_order(self):
        releases = [
            release("v1.0.0"), release("v2.0.0", prerelease=True),
            release("beta-v1.0.9"), release("beta-v1.0.10", prerelease=False),
            release("beta-v1.1.0", draft=True),
            release("beta-v1.2.0", uploaded=False),
        ]
        self.assertEqual(update.candidates(releases, "stable")[0][3], "v1.0.0")
        self.assertEqual(update.candidates(releases, "beta")[0][3], "beta-v1.0.10")

    def test_revision_order_and_legacy_tag(self):
        old = release("beta-v1.0.4-abcdef1", revision=0)
        new = release("beta-v1.0.4", revision=3)
        new["assets"] += release("beta-v1.0.4", revision=2)["assets"]
        self.assertEqual(update.candidates([old, new], "beta")[0][1], 3)

    def test_never_pick_mismatched_version_asset(self):
        bad = release("beta-v2.0.0")
        bad["assets"][0]["name"] = "Harbor_1.0.0-1_amd64.deb"
        self.assertEqual(update.candidates([bad], "beta"), [])

    def test_manifest_agreement_and_sri(self):
        item = update.candidates([release("v1.0.0")], "stable")[0]
        info = update.metadata(item, manifest(item))
        self.assertEqual(info["version"], "1.0.0-1")
        self.assertEqual(info["hash"], "sha256-" + base64.b64encode(hashlib.sha256(b"deb").digest()).decode())
        with self.assertRaisesRegex(ValueError, "disagree"):
            update.metadata(item, "0" * 64 + "  " + item[-1]["name"])
        with self.assertRaisesRegex(ValueError, "disagree"):
            update.metadata(item, manifest(item) * 2)
        bad = copy.deepcopy(item)
        bad[-1]["digest"] = None
        with self.assertRaisesRegex(ValueError, "no SHA-256"):
            update.metadata(bad, "")

    def test_same_url_rebuild_refreshes_hash(self):
        with patch.object(update, "manifest_for", side_effect=manifest):
            initial = update.refresh([release("v1.0.0"), release("beta-v1.0.4")], {})
            rebuilt = update.refresh([release("v1.0.0"), release("beta-v1.0.4", data=b"rebuilt")], initial)
        self.assertEqual(initial["beta"]["url"], rebuilt["beta"]["url"])
        self.assertNotEqual(initial["beta"]["hash"], rebuilt["beta"]["hash"])
        self.assertEqual(initial["stable"], rebuilt["stable"])

    def test_no_downgrade_or_unverified_replacement(self):
        with patch.object(update, "manifest_for", side_effect=manifest):
            with self.assertRaisesRegex(ValueError, "downgrade"):
                update.refresh([release("v1.0.0"), release("beta-v1.0.4")],
                               {"beta": {"version": "1.0.5-1"}})
        with patch.object(update, "manifest_for", return_value=""):
            with self.assertRaisesRegex(ValueError, "disagree"):
                update.refresh([release("v1.0.0"), release("beta-v1.0.4")], {})


if __name__ == "__main__":
    unittest.main()
