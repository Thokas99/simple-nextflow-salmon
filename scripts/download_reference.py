#!/usr/bin/env python3
"""Download the three official GENCODE inputs with MD5 verification."""

from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.error
import urllib.request
from pathlib import Path


def expected_files(release: int, patch: int) -> list[str]:
    return [
        f"gencode.v{release}.transcripts.fa.gz",
        f"GRCh38.p{patch}.genome.fa.gz",
        f"gencode.v{release}.chr_patch_hapl_scaff.annotation.gtf.gz",
    ]


def _checksums(base_url: str) -> dict[str, str]:
    with urllib.request.urlopen(f"{base_url.rstrip('/')}/MD5SUMS", timeout=60) as response:
        values = {}
        for line in response.read().decode("ascii").splitlines():
            fields = line.split()
            if len(fields) >= 2:
                values[fields[1].lstrip("*")] = fields[0].lower()
        return values


def _download(url: str, target: Path, expected_md5: str) -> None:
    part = target.with_name(target.name + ".part")
    if target.exists():
        if target.is_file() and target.stat().st_size > 0:
            return
        raise RuntimeError(f"refusing to replace existing invalid reference: {target}")
    part.unlink(missing_ok=True)
    digest = hashlib.md5()
    try:
        with urllib.request.urlopen(url, timeout=60) as response, part.open("wb") as handle:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                handle.write(chunk)
        if digest.hexdigest() != expected_md5:
            raise RuntimeError(
                f"MD5 mismatch for {target.name}: expected {expected_md5}, got {digest.hexdigest()}"
            )
        if part.stat().st_size == 0:
            raise RuntimeError(f"downloaded file is empty: {target.name}")
        part.replace(target)
    finally:
        part.unlink(missing_ok=True)


def download_reference(reference_dir: Path, release: int, patch: int, base_url: str) -> list[str]:
    reference_dir.mkdir(parents=True, exist_ok=True)
    files = expected_files(release, patch)
    checksums = _checksums(base_url)
    missing_checksums = [name for name in files if name not in checksums]
    if missing_checksums:
        raise RuntimeError("MD5SUMS has no entries for: " + ", ".join(missing_checksums))
    messages = []
    for name in files:
        target = reference_dir / name
        if target.is_file() and target.stat().st_size > 0:
            messages.append(f"Using existing {target}")
            continue
        _download(f"{base_url.rstrip('/')}/{name}", target, checksums[name])
        messages.append(f"Downloaded and verified {target}")
    return messages


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference-dir", type=Path, required=True)
    parser.add_argument("--gencode-release", type=int, required=True)
    parser.add_argument("--genome-patch", type=int, required=True)
    parser.add_argument(
        "--base-url",
        default="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_{release}",
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args(argv)
    base_url = args.base_url.format(release=args.gencode_release)
    try:
        for message in download_reference(args.reference_dir, args.gencode_release, args.genome_patch, base_url):
            print(message)
        return 0
    except (OSError, RuntimeError, UnicodeError, urllib.error.URLError) as exc:
        print(f"Reference download failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
