#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CloudCone Monitoring Agent
# Modified from https://github.com/Cloudcone/cloud-view/blob/master/agent.sh
# ==============================================================================

readonly AGENT_VERSION='1.0'
readonly GATEWAY='http://watch.cloudc.one/agent'
readonly PING_TARGET='1.1.1.1'

readonly DEFAULT_SERVER_KEY_FILE='/run/agenix/cloudcone-server-key'
readonly SERVER_KEY_FILE="${CLOUDCONE_SERVER_KEY_FILE:-${DEFAULT_SERVER_KEY_FILE}}"

# If set to 1, do not send to gateway; print the payload to stdout instead.
readonly DRY_RUN="${CLOUDCONE_DRY_RUN:-0}"
# If set to 1, redact the server key from output. Defaults to DRY_RUN value.
readonly REDACT_SERVERKEY="${CLOUDCONE_REDACT_SERVERKEY:-${DRY_RUN}}"

# ------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------

append_metric() {
  local key="$1"
  local value="$2"
  POST="${POST}{${key}}${value}{/${key}}"
}

get_os_name() {
  if [[ -r /etc/os-release ]]; then
    source /etc/os-release
    echo "${PRETTY_NAME:-${NAME:-Linux}}"
  else
    uname -s
  fi
}

get_cpu_speed() {
  local speed
  speed="$(awk -F: '/cpu MHz/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | xargs || true)"
  if [[ -z "${speed}" ]]; then
    speed="$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {print $2; exit}' | xargs || true)"
  fi
  echo "${speed}"
}

get_default_interface() {
  local iface
  iface="$(ip route show default 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="dev") print $(i+1); exit}' || true)"
  if [[ -z "${iface}" ]]; then
    iface="$(ip route get 4.2.2.1 2>/dev/null | awk '/dev/ {for (i=1; i<=NF; i++) if ($i=="dev") print $(i+1); exit}' || true)"
  fi
  if [[ -z "${iface}" ]]; then
    iface="$(ip link show 2>/dev/null | awk -F: '/^[0-9]+: eth[0-9]+:/ {gsub(/^ +| +$/, "", $2); print $2; exit}' || true)"
  fi
  echo "${iface}"
}

get_active_connections() {
  if command -v ss &>/dev/null; then
    ss -tun 2>/dev/null | tail -n +2 | wc -l
  else
    netstat -tun 2>/dev/null | tail -n +3 | wc -l
  fi
}

get_ping_latency() {
  ping -B -w 2 -n -c 2 "${PING_TARGET}" 2>/dev/null \
    | awk -F/ '/rtt/ {print $5}' \
    || true
}

read_proc_stat_cpu() {
  awk '/^cpu / {printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s;",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' /proc/stat 2>/dev/null || true
}

collect_disk_usage() {
  df -P -T -B 1k 2>/dev/null \
    | awk 'BEGIN {out=""} $1 ~ "^/" {out=out $1","$2","$3","$4","$5","$6","$7";"} END {print out}' \
    || true
}

collect_disk_inodes() {
  df -P -i 2>/dev/null \
    | awk 'BEGIN {out=""} $1 ~ "^/" {out=out $1","$2","$3","$4","$5","$6";"} END {print out}' \
    || true
}

collect_network_interfaces() {
  tail -n +3 /proc/net/dev 2>/dev/null \
    | tr ":" " " \
    | awk 'BEGIN {out=""} {out=out $1","$2","$10","$3","$11";"} END {print out}' \
    || true
}

collect_ipv4_addresses() {
  ip -f inet -o addr show 2>/dev/null \
    | awk '{split($4,a,"/"); printf "%s,%s;",$2,a[1]}' \
    || true
}

collect_ipv6_addresses() {
  ip -f inet6 -o addr show 2>/dev/null \
    | awk '{split($4,a,"/"); printf "%s,%s;",$2,a[1]}' \
    || true
}

collect_processes() {
  ps -e -o pid=,ppid=,rss=,vsz=,uname=,pmem=,pcpu=,comm=,cmd= --sort=-pcpu,-pmem 2>/dev/null \
    | awk '
        BEGIN { out="" }
        # Skip processes owned by ccagent
        $5 == "ccagent" { next }
        {
          cmd=$9
          for (i=10; i<=NF; i++) cmd=cmd " " $i
          gsub(/[\r\n\t]/, " ", cmd)
          gsub(/[ ]+/, " ", cmd)
          gsub(/%/, "%25", cmd)
          gsub(/,/, "%2C", cmd)
          gsub(/;/, "%3B", cmd)
          out=out $1","$2","$3","$4","$5","$6","$7","$8","cmd";"
        }
        END { print out }
      ' \
    || true
}

# ------------------------------------------------------------------------------
# Main Collection
# ------------------------------------------------------------------------------

main() {
  local server_key
  server_key="$(cat "${SERVER_KEY_FILE}")"

  POST=""

  # Agent metadata
  append_metric "agent_version" "${AGENT_VERSION}"
  if [[ "${REDACT_SERVERKEY}" == "1" ]]; then
    append_metric "serverkey" "<redacted>"
  else
    append_metric "serverkey" "${server_key}"
  fi
  append_metric "gateway" "${GATEWAY}"
  append_metric "time" "$(date +%s)"

  # System info
  append_metric "hostname" "$(hostname)"
  append_metric "kernel" "$(uname -r)"
  append_metric "os" "$(get_os_name)"
  append_metric "os_arch" "$(uname -m),$(uname -p)"

  # CPU metrics
  append_metric "cpu_model" "$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | xargs || true)"
  append_metric "cpu_cores" "$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0)"
  append_metric "cpu_speed" "$(get_cpu_speed)"
  append_metric "cpu_load" "$(awk '{print $1","$2","$3}' /proc/loadavg 2>/dev/null || true)"
  append_metric "cpu_info" "$(read_proc_stat_cpu)"
  sleep 1
  append_metric "cpu_info_current" "$(read_proc_stat_cpu)"

  # Disk metrics
  append_metric "disks" "$(collect_disk_usage)"
  append_metric "disks_inodes" "$(collect_disk_inodes)"
  append_metric "file_descriptors" "$(awk '{print $1","$2","$3}' /proc/sys/fs/file-nr 2>/dev/null || true)"

  # Memory metrics
  local ram_total ram_free
  ram_total="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  ram_free="$(awk '/^MemFree:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  append_metric "ram_total" "${ram_total}"
  append_metric "ram_free" "${ram_free}"
  append_metric "ram_usage" "$((ram_total - ram_free))"
  append_metric "ram_available" "$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  append_metric "ram_caches" "$(awk '/^Cached:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  append_metric "ram_buffers" "$(awk '/^Buffers:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"

  # Swap metrics
  local swap_total swap_free
  swap_total="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  swap_free="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  append_metric "swap_total" "${swap_total}"
  append_metric "swap_free" "${swap_free}"
  append_metric "swap_usage" "$((swap_total - swap_free))"

  # Network metrics
  append_metric "default_interface" "$(get_default_interface)"
  append_metric "all_interfaces" "$(collect_network_interfaces)"
  sleep 1
  append_metric "all_interfaces_current" "$(collect_network_interfaces)"
  append_metric "ipv4_addresses" "$(collect_ipv4_addresses)"
  append_metric "ipv6_addresses" "$(collect_ipv6_addresses)"
  append_metric "active_connections" "$(get_active_connections)"
  append_metric "ping_latency" "$(get_ping_latency)"

  # Session / uptime metrics
  append_metric "ssh_sessions" "$(who 2>/dev/null | wc -l || echo 0)"
  append_metric "uptime" "$(awk '{print $1}' /proc/uptime 2>/dev/null || echo 0)"

  # Process list
  append_metric "processes" "$(collect_processes)"

  if [[ "${DRY_RUN}" == "1" ]]; then
    printf 'data=%s\n' "${POST}"
    return 0
  fi

  # Send to CloudCone gateway
  echo "data=${POST}" | curl -m 50 -k -s -d @- "${GATEWAY}" >/dev/null || {
    echo "Warning: Failed to send metrics to CloudCone gateway" >&2
    return 1
  }
}

main "$@"
