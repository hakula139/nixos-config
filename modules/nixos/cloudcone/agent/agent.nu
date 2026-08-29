#!/usr/bin/env nu

# ==============================================================================
# CloudCone Monitoring Agent
# Modified from https://github.com/Cloudcone/cloud-view/blob/master/agent.sh
# ==============================================================================

const AGENT_VERSION = '1.0'
const GATEWAY = 'http://watch.cloudc.one/agent'
const PING_TARGET = '1.1.1.1'

# ------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------

# Every probe is best-effort, and a failing external command would otherwise
# abort the script, so each one goes through `complete`.
def sh [cmd: string, args: list<string> = []]: nothing -> string {
  try { (^$cmd ...$args | complete).stdout } catch { "" }
}

def slurp [path: string]: nothing -> string {
  try { open --raw $path | decode utf-8 } catch { "" }
}

# Whitespace-split into fields, matching awk's default FS.
def fields [text: string]: nothing -> list<string> {
  $text | str trim | split row -r '\s+'
}

def meminfo-kb [text: string, key: string]: nothing -> string {
  let line = ($text | lines | where ($it | str starts-with $key) | get -o 0)
  if ($line | is-empty) { "0" } else { (fields $line | get -o 1 | default "0") }
}

def get-os-name []: nothing -> string {
  let release = (slurp /etc/os-release)
  if ($release | is-not-empty) {
    let vars = (
      $release | lines
      # Uppercase KEY=value assignments
      | parse -r '^(?<k>[A-Z_]+)=(?<v>.*)$'
      | reduce -f {} {|it, acc| $acc | insert $it.k ($it.v | str trim -c '"') }
    )
    let pretty = ($vars | get -o PRETTY_NAME)
    if ($pretty | is-not-empty) { return $pretty }
    let name = ($vars | get -o NAME)
    if ($name | is-not-empty) { return $name }
    return "Linux"
  }
  sh uname [-s] | str trim
}

def get-cpu-speed []: nothing -> string {
  let cpuinfo = (slurp /proc/cpuinfo | lines | where ($it | str contains 'cpu MHz') | get -o 0)
  if ($cpuinfo | is-not-empty) {
    return ($cpuinfo | split row ':' | get -o 1 | default "" | str trim)
  }
  let lscpu = (sh lscpu | lines | where ($it | str contains 'CPU MHz') | get -o 0)
  if ($lscpu | is-not-empty) {
    return ($lscpu | split row ':' | get -o 1 | default "" | str trim)
  }
  ""
}

# The interface name follows the "dev" token.
def dev-after [text: string]: nothing -> string {
  for line in ($text | lines) {
    let f = (fields $line)
    let i = ($f | enumerate | where item == "dev" | get -o 0.index)
    if $i != null {
      let name = ($f | get -o ($i + 1))
      if ($name | is-not-empty) { return $name }
    }
  }
  ""
}

def get-default-interface []: nothing -> string {
  let via_default = (dev-after (sh ip [route show default]))
  if ($via_default | is-not-empty) { return $via_default }

  let via_route = (dev-after (sh ip [route get 4.2.2.1]))
  if ($via_route | is-not-empty) { return $via_route }

  let eth = (
    sh ip [link show] | lines
    # Numbered ethN interface rows
    | where ($it =~ '^[0-9]+: eth[0-9]+:')
    | get -o 0
  )
  if ($eth | is-not-empty) {
    return ($eth | split row ':' | get -o 1 | default "" | str trim)
  }
  ""
}

def get-active-connections []: nothing -> string {
  if (which ss | is-not-empty) {
    (sh ss [-tun] | lines | skip 1 | length | into string)
  } else {
    (sh netstat [-tun] | lines | skip 2 | length | into string)
  }
}

def get-ping-latency []: nothing -> string {
  let rtt = (sh ping [-B -w 2 -n -c 2 $PING_TARGET] | lines | where ($it | str contains 'rtt') | get -o 0)
  if ($rtt | is-empty) { return "" }
  $rtt | split row '/' | get -o 4 | default ""
}

# "cpu" plus its ten counters, comma-joined.
def read-proc-stat-cpu []: nothing -> string {
  let line = (slurp /proc/stat | lines | where ($it | str starts-with 'cpu ') | get -o 0)
  if ($line | is-empty) { return "" }
  $"((fields $line | first 11 | str join ','));"
}

# Join selected fields of every row whose first field is an absolute path.
def rows-from-df [text: string, count: int]: nothing -> string {
  $text | lines
  | each {|l| fields $l }
  | where {|f| ($f | get -o 0 | default "") | str starts-with '/' }
  | each {|f| $"(($f | first $count) | str join ',');" }
  | str join ""
}

def collect-disk-usage []: nothing -> string {
  rows-from-df (sh df [-P -T -B 1k]) 7
}

def collect-disk-inodes []: nothing -> string {
  rows-from-df (sh df [-P -i]) 6
}

# iface, rx_bytes, tx_bytes, rx_packets, tx_packets per interface.
def collect-network-interfaces []: nothing -> string {
  slurp /proc/net/dev | lines | skip 2
  | each {|l|
      let f = (fields ($l | str replace --all ':' ' '))
      $"($f | get -o 0 | default ''),($f | get -o 1 | default ''),($f | get -o 9 | default ''),($f | get -o 2 | default ''),($f | get -o 10 | default '');"
    }
  | str join ""
}

def collect-addresses [family: string]: nothing -> string {
  sh ip [-f $family -o addr show] | lines
  | each {|l|
      let f = (fields $l)
      let addr = ($f | get -o 3 | default "" | split row '/' | get -o 0 | default "")
      $"($f | get -o 1 | default ''),($addr);"
    }
  | str join ""
}

# The gateway parses this payload on `,` and `;`, so those characters plus `%`
# are percent-escaped inside the command line.
def escape-cmd [cmd: string]: nothing -> string {
  $cmd
  # ASCII control whitespace
  | str replace --all -r '[\r\n\t]' ' '
  # Repeated spaces
  | str replace --all -r ' +' ' '
  | str replace --all '%' '%25'
  | str replace --all ',' '%2C'
  | str replace --all ';' '%3B'
}

def collect-processes []: nothing -> string {
  # A comma in a bare list element splits it in two, so both of these are
  # quoted: `--sort=-pcpu,-pmem` would reach `ps` as a stray `-pmem`.
  let ps_args = [
    -e
    -o
    'pid=,ppid=,rss=,vsz=,uname=,pmem=,pcpu=,comm=,cmd='
    '--sort=-pcpu,-pmem'
  ]
  sh ps $ps_args | lines
  | each {|l| fields $l }
  | where {|f| ($f | get -o 4 | default "") != "ccagent" }
  | each {|f|
      let head = ($f | first 8 | str join ',')
      let cmd = (escape-cmd ($f | skip 8 | str join ' '))
      $"($head),($cmd);"
    }
  | str join ""
}

# ------------------------------------------------------------------------------
# Main Collection
# ------------------------------------------------------------------------------

def main [server_key_file: string]: nothing -> nothing {
  let key_file = ($env.CLOUDCONE_SERVER_KEY_FILE? | default $server_key_file)
  # If set to 1, do not send to gateway; print the payload to stdout instead.
  let dry_run = ($env.CLOUDCONE_DRY_RUN? | default "0")
  # If set to 1, redact the server key from output. Defaults to the dry-run value.
  let redact = ($env.CLOUDCONE_REDACT_SERVERKEY? | default $dry_run)

  # A trailing newline in the key file is not part of the key.
  let server_key = (open --raw $key_file | decode utf-8 | str trim)
  let meminfo = (slurp /proc/meminfo)

  let ram_total = (meminfo-kb $meminfo 'MemTotal:')
  let ram_free = (meminfo-kb $meminfo 'MemFree:')
  let swap_total = (meminfo-kb $meminfo 'SwapTotal:')
  let swap_free = (meminfo-kb $meminfo 'SwapFree:')

  let cpu_model = (
    slurp /proc/cpuinfo | lines | where ($it | str contains 'model name') | get -o 0
    | default "" | split row ':' | get -o 1 | default "" | str trim
  )

  let cpu_info = (read-proc-stat-cpu)
  let all_interfaces = (collect-network-interfaces)
  sleep 1sec
  let cpu_info_current = (read-proc-stat-cpu)
  let all_interfaces_current = (collect-network-interfaces)

  let metrics = [
    # Agent metadata
    [agent_version ($AGENT_VERSION)]
    [serverkey (if $redact == "1" { "<redacted>" } else { $server_key })]
    [gateway ($GATEWAY)]
    [time (date now | format date '%s')]

    # System info
    [hostname (sys host | get hostname)]
    [kernel (sh uname [-r] | str trim)]
    [os (get-os-name)]
    [os_arch $"((sh uname [-m] | str trim)),((sh uname [-p] | str trim))"]

    # CPU metrics
    [cpu_model $cpu_model]
    [cpu_cores ((slurp /proc/cpuinfo | lines | where ($it | str starts-with 'processor') | length) | into string)]
    [cpu_speed (get-cpu-speed)]
    [cpu_load ((fields (slurp /proc/loadavg)) | first 3 | str join ',')]
    [cpu_info $cpu_info]
    [cpu_info_current $cpu_info_current]

    # Disk metrics
    [disks (collect-disk-usage)]
    [disks_inodes (collect-disk-inodes)]
    [file_descriptors ((fields (slurp /proc/sys/fs/file-nr)) | first 3 | str join ',')]

    # Memory metrics
    [ram_total $ram_total]
    [ram_free $ram_free]
    [ram_usage (((($ram_total | into int) - ($ram_free | into int))) | into string)]
    [ram_available (meminfo-kb $meminfo 'MemAvailable:')]
    [ram_caches (meminfo-kb $meminfo 'Cached:')]
    [ram_buffers (meminfo-kb $meminfo 'Buffers:')]

    # Swap metrics
    [swap_total $swap_total]
    [swap_free $swap_free]
    [swap_usage (((($swap_total | into int) - ($swap_free | into int))) | into string)]

    # Network metrics
    [default_interface (get-default-interface)]
    [all_interfaces $all_interfaces]
    [all_interfaces_current $all_interfaces_current]
    [ipv4_addresses (collect-addresses inet)]
    [ipv6_addresses (collect-addresses inet6)]
    [active_connections (get-active-connections)]
    [ping_latency (get-ping-latency)]

    # Session / uptime metrics
    [ssh_sessions ((sh who | lines | where ($it | is-not-empty) | length) | into string)]
    [uptime ((fields (slurp /proc/uptime)) | get -o 0 | default "0")]

    # Process list
    [processes (collect-processes)]
  ]

  let post = ($metrics | each {|m| $"{($m.0)}($m.1){/($m.0)}" } | str join "")

  if $dry_run == "1" {
    print $"data=($post)"
    return
  }

  # The endpoint is third-party and best-effort, so a failure here must not
  # leave a permanently failed unit that blocks a deploy.
  let sent = try {
    ($"data=($post)" | ^curl -m 50 -k -s -d @- $GATEWAY | complete).exit_code
  } catch {
    1
  }
  if $sent != 0 {
    print -e "Warning: Failed to send metrics to CloudCone gateway"
  }
}
