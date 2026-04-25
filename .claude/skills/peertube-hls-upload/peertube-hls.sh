#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PeerTube HLS Manual Transcode & Upload
# ==============================================================================
# Manually transcode a video to HLS fragmented MP4 and upload it to the
# PeerTube B2 object storage bucket, bypassing the PeerTube runner workflow.
#
# Subcommands:
#   identify        Query PeerTube API and DB for video details
#   transcode       Transcode source video to HLS fragmented MP4
#   upload          Upload a local file to the B2 bucket
#   regen-sha256    Regenerate segment SHA256 hashes for a changed file
#   db-update-size  Update file size in PeerTube DB
#   db-update-meta  Update ffprobe metadata in PeerTube DB
#   verify          Check x264 encoding parameters
#   purge-urls      Print Cloudflare CDN URLs that need cache purging
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

readonly B2_ENDPOINT="https://s3.us-west-004.backblazeb2.com"
readonly B2_BUCKET="hakula-videos"
readonly B2_CDN="https://b2.hakula.xyz/${B2_BUCKET}"
readonly PEERTUBE_HOST="CloudCone-US-1"
readonly PEERTUBE_DOMAIN="v.hakula.xyz"
readonly WORK_DIR="/tmp/peertube-hls"

# HQ transcode parameters (must match packages/peertube/hq-transcode.patch)
readonly X264_PRESET="slow"
readonly X264_PROFILE="high"
readonly X264_CRF="20"
readonly X264_B_STRATEGY="1"
readonly X264_BF="16"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

# Validate UUID format (lowercase hex with dashes)
require_uuid() {
  [[ "$1" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] \
    || die "invalid UUID: $1"
}

# Validate non-negative integer
require_int() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "invalid integer: $1"
}

require_b2_credentials() {
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    die "B2 credentials not set. Run:
  eval \"\$(agenix -d peertube-env.age -i ~/.ssh/CloudCone/id_ed25519)\"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"
  fi
}

b2_prefix() {
  echo "s3://${B2_BUCKET}/streaming-playlists/hls/$1"
}

cdn_prefix() {
  echo "${B2_CDN}/streaming-playlists/hls/$1"
}

fmp4_path() {
  echo "${WORK_DIR}/$1-$2-fragmented.mp4"
}

m3u8_path() {
  echo "${WORK_DIR}/$1-$2.m3u8"
}

file_size() {
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f%z "$1"
  else
    stat --format=%s "$1"
  fi
}

# Upload a file to B2 with auto-detected content type
b2_upload() {
  local src="$1" dst="$2" content_type
  case "$(basename "${src}")" in
    *.mp4) content_type="video/mp4" ;;
    *.m3u8) content_type="application/x-mpegURL" ;;
    *.json) content_type="application/json" ;;
    *) die "unknown file extension: $(basename "${src}")" ;;
  esac

  echo "Uploading $(basename "${src}") (${content_type})..."
  # Pass paths via env vars to avoid shell injection in --run string
  export B2_SRC="${src}" B2_DST="${dst}" B2_EP="${B2_ENDPOINT}" B2_CT="${content_type}"
  # shellcheck disable=SC2016  # intentional: vars expand inside nix-shell, not here
  nix-shell -p awscli2 \
    --keep AWS_ACCESS_KEY_ID \
    --keep AWS_SECRET_ACCESS_KEY \
    --keep B2_SRC \
    --keep B2_DST \
    --keep B2_EP \
    --keep B2_CT \
    --run 'aws s3 cp "$B2_SRC" "$B2_DST" --endpoint-url "$B2_EP" --content-type "$B2_CT"'
  unset B2_SRC B2_DST B2_EP B2_CT
}

# Run a psql query on the PeerTube DB via SSH
pt_psql() {
  ssh "${PEERTUBE_HOST}" "sudo -u peertube psql -d peertube"
}

# ------------------------------------------------------------------------------
# Subcommands
# ------------------------------------------------------------------------------

cmd_identify() {
  local video_uuid="$1"
  require_uuid "${video_uuid}"

  echo "=== API: Video details ==="
  # shellcheck disable=SC2029  # intentional client-side expansion
  ssh "${PEERTUBE_HOST}" "
    sudo -u peertube curl -s \
      'http://127.0.0.1:9000/api/v1/videos/${video_uuid}' \
      -H 'Host: ${PEERTUBE_DOMAIN}' \
    | jq '{
      uuid, name, state,
      files: [.files[] | {resolution: .resolution.id, size}],
      streamingPlaylists: [.streamingPlaylists[] | {
        type, playlistUrl,
        files: [.files[] | {resolution: .resolution.id, size, fps}]
      }]
    }'
  "

  echo ""
  echo "=== DB: HLS file details ==="
  pt_psql <<SQL
SELECT vf.id, vf.resolution, vf.fps, vf.width, vf.height, vf.size, vf.filename, vf.storage
FROM "videoFile" vf
JOIN "videoStreamingPlaylist" vsp
  ON vsp.id = vf."videoStreamingPlaylistId"
JOIN video v
  ON v.id = vsp."videoId"
WHERE v.uuid = '${video_uuid}'
ORDER BY vf.resolution;
SQL

  echo ""
  echo "=== DB: Streaming playlist metadata ==="
  pt_psql <<SQL
SELECT vsp."playlistFilename", vsp."segmentsSha256Filename"
FROM "videoStreamingPlaylist" vsp
JOIN video v
  ON v.id = vsp."videoId"
WHERE v.uuid = '${video_uuid}';
SQL
}

cmd_transcode() {
  local mode="$1" source="$2" file_uuid="$3" resolution="$4"
  local fps="${5:-}"
  require_uuid "${file_uuid}"
  require_int "${resolution}"
  [[ -z "${fps}" ]] || require_int "${fps}"

  [[ -f "${source}" ]] || die "source file not found: ${source} (use absolute paths)"

  mkdir -p "${WORK_DIR}"
  local fmp4 m3u8
  fmp4=$(fmp4_path "${file_uuid}" "${resolution}")
  m3u8=$(m3u8_path "${file_uuid}" "${resolution}")

  local hls_args=(
    -f hls
    -hls_time 4
    -hls_list_size 0
    -hls_playlist_type vod
    -hls_segment_type fmp4
    -hls_flags single_file
    -hls_segment_filename "${fmp4}"
  )

  case "${mode}" in
    remux)
      ffmpeg -i "${source}" \
        -an -c:v copy \
        "${hls_args[@]}" \
        "${m3u8}"
      ;;
    re-encode)
      [[ -n "${fps}" ]] || die "fps is required for re-encode mode"
      ffmpeg -i "${source}" \
        -an -c:v libx264 \
        -preset "${X264_PRESET}" \
        -profile:v "${X264_PROFILE}" \
        -crf "${X264_CRF}" \
        -b_strategy "${X264_B_STRATEGY}" \
        -bf "${X264_BF}" \
        -r "${fps}" \
        "${hls_args[@]}" \
        "${m3u8}"
      ;;
    *)
      die "unknown mode: ${mode} (use 'remux' or 're-encode')"
      ;;
  esac

  echo ""
  echo "Output:"
  echo "  fmp4: ${fmp4} ($(file_size "${fmp4}") bytes)"
  echo "  m3u8: ${m3u8}"
}

cmd_upload() {
  local video_uuid="$1" file="$2" dest_name="${3:-}"
  require_uuid "${video_uuid}"
  require_b2_credentials

  [[ -f "${file}" ]] || die "file not found: ${file}"

  local prefix
  prefix=$(b2_prefix "${video_uuid}")
  [[ -n "${dest_name}" ]] || dest_name=$(basename "${file}")
  b2_upload "${file}" "${prefix}/${dest_name}"
}

cmd_regen_sha256() {
  local video_uuid="$1" sha256_filename="$2" file_uuid="$3" resolution="$4"
  require_uuid "${video_uuid}"
  require_uuid "${file_uuid}"
  require_int "${resolution}"

  mkdir -p "${WORK_DIR}"
  local fmp4 m3u8 sha256_url sha256_local
  fmp4=$(fmp4_path "${file_uuid}" "${resolution}")
  m3u8=$(m3u8_path "${file_uuid}" "${resolution}")
  sha256_url="$(cdn_prefix "${video_uuid}")/${sha256_filename}"
  sha256_local="${WORK_DIR}/segments-sha256.json"

  [[ -f "${fmp4}" ]] || die "fmp4 not found: ${fmp4}"
  [[ -f "${m3u8}" ]] || die "m3u8 not found: ${m3u8}"

  echo "Downloading current SHA256 JSON..."
  curl -fsSL -H "Cache-Control: no-cache" "${sha256_url}" >"${sha256_local}"

  echo "Regenerating hashes..."
  local fmp4_filename="${file_uuid}-${resolution}-fragmented.mp4"
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  python3 "${script_dir}/regen-sha256.py" \
    "${fmp4}" "${m3u8}" "${sha256_local}" "${fmp4_filename}"

  echo "SHA256 JSON saved to: ${sha256_local}"
  echo ""
  echo "Now upload it:"
  echo "  $0 upload '${video_uuid}' '${sha256_local}' '${sha256_filename}'"
}

cmd_db_update_size() {
  local file_id="$1" file_uuid="$2" resolution="$3"
  require_int "${file_id}"
  require_uuid "${file_uuid}"
  require_int "${resolution}"

  local fmp4 new_size
  fmp4=$(fmp4_path "${file_uuid}" "${resolution}")
  [[ -f "${fmp4}" ]] || die "fmp4 not found: ${fmp4}"

  new_size=$(file_size "${fmp4}")
  echo "Updating videoFile id=${file_id} size to ${new_size}..."

  pt_psql <<SQL
UPDATE "videoFile"
SET size = ${new_size}
WHERE id = ${file_id};
SQL
}

cmd_db_update_meta() {
  local file_id="$1" file_uuid="$2" resolution="$3"
  require_int "${file_id}"
  require_uuid "${file_uuid}"
  require_int "${resolution}"

  local fmp4 metadata_file metadata
  fmp4=$(fmp4_path "${file_uuid}" "${resolution}")
  [[ -f "${fmp4}" ]] || die "fmp4 not found: ${fmp4}"

  metadata_file="${WORK_DIR}/metadata-${file_uuid}-${resolution}.json"
  ffprobe -v quiet -print_format json -show_format -show_streams "${fmp4}" >"${metadata_file}"
  metadata=$(jq -c '.' "${metadata_file}")

  echo "Updating videoFile id=${file_id} metadata..."

  local escaped_metadata="${metadata//\'/\'\'}"

  pt_psql <<SQL
UPDATE "videoFile"
SET metadata = '${escaped_metadata}'
WHERE id = ${file_id};
SQL
}

cmd_verify() {
  local target="$1"
  if [[ "${target}" == http* ]]; then
    echo "Fetching first 256 KB from remote..."
    curl -s -r 0-262143 "${target}" | strings | grep 'x264.*options:' || echo "(no x264 options found)"
  else
    [[ -f "${target}" ]] || die "file not found: ${target}"
    strings "${target}" | grep 'x264.*options:' || echo "(no x264 options found)"
  fi
}

cmd_purge_urls() {
  local video_uuid="$1"
  require_uuid "${video_uuid}"
  shift

  local prefix
  prefix=$(cdn_prefix "${video_uuid}")

  echo "Cloudflare CDN URLs to purge:"
  for filename in "$@"; do
    echo "  ${prefix}/${filename}"
  done
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: peertube-hls.sh <command> [args...]

Commands:
  identify        <VIDEO_UUID>
  transcode       <remux|re-encode> <SOURCE_FILE> <FILE_UUID> <RESOLUTION> [FPS]
  upload          <VIDEO_UUID> <LOCAL_FILE> [DEST_NAME]
  regen-sha256    <VIDEO_UUID> <SHA256_FILENAME> <FILE_UUID> <RESOLUTION>
  db-update-size  <FILE_ID> <FILE_UUID> <RESOLUTION>
  db-update-meta  <FILE_ID> <FILE_UUID> <RESOLUTION>
  verify          <FILE_OR_URL>
  purge-urls      <VIDEO_UUID> <FILENAME>...

Parameters:
  VIDEO_UUID       Video UUID (e.g., 4c4efc20-bb9e-4f7c-a20c-738791ac8605)
  FILE_UUID        Per-file UUID prefix (e.g., ea2aebdd-b5cf-41c0-add4-63fa8d5fb6ea)
  RESOLUTION       Numeric resolution (2160, 1080, 720, 480, or 0 for audio)
  FPS              Frames per second (required for re-encode mode)
  FILE_ID          DB row ID from videoFile table
  SHA256_FILENAME  Full SHA256 JSON filename from DB
  SOURCE_FILE      Absolute path to source video (~ is NOT expanded)
  DEST_NAME        Override the B2 object name (defaults to local filename)

Environment:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY  (required for upload)
    Decrypt with:
      eval "$(agenix -d peertube-env.age -i ~/.ssh/CloudCone/id_ed25519)"
      export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
EOF
}

main() {
  [[ $# -ge 1 ]] || {
    usage
    exit 1
  }

  local command="$1"
  shift

  case "${command}" in
    identify)
      [[ $# -ge 1 ]] || die "usage: identify <VIDEO_UUID>"
      cmd_identify "$@"
      ;;
    transcode)
      [[ $# -ge 4 ]] || die "usage: transcode <remux|re-encode> <SOURCE_FILE> <FILE_UUID> <RESOLUTION> [FPS]"
      cmd_transcode "$@"
      ;;
    upload)
      [[ $# -ge 2 ]] || die "usage: upload <VIDEO_UUID> <LOCAL_FILE> [DEST_NAME]"
      cmd_upload "$@"
      ;;
    regen-sha256)
      [[ $# -ge 4 ]] || die "usage: regen-sha256 <VIDEO_UUID> <SHA256_FILENAME> <FILE_UUID> <RESOLUTION>"
      cmd_regen_sha256 "$@"
      ;;
    db-update-size)
      [[ $# -ge 3 ]] || die "usage: db-update-size <FILE_ID> <FILE_UUID> <RESOLUTION>"
      cmd_db_update_size "$@"
      ;;
    db-update-meta)
      [[ $# -ge 3 ]] || die "usage: db-update-meta <FILE_ID> <FILE_UUID> <RESOLUTION>"
      cmd_db_update_meta "$@"
      ;;
    verify)
      [[ $# -ge 1 ]] || die "usage: verify <FILE_OR_URL>"
      cmd_verify "$@"
      ;;
    purge-urls)
      [[ $# -ge 2 ]] || die "usage: purge-urls <VIDEO_UUID> <FILENAME>..."
      cmd_purge_urls "$@"
      ;;
    help | --help | -h)
      usage
      ;;
    *)
      die "unknown command: ${command} (run with 'help' for usage)"
      ;;
  esac
}

main "$@"
