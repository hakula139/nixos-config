#!/usr/bin/env nu

const repo = 'hakula139/nixos-config'

export def require [condition: bool, message: string] {
  if not $condition { error make {msg: $message} }
}

export def validate-manifest [manifest: record, revision: string, host: string] {
  require ($manifest.revision == $revision) 'CI artifact revision does not match the requested revision'
  require ($manifest.host == $host) 'CI artifact belongs to another host'
  # Nix store paths contain a 32-character hash and a package name.
  require ($manifest.system =~ '^/nix/store/[a-z0-9]{32}-nixos-system-[a-z0-9.-]+$') 'Invalid system store path'
}

export def validate-health [before: record, after: record, expected: string] {
  require ($after.profile == $expected) 'The active system does not match the CI artifact'
  require ($after.failed | is-empty) 'The host has failed systemd units'
  let missing = $before.services | where {|unit| $unit not-in $after.services }
  require ($missing | is-empty) $'Previously running services stopped: ($missing | str join ", ")'
}

def run [command: string, args: list<string>] {
  let result = ^timeout 10m $command ...$args | complete
  if $result.exit_code != 0 {
    error make {msg: $'($command) failed: ($result.stderr | str trim)'}
  }
  $result.stdout | str trim
}

def stream [command: string, args: list<string>] {
  ^timeout 30m $command ...$args
  require ($env.LAST_EXIT_CODE == 0) $'($command) failed; deployment stopped'
}

def remote [host: record, script: string, --timeout: string = '90s'] {
  let result = $script | ^timeout $timeout ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -p $host.port $'root@($host.ip)' bash -se | complete
  if $result.exit_code != 0 {
    error make {msg: $'SSH to ($host.name) failed: ($result.stderr | str trim)'}
  }
  $result.stdout | str trim
}

def health [host: record] {
  let rows = remote $host r#'
    readlink /run/current-system
    cat /proc/sys/kernel/random/boot_id
    uname -r
    df -Pk / | tail -1 | awk '{print $4}'
    printf 'SERVICES\n'
    while read -r unit; do
      if [ "$(systemctl show "$unit" --property=Type --value)" != oneshot ]; then
        printf '%s\n' "$unit"
      fi
    done < <(systemctl list-units --type=service --state=running --no-legend --plain | awk '{print $1}')
    printf 'FAILED\n'
    systemctl --failed --no-legend --plain
  '# | lines
  let sections = $rows | split list 'SERVICES'
  let units = $sections.1 | split list 'FAILED'
  {
    profile: $rows.0
    boot: $rows.1
    kernel: $rows.2
    freeKiB: ($rows.3 | into int)
    services: ($units.0 | where {|name| not ($name | str starts-with 'user@') })
    failed: $units.1
  }
}

def controller [settings: record, endpoint: string, --select: string] {
  # Keep the bearer token inside Nushell, away from process arguments and state files.
  let headers = {Authorization: $'Bearer ($settings.secret)'}
  let url = $'http://($settings.external-controller)($endpoint)'
  try {
    with-env {NO_PROXY: '127.0.0.1,localhost', no_proxy: '127.0.0.1,localhost'} {
      if $select != null {
        http put --max-time 12sec --content-type application/json --headers $headers $url {name: $select}
      } else {
        http get --max-time 12sec --headers $headers $url
      }
    }
  } catch {
    error make {msg: 'Clash controller request failed'}
  }
}

def delay [settings: record, name: string] {
  let encoded = $name | url encode --all
  let target = 'https://www.gstatic.com/generate_204' | url encode --all
  let result = controller $settings $'/proxies/($encoded)/delay?timeout=8000&url=($target)'
  require ($result.delay > 0) 'Proxy did not pass its connectivity check'
}

export def selected-proxy [proxies: record, group: string] {
  mut name = $group
  mut visited = []
  loop {
    require ($name not-in $visited) 'Proxy selector contains a cycle'
    $visited = $visited | append $name
    let proxy = $proxies | get $name
    if $proxy.now? == null { return $name }
    $name = $proxy.now
  }
}

def protect-proxy [settings: record, host: string] {
  let proxies = (controller $settings '/proxies').proxies
  let selected = selected-proxy $proxies $settings.group
  let label = $host | str upcase
  if ($selected | str contains $label) {
    let candidates = ($proxies | get $settings.group).all | where {|name|
      ($name | str contains 'REALITY') and not ($name | str contains $label)
    }
    mut switched = false
    for name in $candidates {
      let healthy = try { delay $settings $name; true } catch { false }
      if $healthy {
        controller $settings $'/proxies/($settings.group)' --select $name | ignore
        require ((controller $settings $'/proxies/($settings.group)').now == $name) 'Proxy selection did not change'
        print $'Proxy moved to ($name) before deploying ($host)'
        $switched = true
        break
      }
    }
    require $switched 'No healthy alternate proxy is available'
  }
}

def public-health [host: string] {
  let urls = match $host {
    'us-1' => ['https://v.hakula.xyz/api/v1/config']
    'us-4' => ['https://umami.hakula.xyz/api/heartbeat' 'https://cloud.hakula.xyz/']
    _ => []
  }
  for url in $urls {
    run curl ['--fail' '--silent' '--show-error' '--max-time' '30' '--output' '/dev/null' $url] | ignore
  }
}

def check-proxy-routes [settings: record, host: string] {
  let proxies = (controller $settings '/proxies').proxies
  let label = $host | str upcase
  let names = $proxies | columns | where {|name|
    ($name | str contains $label) and ($proxies | get $name).now? == null
  }
  require (not ($names | is-empty)) $'No Clash routes found for ($host)'
  for name in $names { delay $settings $name }
}

def wait-health [host: record, before: record, expected: string] {
  let deadline = (date now) + 1min
  mut failure = 'Host did not become ready'
  loop {
    let result = try {
      let current = health $host
      validate-health $before $current $expected
      public-health $host.name
      {ready: true, current: $current}
    } catch {|error| {ready: false, error: $error.msg} }
    if $result.ready { return $result.current }
    $failure = $result.error
    if (date now) >= $deadline { break }
    print $'Waiting for ($host.name) services to become ready...'
    sleep 3sec
  }
  error make {msg: $failure}
}

def backup [host: record] {
  let targets = match $host.name {
    'us-1' => ['peertube']
    'us-4' => ['umami' 'cloudreve' 'twikoo']
    _ => []
  }
  for target in $targets {
    print $'Backing up ($target) before activation...'
    remote $host $'systemctl start restic-backups-($target).service' --timeout '20m' | ignore
  }
}

def umami-sql [host: record, query: string] {
  let command = [
    "runuser -u postgres -- psql -d umami -v ON_ERROR_STOP=1 -At <<'SQL'"
    $query
    'SQL'
  ] | str join (char nl)
  remote $host $command
}

def umami-health [host: record] {
  let website = random uuid
  let payload = {
    type: 'event'
    payload: {website: $website, hostname: 'geo-smoke.invalid', url: '/geo-smoke', language: 'en-US', screen: '1920x1080'}
  } | to json --raw
  umami-sql $host $"INSERT INTO website \(website_id, name, domain\) VALUES \('($website)', 'Deployment geolocation check', 'geo-smoke.invalid'\)" | ignore
  let failure = try {
    let request = [
      'curl --fail --silent --show-error --max-time 30 --output /dev/null'
      "-H 'Content-Type: application/json' -H 'X-Forwarded-For: 8.8.8.8, 127.0.0.1'"
      "-H 'CF-IPCountry: US' -H 'CF-Region-Code: CA' -H 'CF-IPCity: Mountain View'"
      "-A 'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36'"
      "--data-binary @- http://127.0.0.1:3000/api/send <<'JSON'"
    ] | str join ' '
    remote $host ([$request $payload 'JSON'] | str join (char nl)) | ignore
    let location = umami-sql $host $"SELECT country || '|' || region FROM session WHERE website_id = '($website)'"
    require ($location == 'US|US-CA') 'Umami did not retain the forwarded IP country and region'
    run curl ['--fail' '--silent' '--show-error' '--max-time' '30' '--output' '/dev/null' '-H' 'Content-Type: application/json' '-A' 'Mozilla/5.0 Chrome/131.0.0.0 Safari/537.36' '--data' $payload 'https://umami.hakula.xyz/api/send'] | ignore
    let missing = umami-sql $host $"SELECT count\(*\) FROM session WHERE website_id = '($website)' AND country IS NOT NULL AND region IS NOT NULL"
    require ($missing == '2') 'Public Umami collection did not store country and region'
    null
  } catch {|error| $error.msg }
  umami-sql $host $"BEGIN; DELETE FROM website_event WHERE website_id = '($website)'; DELETE FROM session WHERE website_id = '($website)'; DELETE FROM website WHERE website_id = '($website)'; COMMIT;" | ignore
  require ($failure == null) ($failure | default '')
}

def wait-reboot [host: record, before: record, expected: string] {
  let deadline = (date now) + 5min
  while (date now) < $deadline {
    sleep 5sec
    let current = try { health $host } catch { null }
    if $current != null and $current.boot != $before.boot {
      let ready = try {
        validate-health $before $current $expected
        let kernel = remote $host $'basename ($expected)/kernel-modules/lib/modules/*'
        require ($current.kernel == $kernel) 'The running kernel differs from the deployed kernel'
        public-health $host.name
        true
      } catch { false }
      if $ready { return }
    }
  }
  error make {msg: $'($host.name) did not return healthy after reboot. Deployment stopped.'}
}

# Deploy CI-cached public main, optionally rebooting each healthy server in turn.
def main [
  --on: string = 'us-1,us-2,us-3,sg-1,us-4' # Comma-separated inventory host names
  --revision: string # Resume a previously selected public main commit
  --reboot # Reboot each server after activation and service checks
  --clash-config: path # Override the local Clash Verge runtime YAML path
  --without-clash # Explicitly declare that this workstation does not use Clash
] {
  let config = open $env.NIXOS_DEPLOY_CONFIG
  let hosts = $on | split row ',' | uniq
  require (not ($hosts | is-empty)) 'Select at least one server'
  for host in $hosts { require ($host in $config.servers) $'Unknown server: ($host)' }
  let sha = if $revision == null {
    run gh ['api' $'repos/($repo)/commits/main' '--jq' '.sha']
  } else { $revision }
  # Only full commit IDs are accepted, so a resume cannot follow a moving branch.
  require ($sha =~ '^[a-f0-9]{40}$') 'Revision must be a full commit SHA'
  let state = ($env.XDG_STATE_HOME? | default ($nu.home-dir | path join '.local/state')) | path join 'nixos-deploy' $sha
  mkdir $state
  print $'Deploying public revision ($sha). Resume with --revision ($sha). Private working-tree overrides are excluded.'

  let settings = if $without_clash { null } else {
    let path = $clash_config | default ($nu.home-dir | path join 'Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml')
    require ($path | path exists) 'Clash runtime configuration is missing. Supply --clash-config or --without-clash.'
    let runtime = try { open $path | select external-controller secret } catch {
      error make {msg: 'Cannot parse Clash runtime controller settings'}
    }
    let mode = (controller $runtime '/configs').mode
    require ($mode in ['rule' 'global']) 'Unsupported Clash mode. Check connectivity and use --without-clash if routing is direct.'
    $runtime | insert group (if $mode == 'global' { 'GLOBAL' } else { 'PROXY' })
  }
  let proxy_state = $state | path join 'proxy.json'
  let original = if $settings != null {
    let selected = if ($proxy_state | path exists) { open $proxy_state } else {
      let selection = {group: $settings.group, name: (controller $settings $'/proxies/($settings.group)').now}
      $selection | save $proxy_state
      $selection
    }
    require ($selected.group == $settings.group) 'Clash routing mode changed since this deployment started'
    $selected.name
  } else { null }
  let source = $state | path join 'source'
  if not ($source | path exists) {
    run git ['init' '--quiet' $source] | ignore
    run git ['-C' $source 'remote' 'add' 'origin' $'https://github.com/($repo).git'] | ignore
  }
  run git ['-C' $source 'fetch' '--depth' '1' 'origin' $sha] | ignore
  run git ['-C' $source 'checkout' '--detach' $sha] | ignore
  require ((run git ['-C' $source 'status' '--porcelain']) | is-empty) 'Deployment checkout is dirty'
  mut run_id = 0
  for attempt in 1..60 {
    let runs = run gh ['run' 'list' '--repo' $repo '--workflow' 'ci.yml' '--commit' $sha '--event' 'push' '--json' 'databaseId' '--limit' '1'] | from json
    if not ($runs | is-empty) { $run_id = $runs.0.databaseId; break }
    print 'Waiting for GitHub to start CI...'
    sleep 10sec
  }
  require ($run_id != 0) 'No CI push run appeared for this revision'
  mut manifests = {}
  for host in $hosts {
    let artifact = $'deploy-($host)'
    let destination = $state | path join $artifact
    mut ready = false
    for attempt in 1..120 {
      let artifacts = run gh ['api' $'repos/($repo)/actions/runs/($run_id)/artifacts'] | from json
      let jobs = run gh ['api' $'repos/($repo)/actions/runs/($run_id)/jobs'] | from json
      let selected_jobs = $jobs.jobs | where {|job| $job.name == 'Nix Flake Check' or ($job.name | str starts-with $'Build ($host) ') }
      let failed = $selected_jobs | any {|job| $job.conclusion in ['failure' 'cancelled' 'timed_out'] }
      require (not $failed) $'CI failed for ($host)'
      let succeeded = ($selected_jobs | length) == 2 and ($selected_jobs | all {|job| $job.conclusion == 'success' })
      if $succeeded and ($artifacts.artifacts | any {|item| $item.name == $artifact and not $item.expired }) {
        if ($destination | path exists) { rm --recursive $destination }
        run gh ['run' 'download' ($run_id | into string) '--repo' $repo '--name' $artifact '--dir' $destination] | ignore
        $ready = true
        break
      }
      print $'Waiting for the CI cache artifact for ($host)...'
      sleep 30sec
    }
    require $ready $'Timed out waiting for CI artifact ($artifact)'
    let manifest = open ($destination | path join 'deployment.json')
    validate-manifest $manifest $sha $host
    $manifests = $manifests | insert $host $manifest
  }

  let expression = '{ nodes, ... }: { ' + ($hosts | each {|host| $'"($host)" = nodes."($host)".config.system.build.toplevel.outPath;' } | str join ' ') + ' }'
  let evaluated = run colmena ['--config' ($source | path join 'flake.nix') 'eval' '-E' $expression] | from json
  for host in $hosts {
    let manifest = $manifests | get $host
    require (($evaluated | get $host) == $manifest.system) $'CI / Colmena output mismatch for ($host)'
  }
  # Fetch output paths, since realizing derivations can bypass substitution preferences.
  for host in $hosts {
    let manifest = $manifests | get $host
    print $'Fetching the cached runtime closure for ($host)...'
    stream nix-store ['--realise' $manifest.system '--add-root' ($state | path join $'system-($host)') '--indirect' '--option' 'max-jobs' '0' '--option' 'builders' '' '--option' 'narinfo-cache-negative-ttl' '0']
  }

  # Matching local builds may lack signatures even when CI has published their paths.
  for host in $hosts {
    let system = ($manifests | get $host).system
    let trusted = ^nix store verify --recursive --no-contents --sigs-needed 1 $system | complete
    if $trusted.exit_code != 0 {
      let caches = $config.caches | each {|cache| ['--substituter' $cache] } | flatten
      stream nix (['store' 'copy-sigs' '--recursive' $system] | append $caches)
      stream nix ['store' 'verify' '--recursive' '--no-contents' '--sigs-needed' '1' $system]
    }
  }

  for name in $hosts {
    let host = $config.servers | get $name
    let expected = ($manifests | get $name).system
    if $settings != null { protect-proxy $settings $name }
    let checkpoint = $state | path join $'($name).json'
    let current = health $host
    require ($current.failed | is-empty) $'($name) already has failed units'
    let before = if ($checkpoint | path exists) { open $checkpoint } else {
      $current | save $checkpoint
      $current
    }
    # Preserve the known working generation until activation and reboot checks succeed.
    remote $host $'ln -sfn ($before.profile) /nix/var/nix/gcroots/deploy-($sha)-previous' | ignore
    if $current.profile != $expected {
      let closure = run nix ['path-info' '--json' '--json-format' '1' '--recursive' $expected] | from json | transpose path info | each {|item| $item.info | insert path $item.path }
      let paths = $closure | get path | str join ' '
      let missing = remote $host $'nix-store --check-validity --print-invalid ($paths)' | lines
      let bytes = $closure | where {|item| $item.path in $missing } | get narSize | append 0 | math sum
      require (($current.freeKiB * 1024) > ($bytes * 1.1 + 1073741824)) $'($name) lacks space for the missing runtime closure plus 1 GiB reserve. Inspect GC roots before continuing.'
      backup $host
      stream colmena ['--config' ($source | path join 'flake.nix') '--nix-option' 'max-jobs' '0' '--nix-option' 'builders' '' 'apply' 'switch' '--on' $name '--no-build-on-target' '--parallel' '1']
    }
    let after = wait-health $host $before $expected
    if $name == 'us-4' { umami-health $host }
    let kernel = remote $host $'basename ($expected)/kernel-modules/lib/modules/*'
    let rebooted = $before.rebootBoot? != null and $after.boot != $before.rebootBoot and $after.kernel == $kernel
    if $reboot and not $rebooted {
      $before | upsert rebootBoot $after.boot | save --force $checkpoint
      remote $host 'systemctl reboot' | ignore
      wait-reboot $host $after $expected
      if $name == 'us-4' { umami-health $host }
    }
    if $settings != null { check-proxy-routes $settings $name }
    remote $host $'rm /nix/var/nix/gcroots/deploy-($sha)-previous' | ignore
    print $'($name): expected system active, services healthy'
  }
  if $settings != null {
    delay $settings $original
    controller $settings $'/proxies/($settings.group)' --select $original | ignore
  }
}
