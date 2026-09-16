#!/usr/bin/env python3
"""Regenerate PeerTube HLS segment SHA256 hashes for a changed media file.

Parses byte ranges from an HLS m3u8 playlist, computes SHA256 for each
segment in the corresponding fragmented MP4, and updates the SHA256 JSON.

Run with `--help` for usage.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def parse_byte_ranges(m3u8_path: Path, filename: str) -> list[tuple[int, int]]:
    """Extract explicit (offset, length) pairs from a single-file HLS playlist."""
    ranges: list[tuple[int, int]] = []
    pending_segment = False
    has_segments = False
    with open(m3u8_path) as f:
        for line_number, line in enumerate(f, start=1):
            line = line.strip()
            if line.startswith('#EXT-X-BYTERANGE:'):
                if pending_segment:
                    raise ValueError(f'{m3u8_path}:{line_number}: missing segment URI')
                match = re.fullmatch(r'#EXT-X-BYTERANGE:(\d+)@(\d+)', line)
                pending_segment = True
            elif line.startswith('#EXT-X-MAP:'):
                uri = re.search(r'[:,]URI="([^"]*)"(?:,|$)', line)
                if not uri or uri.group(1) != filename:
                    raise ValueError(
                        f'{m3u8_path}:{line_number}: map URI must be {filename}',
                    )
                match = re.search(r'[:,]BYTERANGE="(\d+)@(\d+)"(?:,|$)', line)
            else:
                if line and not line.startswith('#'):
                    if line != filename or not pending_segment:
                        raise ValueError(
                            f'{m3u8_path}:{line_number}: '
                            f'expected {filename} with an explicit byte range',
                        )
                    pending_segment = False
                    has_segments = True
                continue
            if not match or int(match.group(1)) == 0:
                raise ValueError(
                    f'{m3u8_path}:{line_number}: '
                    'expected a positive byte range with an explicit offset',
                )
            ranges.append((int(match.group(2)), int(match.group(1))))
    if pending_segment:
        raise ValueError(f'{m3u8_path}: missing segment URI after byte range')
    if not has_segments:
        raise ValueError(f'{m3u8_path}: no media segments found')
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

    try:
        ranges = parse_byte_ranges(m3u8, filename)
    except ValueError as error:
        parser.error(str(error))
    new_hashes = compute_segment_hashes(fmp4, ranges)

    with open(sha256_json) as f:
        sha256_data = json.load(f)
    sha256_data[filename] = new_hashes
    with open(sha256_json, 'w') as f:
        json.dump(sha256_data, f)

    print(f'Updated {len(new_hashes)} segment hashes for {filename}')


if __name__ == '__main__':
    main()
