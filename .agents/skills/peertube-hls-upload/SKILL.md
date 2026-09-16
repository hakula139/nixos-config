---
name: peertube-hls-upload
description: >-
  Repair existing PeerTube HLS renditions in this repository by transcoding or uploading B2 files, updating playlists and segment hashes, and identifying CDN cache purges. Use when a registered rendition has missing media, failed transcodes, or broken playback.
---

# PeerTube HLS Repair

Use `scripts/peertube-hls.nu` for manual repairs to existing HLS renditions when the runner workflow cannot complete them. The helper uploads files and updates existing database rows. It does not register new renditions, create audio tracks, or reproduce PeerTube's complete transcoding lifecycle.

Start with inspection and local preparation. Uploads, database updates, and CDN purges change production, so keep them within the user's authorized repair scope. Check that no runner job is concurrently updating the same video before preparing a replacement manifest or publishing files.

## Setup and target

Run examples from the repository root in Bash:

```bash
hls=.agents/skills/peertube-hls-upload/scripts/peertube-hls.nu
"$hls" --help
"$hls" identify <VIDEO_UUID>
```

`identify` reads the PeerTube API and database on `CloudCone-US-1`. Record each existing `videoFile` row's ID, filename, resolution, FPS, dimensions, size, and storage, plus the master playlist and SHA256 filenames. Derive `FILE_UUID` from the file's actual name, not the video UUID. The work files are `/tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4` and the corresponding `<FILE_UUID>-<RESOLUTION>.m3u8`.

The script targets `v.hakula.xyz`, database `peertube`, and bucket `hakula-videos` at `https://s3.us-west-004.backblazeb2.com`. Objects live under `streaming-playlists/hls/<VIDEO_UUID>/`, served through `https://b2.hakula.xyz/hakula-videos/`. Check these constants against the target before using the helper for another server.

Local commands need Nushell, Python 3, FFmpeg / ffprobe, and Nix. `verify` also uses `strings` and `grep`. Database commands require SSH access to `CloudCone-US-1` and `sudo -u peertube psql -d peertube`. The upload helper obtains `awscli2` through `nix-shell`.

For S3 reads and uploads, decrypt credentials directly into the shell without printing them or enabling shell tracing:

```bash
peertube_credentials=$(agenix -d secrets/peertube/env.age -i ~/.ssh/CloudCone/id_ed25519) || exit 1
eval "$peertube_credentials"
unset peertube_credentials
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
```

The export lets credentials reach the `nix-shell` subprocess. It requires the corresponding agenix identity at the path shown. The repository's root `secrets.nix` maps these paths to the recipient rules. See [secrets](../../../docs/guides/secrets.md) for execution from other directories.

## Prepare the rendition

For an existing file whose hashes alone are broken, download the matching media and rendition playlist from S3 and skip transcoding. Preserve the original master, SHA256 JSON, and any objects to be replaced for recovery. Use a separate backup directory because the helpers reuse fixed filenames under `/tmp/peertube-hls/`.

For a manual transcode, use an absolute source path. `RESOLUTION` controls filenames only: neither mode scales the video. Prepare the source at the intended dimensions first. Both modes strip audio with `-an`, so use them only for video renditions whose master already supplies a working separate audio track, or for intentionally silent videos. Resolution `0` in the database denotes audio and must not be created with these transcode commands.

Remux an already suitable H.264 source without changing its encoding settings:

```bash
"$hls" transcode remux /absolute/path/to/source.mp4 <FILE_UUID> <RESOLUTION>
```

Re-encode to H.264 using the VOD settings from `packages/peertube/hq-transcode.patch`:

```bash
"$hls" transcode re-encode /absolute/path/to/source.mp4 <FILE_UUID> <RESOLUTION> <FPS>
```

`FPS` is required for re-encoding and accepts integers only. A fractional rate such as `30000/1001` needs a separate FFmpeg invocation that preserves the intended rate. The helper uses `-preset slow -crf 20 -profile:v high -b_strategy 1 -bf 16` and a single fragmented MP4 with byte-range HLS segments.

Inspect actual stream properties and check that playlist URIs name the intended object:

```bash
ffprobe -v error -show_format -show_streams -of json \
  /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4
"$hls" verify /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4
```

`verify` prints an embedded x264 options string when present. It does not test decoding, dimensions, duration, audio, or segment integrity. A remux retains the source's settings, and absence of that string is not proof of a bad file. For a new re-encode, check `rc=crf crf=20.0` and `bframes=16 b_adapt=1` against the requested settings. Encoder defaults such as reference-frame counts can vary with level constraints, so do not require one exact options string.

## Prepare playlists and integrity hashes

Read the current master and SHA256 JSON from S3 to avoid starting from a stale CDN response. For example:

```bash
mkdir -p /tmp/peertube-hls
nix-shell -p awscli2 --run "aws s3 cp \
  's3://hakula-videos/streaming-playlists/hls/<VIDEO_UUID>/<MASTER_FILENAME>' \
  /tmp/peertube-hls/master.m3u8 \
  --endpoint-url https://s3.us-west-004.backblazeb2.com"
nix-shell -p awscli2 --run "aws s3 cp \
  's3://hakula-videos/streaming-playlists/hls/<VIDEO_UUID>/<SHA256_FILENAME>' \
  /tmp/peertube-hls/segments-sha256.json \
  --endpoint-url https://s3.us-west-004.backblazeb2.com"
```

Adapt the same S3 read command for existing media and rendition playlists. Do not start an empty hash manifest for a video with other renditions: their entries must survive the repair.

### Master playlist

Update only entries affected by the repair, preserving unrelated renditions, audio groups, and subtitles. For split audio and video, an entry has this shape:

```text
#EXT-X-STREAM-INF:BANDWIDTH=<BITRATE>,RESOLUTION=<W>x<H>,FRAME-RATE=<FPS>,CODECS="<VIDEO_CODEC>,<AUDIO_CODEC>",AUDIO="audio"
<FILE_UUID>-<RESOLUTION>.m3u8
```

Use the output's actual dimensions, rate, and codec profile / level. Do not infer an AVC codec string from resolution alone, or assume the audio codec is AAC. PeerTube's current master generator computes bandwidth as `ceil(file_size_bytes * 8 / video_duration_seconds)`. Preserve an existing compatible entry when its fields remain accurate.

Adding a playlist entry alone does not register a new PeerTube rendition. If the database has no matching file row, use the supported runner workflow or prepare a separate schema-aware repair before publication.

### Segment hashes

Every changed media byte range needs matching hashes. PeerTube's normal playlist-update pipeline regenerates hashes, but direct S3 uploads and these SQL helpers bypass it. Missing entries or mismatched hashes can break quality selection or playback. Diagnose against the actual manifest and media instead of assuming every missing quality option is a hash problem.

Update the downloaded manifest locally:

```bash
"$hls" regen-sha256 <FILE_UUID> <RESOLUTION> /tmp/peertube-hls/segments-sha256.json
```

Repeat this command against the same JSON for each changed rendition. It replaces that filename's hash map and preserves other entries. The parser requires positive, explicit `length@offset` byte ranges, including the initialization map, and all map and segment URIs must name the supplied filename. It rejects playlists without media segments, unsupported ranges, mismatched resources, and reads extending beyond the media file before changing the JSON. Playlists with implicit offsets need a different parser before proceeding.

The command delegates to `scripts/regen-sha256.py`. Use that helper directly when media or playlist files live outside the work directory. Neither command downloads a manifest or uploads the result.

## Publish and reconcile

Prepare and validate all files before the first upload. Re-read the video's filenames and manifest baseline if another operation could have changed them. Keep the previous objects available until playback is verified.

Upload media first, then each rendition playlist, then the combined hash manifest. Upload the edited master last, once its dependencies are present:

```bash
"$hls" upload <VIDEO_UUID> /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>-fragmented.mp4
"$hls" upload <VIDEO_UUID> /tmp/peertube-hls/<FILE_UUID>-<RESOLUTION>.m3u8
"$hls" upload <VIDEO_UUID> /tmp/peertube-hls/segments-sha256.json <SHA256_FILENAME>
"$hls" upload <VIDEO_UUID> /tmp/peertube-hls/master.m3u8 <MASTER_FILENAME>
```

The optional final argument overrides the destination name and is required for the locally renamed master and hash files. Skip uploading an unchanged master. This sequence does not make overwrites atomic: an existing master already references the old names, and clients can observe mixed versions while publication or cache invalidation is in progress.

### Database reconciliation

Confirm that `FILE_ID` belongs to this video's existing HLS file and matches `FILE_UUID` / `RESOLUTION` before running either command. The helper updates by ID only and does not check that relationship.

```bash
"$hls" db-update-size <FILE_ID> <FILE_UUID> <RESOLUTION>
"$hls" db-update-meta <FILE_ID> <FILE_UUID> <RESOLUTION>
```

Run the size update when the media size changed and the metadata update when the probe data changed. The latter changes only the `metadata` JSON. Neither updates the separate FPS, dimensions, resolution, storage, filename, or playlist infohash fields, and neither creates a row. A repair that changes those properties needs additional reconciliation before it can be considered complete.

Inspect the SQL result and re-read the row after a write. `ON_ERROR_STOP` propagates SQL errors, but an update matching zero rows still succeeds.

## Cache and playback verification

List URLs needing invalidation:

```bash
"$hls" purge-urls <VIDEO_UUID> <MASTER_FILENAME> <SHA256_FILENAME> \
  <FILE_UUID>-<RESOLUTION>.m3u8 <FILE_UUID>-<RESOLUTION>-fragmented.mp4
```

This command only prints URLs. Perform the authorized purge through Cloudflare and confirm completion. Include every overwritten object, including media. Newly named media does not need purging unless a prior response for that name was cached.

Read back the uploaded objects through S3 and the CDN, compare them with the prepared files, and re-run `identify` for the API / database view. Verify playback and seeking at each repaired quality, audio continuity, and the absence of segment-integrity errors in the browser. If browser verification is unavailable, report that limit explicitly. Remove only this repair's local working files and backups after verification, accounting for the shared `/tmp/peertube-hls/` directory.
