---
name: peertube-hls-upload
description: Manually transcode a video to HLS fragmented MP4 and upload it to the self-hosted PeerTube B2 bucket (v.hakula.xyz / hakula-videos), bypassing the PeerTube runner. Use this skill whenever the user is fixing a broken or missing PeerTube video resolution, working around a failed or too-slow runner transcode, regenerating the segments-sha256 hashes that PeerTube uses for HLS integrity, editing an HLS master playlist to add or replace a quality variant, purging stale Cloudflare CDN cache for v.hakula.xyz / b2.hakula.xyz, or doing any manual HLS / B2 / ffmpeg / database work tied to PeerTube, even if they don't say "skill" or name the script directly. Trigger on phrases like "peertube transcode failed", "fix broken peertube video", "re-encode this resolution", "upload HLS to B2", "regen sha256 for peertube", "missing quality on v.hakula.xyz", or any PeerTube troubleshooting that involves touching B2 / Cloudflare / fMP4 files.
---

# PeerTube HLS Manual Transcode & Upload

Manually transcode a video to HLS fragmented MP4 and upload it to the PeerTube B2 object storage bucket, bypassing the PeerTube runner workflow. Use when re-transcoding fails, is too slow via the runner, or when fixing broken / missing HLS files.

**Script**: `peertube-hls.nu` (sibling to this `SKILL.md`), where all operations are implemented as subcommands. Run with `--help` for the subcommand list, or `<subcommand> --help` for one command's parameters. The Python helper `regen-sha256.py` lives next to it and is invoked by the `regen-sha256` subcommand.

## Prerequisites

- `ffmpeg` / `ffprobe` (available in the system)
- `awscli2` (used via `nix-shell -p awscli2`, which the script invokes automatically)
- SSH access to `CloudCone-US-1` (PeerTube server)
- Agenix decryption key at `~/.ssh/CloudCone/id_ed25519`

## Infrastructure Reference

- **PeerTube server**: `CloudCone-US-1` (SSH alias)
- **PeerTube domain**: `v.hakula.xyz`
- **B2 bucket**: `hakula-videos`
- **B2 S3 endpoint**: `s3.us-west-004.backblazeb2.com`
- **B2 CDN base URL**: `https://b2.hakula.xyz/hakula-videos`
- **PeerTube DB**: `peertube` (accessed via `sudo -u peertube psql -d peertube`)
- **Encoding patch**: `packages/peertube/hq-transcode.patch` — VOD uses `-preset slow -crf 20 -profile:v high -b_strategy 1 -bf 16`

## Parameter Naming

Parameters used across subcommands (the script validates UUID and integer formats):

| Parameter         | Description                           | Example                                   |
| ----------------- | ------------------------------------- | ----------------------------------------- |
| `VIDEO_UUID`      | Video's UUID                          | `4c4efc20-bb9e-4f7c-a20c-738791ac8605`    |
| `FILE_UUID`       | Per-file UUID prefix                  | `ea2aebdd-b5cf-41c0-add4-63fa8d5fb6ea`    |
| `RESOLUTION`      | Numeric resolution                    | `2160`, `1080`, `720`, `480`, `0` (audio) |
| `FPS`             | Frames per second                     | `30`, `60`                                |
| `FILE_ID`         | DB row ID from `videoFile` table      | `21`                                      |
| `SHA256_FILENAME` | Full SHA256 JSON filename from DB     | `83744bf4-...-segments-sha256.json`       |
| `MASTER_FILENAME` | Full master playlist filename from DB | `197b0cec-...-master.m3u8`                |

File paths in the working directory (`/tmp/peertube-hls/`) are derived from `FILE_UUID` and `RESOLUTION`:

- fMP4: `<FILE_UUID>-<RESOLUTION>-fragmented.mp4`
- m3u8: `<FILE_UUID>-<RESOLUTION>.m3u8`

## Workflow

### Step 1: Identify the Video

```bash
./peertube-hls.nu identify <VIDEO_UUID>
```

This runs three queries (PeerTube API, HLS file details, streaming playlist metadata) and prints all the UUIDs, filenames, and DB IDs needed for subsequent steps.

### Step 2: Get B2 Credentials

```bash
eval "$(agenix -d peertube/env.age -i ~/.ssh/CloudCone/id_ed25519)"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
```

The `export` is required, since without it credentials don't propagate into the `nix-shell` subshells that the script uses for `aws` commands.

### Step 3: Transcode

#### Option A: Remux (same codec, no re-encode, seconds)

Use when the source is already H.264 at the target resolution:

```bash
./peertube-hls.nu transcode remux /absolute/path/to/source.mp4 <FILE_UUID> <RESOLUTION>
```

#### Option B: Re-encode (codec / quality change, minutes to hours)

Use when transcoding from VP9 / AV1 / other to H.264, or re-encoding with different quality settings:

```bash
./peertube-hls.nu transcode re-encode /absolute/path/to/source.mp4 <FILE_UUID> <RESOLUTION> <FPS>
```

**Important**: Use absolute paths for source files. ffmpeg does not expand `~`.

Key parameters applied by the script (matching `hq-transcode.patch`):

- `-an`: Strip audio (PeerTube uses separated audio, shared across resolutions)
- `-preset slow -crf 20 -profile:v high -b_strategy 1 -bf 16`
- `-hls_flags single_file`: Single fragmented MP4 with byte-range addressing

#### Verify encoding

```bash
./peertube-hls.nu verify /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4
```

Expected: `rc=crf crf=20.0 ... ref=5 subme=8 trellis=2 rc_lookahead=50 ... bframes=16 b_adapt=1`

If you see `ref=1 subme=2 trellis=0 rc_lookahead=10`, the file uses the old `-preset veryfast` and needs re-encoding.

### Step 4: Upload to B2

Upload in order: **fragmented MP4 first, then segment playlist** (so the player never references a file that doesn't exist yet):

```bash
./peertube-hls.nu upload <VIDEO_UUID> /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4
./peertube-hls.nu upload <VIDEO_UUID> /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>.m3u8
```

### Step 5: Update the Master Playlist

Download the current master playlist:

```bash
curl -s 'https://b2.hakula.xyz/hakula-videos/streaming-playlists/hls/<VIDEO_UUID>/<MASTER_FILENAME>' \
  > /tmp/peertube-hls/master.m3u8
```

Edit it to add / update the resolution entry. The `#EXT-X-STREAM-INF` format:

```text
#EXT-X-STREAM-INF:BANDWIDTH=<BITRATE>,RESOLUTION=<W>x<H>,FRAME-RATE=<FPS>,CODECS="<CODEC>,mp4a.40.2",AUDIO="audio"
<FILE_UUID>-<RESOLUTION>.m3u8
```

Where:

- `BANDWIDTH`: `file_size_bytes * 8 / duration_seconds`
- `CODECS` (H.264 High profile):
  - `avc1.64001f` — 480p
  - `avc1.640020` — 720p
  - `avc1.640032` — 1080p
  - `avc1.640033` — 2160p @ 30fps
  - `avc1.640034` — 2160p @ 60fps

Upload the updated master playlist **last**:

```bash
./peertube-hls.nu upload <VIDEO_UUID> /tmp/peertube-hls/master.m3u8 <MASTER_FILENAME>
```

The third argument (`DEST_NAME`) overrides the B2 object name. Without it, the upload uses the local filename, which would be wrong here.

### Step 6: Update the Database (if needed)

Only needed when the file size changed (re-encode produces different size than what's in the DB):

```bash
./peertube-hls.nu db-update-size <FILE_ID> <FILE_UUID> <RESOLUTION>
```

To also update the stored ffprobe metadata (recommended for re-encodes):

```bash
./peertube-hls.nu db-update-meta <FILE_ID> <FILE_UUID> <RESOLUTION>
```

### Step 7: Update Segments SHA256

**This step is NOT optional.** PeerTube verifies HLS segment integrity using a SHA256 JSON file. PeerTube does **not** auto-regenerate this file, not even when the runner transcodes a new resolution.

**Symptoms of missing / stale hashes:**

- **Missing key** (fMP4 filename absent from JSON): The resolution **silently disappears** from the quality selector: no error in the UI, no console message about hashes. Diagnose by checking whether the SHA256 JSON has an entry for the fMP4 filename.
- **Hash mismatch** (key exists but hashes are wrong): The resolution appears but segments fail to play, with console errors:

  ```text
  Hashes does not correspond for segment <UUID>-<RES>-fragmented.mp4/<RANGE>
  (expected: <old_hash> instead of <new_hash>)
  ```

**Regenerate and upload:**

```bash
./peertube-hls.nu regen-sha256 <VIDEO_UUID> <SHA256_FILENAME> <FILE_UUID> <RESOLUTION>
./peertube-hls.nu upload <VIDEO_UUID> /tmp/peertube-hls/segments-sha256.json <SHA256_FILENAME>
```

**Note**: The `regen-sha256` command requires the fMP4 and m3u8 files locally in `/tmp/peertube-hls/`. If you're fixing a runner-transcoded file (not a manual transcode), download them from B2 first:

```bash
mkdir -p /tmp/peertube-hls
curl -o /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>.m3u8 \
  'https://b2.hakula.xyz/hakula-videos/streaming-playlists/hls/<VIDEO_UUID>/<FILE_UUID>-<RESOLUTION>.m3u8'
curl -o /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4 \
  'https://b2.hakula.xyz/hakula-videos/streaming-playlists/hls/<VIDEO_UUID>/<FILE_UUID>-<RESOLUTION>-fragmented.mp4'
```

The `regen-sha256` command downloads the current SHA256 JSON from B2 CDN with a `Cache-Control: no-cache` header. If the CDN still serves a stale cached version, download directly via the S3 API instead.

### Step 8: Purge Cloudflare CDN Cache

B2 is served through Cloudflare CDN (`b2.hakula.xyz`). After uploading updated files, the CDN may serve stale cached versions.

```bash
./peertube-hls.nu purge-urls <VIDEO_UUID> <MASTER_FILENAME> <SHA256_FILENAME> <FILE_UUID>-<RESOLUTION>.m3u8
```

This prints the URLs to purge. Purge them in the Cloudflare dashboard.

The fragmented MP4 does **not** need purging if it's a new file. If overwriting an existing file, include it too.

### Cleanup

After verifying everything works in the player:

```bash
rm -rf /tmp/peertube-hls/
```

## Verifying Encoding Parameters (Bulk)

To check any existing remote HLS file:

```bash
./peertube-hls.nu verify 'https://b2.hakula.xyz/hakula-videos/streaming-playlists/hls/<VIDEO_UUID>/<FILENAME>'
```

Key indicators:

- `rc=crf crf=20.0` — correct CRF mode and value
- `ref=5 subme=8 trellis=2 rc_lookahead=50` — `-preset slow` (correct)
- `ref=1 subme=2 trellis=0 rc_lookahead=10` — `-preset veryfast` (OLD, needs re-encode)
- `bframes=16 b_adapt=1` — correct `-bf 16 -b_strategy 1`
