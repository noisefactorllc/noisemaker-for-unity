#!/usr/bin/env python3
"""Create a deterministic Unity project for the parity harness.

The parity entrypoints (scripts/parity-summary, parity/*-verify.sh) need a
Unity project that embeds the com.noisemaker.hlsl package and uses Linear
color space. The repository ships no project, so every licensed-editor
platform (macOS, Windows, Linux) previously needed a hand-built one. This
script writes that project from the current source tree, so each platform's
qualification run starts from the same deterministic bytes.

The project is minimal by design: an empty Assets folder, a manifest with no
dependencies, a PlayerSettings asset with Linear color space, and the package
copied into Packages/. It records no editor version, so any Unity 6000.0+
editor can import it. After an editor imports the project,
scripts/parity-summary's validate_project and validate_package accept it.
"""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "unity/com.noisemaker.hlsl"

PROJECT_SETTINGS = """%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!129 &1
PlayerSettings:
  m_ActiveColorSpace: 1
"""

MANIFEST = {"dependencies": {}}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package_files(package):
    files = {}
    for path in sorted(package.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"package contains a symbolic link: {path}")
        if path.is_file():
            files[path.relative_to(package).as_posix()] = sha256(path)
    return files


def make_project(target):
    target = Path(target)
    if target.exists() and any(target.iterdir()):
        raise ValueError(f"target directory is not empty: {target}")
    if not PACKAGE.is_dir() or PACKAGE.is_symlink():
        raise ValueError(f"regular package directory is missing: {PACKAGE}")
    source = package_files(PACKAGE)
    if not source:
        raise ValueError(f"package is empty: {PACKAGE}")
    if target.exists():
        # Only an empty directory may already exist; it has no files to lose.
        target.rmdir()
    try:
        embedded = target / "Packages/com.noisemaker.hlsl"
        embedded.mkdir(parents=True)
        for name in source:
            destination = embedded / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(PACKAGE / name, destination)
        (target / "Assets").mkdir()
        settings = target / "ProjectSettings"
        settings.mkdir()
        (settings / "ProjectSettings.asset").write_text(PROJECT_SETTINGS)
        (target / "Packages/manifest.json").write_text(
            json.dumps(MANIFEST, indent=4) + "\n")
        written = package_files(embedded)
        if written != source:
            raise ValueError("embedded package differs from the source package")
        return target
    except BaseException:
        shutil.rmtree(target, ignore_errors=True)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", help="directory for the new project (must not exist or be empty)")
    args = parser.parse_args()
    try:
        target = make_project(Path(args.target))
    except (OSError, ValueError) as exc:
        print(f"make-project: {exc}", file=sys.stderr)
        return 1
    print(f"parity project created at {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
