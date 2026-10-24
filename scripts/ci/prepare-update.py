#!/usr/bin/env python3
"""Create updater metadata only after the public asset matches the local ZIP."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time
from urllib.parse import quote
from urllib.request import urlopen
import zipfile


def digest(stream):
    result = hashlib.sha256()
    size = 0
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        result.update(chunk)
        size += len(chunk)
    return size, result.hexdigest()


def prepare_update(package, assets, repository, tag):
    package = Path(package)
    with package.open("rb") as stream:
        expected = digest(stream)
    matches = [asset for asset in assets if asset.get("name") == package.name]
    if len(matches) != 1:
        raise ValueError("Expected exactly one uploaded release asset")
    asset = matches[0]
    if asset.get("state") != "uploaded" or asset.get("size") != expected[0] or expected[0] == 0:
        raise ValueError("Release asset is incomplete or has the wrong size")
    url = asset.get("browser_download_url", "")
    if not url.startswith(f"https://github.com/{repository}/releases/download/"):
        raise ValueError("Unexpected public release asset URL")
    error = None
    for attempt in range(5):
        try:
            # Public updater clients have no GitHub token. Verify the same URL
            # without authentication, and never send credentials to redirects.
            with urlopen(url, timeout=30) as stream:
                actual = digest(stream)
            if actual != expected:
                raise ValueError("Public ZIP does not match the local release package")
            break
        except (OSError, ValueError) as exc:
            error = exc
            if attempt == 4:
                raise RuntimeError("Public release ZIP verification failed") from error
            time.sleep(3)
    with zipfile.ZipFile(package) as archive:
        props = dict(line.split("=", 1) for line in archive.read("module.prop").decode().splitlines() if "=" in line)
    code = int(props["versionCode"])
    if not props.get("version") or code <= 0:
        raise ValueError("Invalid packaged module version")
    return {
        "version": props["version"],
        "versionCode": code,
        "zipUrl": url,
        "changelog": f"https://raw.githubusercontent.com/{repository}/{quote(tag, safe='')}/changelog.md",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    data = prepare_update(args.package, json.loads(os.environ["RELEASE_ASSETS"]), args.repository, args.tag)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_suffix(".json.tmp")
    temp.write_text(json.dumps(data, indent=2) + "\n")
    temp.replace(output)
    print("Verified public release ZIP; updater metadata is ready")


if __name__ == "__main__":
    main()
