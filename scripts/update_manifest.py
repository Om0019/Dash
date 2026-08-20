#!/usr/bin/env python3
"""Updates apps.json (the AltStore/SideStore source manifest) with a new
release entry. Run after building and publishing Dash.ipa as a GitHub
Release asset.
"""
import argparse
import json
import pathlib
import sys

MANIFEST_PATH = pathlib.Path(__file__).resolve().parent.parent / "apps.json"
BUNDLE_ID = "com.orlando.dash"


def load_manifest() -> dict:
    if MANIFEST_PATH.exists():
        return json.loads(MANIFEST_PATH.read_text())
    return {
        "name": "Dash",
        "identifier": "com.orlando.dash.altstore-source",
        "sourceURL": "https://raw.githubusercontent.com/Om0019/Dash/main/apps.json",
        "apps": [
            {
                "name": "Dash",
                "bundleIdentifier": BUNDLE_ID,
                "developerName": "Orlando",
                "subtitle": "Home Screen widgets for the Orlando dashboard",
                "localizedDescription": (
                    "A SwiftUI companion app and WidgetKit extension that brings "
                    "the Orlando dashboard to the iOS Home Screen as widgets."
                ),
                "iconURL": "https://raw.githubusercontent.com/Om0019/Dash/main/Dash/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
                "tintColor": "000000",
                "versions": [],
            }
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--date", required=True, help="ISO 8601, e.g. 2026-08-20T00:00:00Z")
    parser.add_argument("--size", required=True, type=int, help="ipa size in bytes")
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--notes", default="")
    args = parser.parse_args()

    manifest = load_manifest()
    app = manifest["apps"][0]

    version_entry = {
        "version": args.version,
        "date": args.date,
        "size": args.size,
        "sha256": args.sha256,
        "downloadURL": args.download_url,
        "localizedDescription": args.notes or f"Dash {args.version}",
        "minOSVersion": "17.0",
    }

    versions = app.setdefault("versions", [])
    versions = [v for v in versions if v.get("version") != args.version]
    versions.insert(0, version_entry)
    app["versions"] = versions

    # Mirror the latest release at the top level for older AltStore parsers
    # that don't read the "versions" array.
    app["version"] = args.version
    app["versionDate"] = args.date
    app["size"] = args.size
    app["sha256"] = args.sha256
    app["downloadURL"] = args.download_url

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Updated {MANIFEST_PATH} with version {args.version}")


if __name__ == "__main__":
    sys.exit(main())
