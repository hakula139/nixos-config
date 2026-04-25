#!/usr/bin/env python3
"""Regenerate PeerTube HLS segment SHA256 hashes for a re-encoded file.

Parses byte ranges from an HLS m3u8 playlist, computes SHA256 for each
segment in the corresponding fragmented MP4, and updates the SHA256 JSON.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def parse_byte_ranges(m3u8_path: Path) -> list[tuple[int, int]]:
    """Extract (offset, length) pairs from m3u8 BYTERANGE directives."""
    ranges: list[tuple[int, int]] = []
    with open(m3u8_path) as f:
        for line in f:
            m = re.match(r'#EXT-X-BYTERANGE:(\d+)@(\d+)', line.strip())
            if m:
                ranges.append((int(m.group(2)), int(m.group(1))))
            m2 = re.match(
                r'#EXT-X-MAP:.*BYTERANGE="(\d+)@(\d+)"',
                line.strip(),
            )
            if m2:
                ranges.append((int(m2.group(2)), int(m2.group(1))))
    return ranges


def compute_segment_hashes(
    fmp4_path: Path, ranges: list[tuple[int, int]]
) -> dict[str, str]:
    """Compute SHA256 for each byte range in the fragmented MP4."""
    hashes: dict[str, str] = {}
    with open(fmp4_path, 'rb') as f:
        for offset, length in ranges:
            f.seek(offset)
            data = f.read(length)
            if len(data) != length:
                print(
                    f'error: short read at offset {offset}: '
                    f'expected {length} bytes, got {len(data)}',
                    file=sys.stderr,
                )
                sys.exit(1)
            key = f'{offset}-{offset + length - 1}'
            hashes[key] = hashlib.sha256(data).hexdigest()
    return hashes


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Regenerate PeerTube HLS segment SHA256 hashes.',
    )
    parser.add_argument('fmp4', type=Path, help='fragmented MP4 file')
    parser.add_argument('m3u8', type=Path, help='HLS segment playlist')
    parser.add_argument('sha256_json', type=Path, help='SHA256 JSON to update')
    parser.add_argument(
        'filename',
        help='fMP4 filename key in the JSON (e.g. <uuid>-2160-fragmented.mp4)',
    )
    args = parser.parse_args()

    fmp4: Path = args.fmp4
    m3u8: Path = args.m3u8
    sha256_json: Path = args.sha256_json
    filename: str = args.filename

    ranges = parse_byte_ranges(m3u8)
    if not ranges:
        print(
            f'error: no BYTERANGE directives found in {m3u8}',
            file=sys.stderr,
        )
        sys.exit(1)
    new_hashes = compute_segment_hashes(fmp4, ranges)

    with open(sha256_json) as f:
        sha256_data = json.load(f)
    sha256_data[filename] = new_hashes
    with open(sha256_json, 'w') as f:
        json.dump(sha256_data, f)

    print(f'Updated {len(new_hashes)} segment hashes for {filename}')


if __name__ == '__main__':
    main()
