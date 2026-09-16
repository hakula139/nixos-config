#!/usr/bin/env nu

# ==============================================================================
# PeerTube HLS Manual Transcode & Upload
# ==============================================================================
# Manually transcode a video to HLS fragmented MP4 and upload it to the
# PeerTube B2 object storage bucket, bypassing the PeerTube runner workflow.
#
# Run with `--help` for usage.
# ==============================================================================

const SCRIPT_DIR = path self .

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

const B2_BUCKET = "hakula-videos"
const B2_CDN = "https://b2.hakula.xyz/hakula-videos"
const B2_ENDPOINT = "https://s3.us-west-004.backblazeb2.com"

const PEERTUBE_DOMAIN = "v.hakula.xyz"
const PEERTUBE_HOST = "CloudCone-US-1"

const WORK_DIR = "/tmp/peertube-hls"

# HQ transcode parameters (must match packages/peertube/hq-transcode.patch)
const X264_PRESET = "slow"
const X264_CRF = "20"
const X264_PROFILE = "high"
const X264_B_STRATEGY = "1"
const X264_BF = "16"

const CREDENTIAL_HINT = "B2 credentials not set. Run in Bash from the repository root:
  peertube_credentials=$(agenix -d secrets/peertube/env.age -i ~/.ssh/CloudCone/id_ed25519) || exit 1
  eval \"$peertube_credentials\"
  unset peertube_credentials
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"

# ------------------------------------------------------------------------------
# Queries
# ------------------------------------------------------------------------------

const API_JQ_FILTER = r#'{
  uuid, name, state,
  files: [.files[] | {resolution: .resolution.id, size}],
  streamingPlaylists: [.streamingPlaylists[] | {
    type, playlistUrl,
    files: [.files[] | {resolution: .resolution.id, size, fps}]
  }]
}'#

const SQL_HLS_FILES = r#'
SELECT vf.id, vf.resolution, vf.fps, vf.width, vf.height, vf.size, vf.filename, vf.storage
FROM "videoFile" vf
JOIN "videoStreamingPlaylist" vsp
  ON vsp.id = vf."videoStreamingPlaylistId"
JOIN video v
  ON v.id = vsp."videoId"
WHERE v.uuid = :'uuid'
ORDER BY vf.resolution;
'#

const SQL_PLAYLIST_META = r#'
SELECT vsp."playlistFilename", vsp."segmentsSha256Filename"
FROM "videoStreamingPlaylist" vsp
JOIN video v
  ON v.id = vsp."videoId"
WHERE v.uuid = :'uuid';
'#

const SQL_UPDATE_SIZE = r#'
UPDATE "videoFile"
SET size = :size
WHERE id = :id;
'#

const SQL_UPDATE_META = r#'
UPDATE "videoFile"
SET metadata = :'metadata'
WHERE id = :id;
'#

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

def die [msg: string] {
  print -e $"error: ($msg)"
  exit 1
}

def require-uuid [value: string] {
  if not ($value =~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
    die $"invalid UUID: ($value)"
  }
}

def require-int [value: string] {
  if not ($value =~ '^[0-9]+$') {
    die $"invalid integer: ($value)"
  }
}

def require-file [path: string, label: string] {
  if not ($path | path exists) {
    die $"($label): ($path)"
  }
}

def require-b2-credentials [] {
  if ($env.AWS_ACCESS_KEY_ID? | is-empty) or ($env.AWS_SECRET_ACCESS_KEY? | is-empty) {
    die $CREDENTIAL_HINT
  }
}

def b2-prefix [video_uuid: string]: nothing -> string {
  $"s3://($B2_BUCKET)/streaming-playlists/hls/($video_uuid)"
}

def cdn-prefix [video_uuid: string]: nothing -> string {
  $"($B2_CDN)/streaming-playlists/hls/($video_uuid)"
}

def fmp4-path [file_uuid: string, resolution: string]: nothing -> string {
  $"($WORK_DIR)/($file_uuid)-($resolution)-fragmented.mp4"
}

def m3u8-path [file_uuid: string, resolution: string]: nothing -> string {
  $"($WORK_DIR)/($file_uuid)-($resolution).m3u8"
}

def file-size [path: string]: nothing -> int {
  ls -l $path | get size.0 | into int
}

# `nix-shell --run` and `ssh` both hand their command to a shell, so every
# interpolated value needs POSIX quoting. A literal `'` closes the quote, emits
# an escaped one, and reopens.
def sh-quote [value: string]: nothing -> string {
  "'" + ($value | str replace --all "'" "'\\''") + "'"
}

def sh-join [args: list<string>]: nothing -> string {
  $args | each {|a| sh-quote $a } | str join " "
}

def b2-upload [src: string, dst: string] {
  let name = ($src | path basename)
  let content_type = match ($name | path parse | get extension) {
    "mp4" => "video/mp4"
    "m3u8" => "application/x-mpegURL"
    "json" => "application/json"
    _ => { die $"unknown file extension: ($name)" }
  }

  print $"Uploading ($name) \(($content_type)\)..."
  (
    ^nix-shell -p awscli2 --run
      (sh-join [aws s3 cp $src $dst --endpoint-url $B2_ENDPOINT --content-type $content_type])
  )
}

# Values bind through psql's `-v`, so nothing is escaped into the statement
# itself. The quoting here is for the remote shell, which would otherwise split
# and expand a JSON payload.
def pt-psql [sql: string, params: record = {}] {
  let bindings = (
    $params | items {|k, v| ["-v" (sh-quote $"($k)=($v)")] } | flatten | str join " "
  )
  $sql | ^ssh $PEERTUBE_HOST $"sudo -u peertube psql -v ON_ERROR_STOP=1 -d peertube ($bindings)"
}

# ------------------------------------------------------------------------------
# Subcommands
# ------------------------------------------------------------------------------

# Query the PeerTube API and database for a video's file details.
def "main identify" [video_uuid: string] {
  require-uuid $video_uuid

  print "=== API: Video details ==="
  let fetch = (sh-join [
    curl --fail --show-error --silent
    $"http://127.0.0.1:9000/api/v1/videos/($video_uuid)"
    -H $"Host: ($PEERTUBE_DOMAIN)"
  ])
  let query = $fetch + " | " + (sh-join [jq $API_JQ_FILTER])
  ^ssh $PEERTUBE_HOST (sh-join [sudo -u peertube bash -o pipefail -c $query])

  print "\n=== DB: HLS file details ==="
  pt-psql $SQL_HLS_FILES {uuid: $video_uuid}

  print "\n=== DB: Streaming playlist metadata ==="
  pt-psql $SQL_PLAYLIST_META {uuid: $video_uuid}
}

# Transcode a source video to HLS fragmented MP4. `fps` is required for
# re-encode mode.
def "main transcode" [
  mode: string # remux or re-encode
  source: string # absolute path to the source video
  file_uuid: string
  resolution: string
  fps?: string
] {
  require-uuid $file_uuid
  require-int $resolution
  if ($fps | is-not-empty) {
    require-int $fps
  }
  require-file $source "source file not found (use absolute paths)"

  mkdir $WORK_DIR
  let fmp4 = (fmp4-path $file_uuid $resolution)
  let m3u8 = (m3u8-path $file_uuid $resolution)

  let hls_args = [
    "-f" "hls"
    "-hls_time" "4"
    "-hls_list_size" "0"
    "-hls_playlist_type" "vod"
    "-hls_segment_type" "fmp4"
    "-hls_flags" "single_file"
    "-hls_segment_filename" $fmp4
  ]

  match $mode {
    "remux" => {
      (
        ^ffmpeg
        -i $source
        -an
        -c:v copy
        ...$hls_args $m3u8
      )
    }
    "re-encode" => {
      if ($fps | is-empty) {
        die "fps is required for re-encode mode"
      }
      (
        ^ffmpeg
        -i $source
        -an
        -c:v libx264
        -preset $X264_PRESET
        -profile:v $X264_PROFILE
        -crf $X264_CRF
        -b_strategy $X264_B_STRATEGY
        -bf $X264_BF
        -r $fps
        ...$hls_args $m3u8
      )
    }
    _ => { die $"unknown mode: ($mode) \(use 'remux' or 're-encode'\)" }
  }

  print ""
  print "Output:"
  print $"  fmp4: ($fmp4) \((file-size $fmp4) bytes\)"
  print $"  m3u8: ($m3u8)"
}

# Upload a local file to the video's B2 prefix.
def "main upload" [
  video_uuid: string
  file: string
  dest_name?: string # override the B2 object name
] {
  require-uuid $video_uuid
  require-b2-credentials
  require-file $file "file not found"

  let name = if ($dest_name | is-empty) { $file | path basename } else { $dest_name }
  b2-upload $file $"(b2-prefix $video_uuid)/($name)"
}

# Regenerate hashes in an existing local manifest after a media file changed.
def "main regen-sha256" [
  file_uuid: string
  resolution: string
  sha256_file: path
] {
  require-uuid $file_uuid
  require-int $resolution

  let fmp4 = (fmp4-path $file_uuid $resolution)
  let m3u8 = (m3u8-path $file_uuid $resolution)

  require-file $fmp4 "fmp4 not found"
  require-file $m3u8 "m3u8 not found"
  require-file $sha256_file "SHA256 manifest not found"

  (
    ^($SCRIPT_DIR | path join "regen-sha256.py")
      $fmp4 $m3u8 $sha256_file $"($file_uuid)-($resolution)-fragmented.mp4"
  )

  print $"SHA256 JSON saved to: ($sha256_file)"
}

# Update a videoFile row's size to match the local fmp4.
def "main db-update-size" [file_id: string, file_uuid: string, resolution: string] {
  require-int $file_id
  require-uuid $file_uuid
  require-int $resolution

  let fmp4 = (fmp4-path $file_uuid $resolution)
  require-file $fmp4 "fmp4 not found"

  let new_size = (file-size $fmp4)
  print $"Updating videoFile id=($file_id) size to ($new_size)..."

  pt-psql $SQL_UPDATE_SIZE {size: $new_size, id: $file_id}
}

# Update a videoFile row's ffprobe metadata from the local fmp4.
def "main db-update-meta" [file_id: string, file_uuid: string, resolution: string] {
  require-int $file_id
  require-uuid $file_uuid
  require-int $resolution

  let fmp4 = (fmp4-path $file_uuid $resolution)
  require-file $fmp4 "fmp4 not found"

  let metadata_file = $"($WORK_DIR)/metadata-($file_uuid)-($resolution).json"
  (
    ^ffprobe
    -v quiet
    -print_format json
    -show_format
    -show_streams
    $fmp4
    | save --raw --force $metadata_file
  )

  print $"Updating videoFile id=($file_id) metadata..."

  let metadata = (open --raw $metadata_file | from json | to json -r)
  pt-psql $SQL_UPDATE_META {metadata: $metadata, id: $file_id}
}

# Print the x264 encoding parameters recorded in a local file or remote URL.
def "main verify" [target: string] {
  let output = (
    if ($target =~ '^https?://') {
      print "Fetching first 256 KB from remote..."
      http get --raw --headers [Range bytes=0-262143] $target | ^strings
    } else {
      require-file $target "file not found"
      ^strings -- $target
    }
    | ^grep 'x264.*options:'
    | complete
  )

  if $output.exit_code == 0 and ($output.stdout | is-not-empty) {
    print ($output.stdout | str trim)
  } else {
    print "(no x264 options found)"
  }
}

# Print the Cloudflare CDN URLs that need a cache purge.
def "main purge-urls" [video_uuid: string, ...filenames: string] {
  require-uuid $video_uuid
  if ($filenames | is-empty) {
    die "usage: purge-urls <VIDEO_UUID> <FILENAME>..."
  }

  let prefix = (cdn-prefix $video_uuid)
  print "Cloudflare CDN URLs to purge:"
  for filename in $filenames { print $"  ($prefix)/($filename)" }
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

# Manual PeerTube HLS transcode and upload. AWS_ACCESS_KEY_ID and
# AWS_SECRET_ACCESS_KEY are required by `upload`.
def main [] {
  die "subcommand required. Run with --help for usage."
}
