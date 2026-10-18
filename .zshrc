# --- my-zsh loader + auto-updater (github.com/ushst/my-zsh) ---
# This file is intended to stay small and stable.
# Your personal config should go to ~/.zshrc.local or ~/.zshrc.d/*.zsh

# Keep the entry point stable; updates live beside the managed configuration.
if [[ -z ${_MY_ZSH_LOADER_ACTIVE:-} && -s "${XDG_CONFIG_HOME:-$HOME/.config}/my-zsh/loader.managed.zsh" ]]; then
  typeset -g _MY_ZSH_LOADER_ACTIVE=1
  source "${XDG_CONFIG_HOME:-$HOME/.config}/my-zsh/loader.managed.zsh"
  unset _MY_ZSH_LOADER_ACTIVE
  return
fi

typeset -gA MyZshUpdaterCfg
MyZshUpdaterCfg[repoRawBase]="https://raw.githubusercontent.com/ushst/my-zsh/main"
MyZshUpdaterCfg[remoteVersionPath]="version.txt"
MyZshUpdaterCfg[remoteManagedPath]="zshrc.managed"
MyZshUpdaterCfg[checkIntervalSeconds]=21600   # 6 hours
MyZshUpdaterCfg[offlineRetrySeconds]=300      # retry in 5 minutes if offline
MyZshUpdaterCfg[networkCheckRetries]=1
MyZshUpdaterCfg[networkRetryDelaySeconds]=1
MyZshUpdaterCfg[networkCheckTimeoutSeconds]=2
MyZshUpdaterCfg[downloadTimeoutSeconds]=30

my_zsh_state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/my-zsh"
my_zsh_config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/my-zsh"
( umask 077; mkdir -p "${my_zsh_state_dir}" "${my_zsh_config_dir}" ) 2>/dev/null || true

my_zsh_last_check_file="${my_zsh_state_dir}/last_check"
my_zsh_local_version_file="${my_zsh_state_dir}/local_version"
my_zsh_lock_dir="${my_zsh_state_dir}/lockdir"

my_zsh_managed_file="${my_zsh_config_dir}/zshrc.managed"
my_zsh_local_file="${HOME}/.zshrc.local"
my_zsh_local_dir="${HOME}/.zshrc.d"

my_zsh_get_local_version() {
  [[ -f "${my_zsh_local_version_file}" ]] && cat "${my_zsh_local_version_file}" && return
  echo "0.0.0"
}

my_zsh_version_lt() {
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" && "$1" != "$2" ]]
}

my_zsh_should_check_now() {
  local now last
  now=$(date +%s)
  [[ ! -f "${my_zsh_last_check_file}" ]] && return 0
  last=$(<"${my_zsh_last_check_file}")
  [[ "$last" == <-> ]] || return 0
  (( now < last || now - last >= MyZshUpdaterCfg[checkIntervalSeconds] ))
}

my_zsh_with_lock() (
  local owner
  if ! mkdir "${my_zsh_lock_dir}" 2>/dev/null; then
    owner=$(cat "${my_zsh_lock_dir}/pid" 2>/dev/null)
    if [[ "$owner" == <-> ]]; then
      kill -0 "$owner" 2>/dev/null && return 1
    else
      [[ -n "$(find "${my_zsh_lock_dir}" -maxdepth 0 -mmin +2 2>/dev/null)" ]] || return 1
    fi
    rm -f "${my_zsh_lock_dir}/pid" || return 1
    rmdir "${my_zsh_lock_dir}" 2>/dev/null || return 1
    mkdir "${my_zsh_lock_dir}" 2>/dev/null || return 1
  fi
  trap 'rm -f "${my_zsh_lock_dir}/pid"; rmdir "${my_zsh_lock_dir}" 2>/dev/null' EXIT
  zmodload zsh/system || return 1
  print -r -- "$sysparams[pid]" > "${my_zsh_lock_dir}/pid" || return 1
  "$@"
)

my_zsh_network_available() {
  local testUrl retries delay timeout attempt
  testUrl="${MyZshUpdaterCfg[repoRawBase]}/${MyZshUpdaterCfg[remoteVersionPath]}"
  retries=${MyZshUpdaterCfg[networkCheckRetries]}
  delay=${MyZshUpdaterCfg[networkRetryDelaySeconds]}
  timeout=${MyZshUpdaterCfg[networkCheckTimeoutSeconds]}

  for (( attempt = 1; attempt <= retries; attempt++ )); do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsI --connect-timeout 2 --max-time "${timeout}" "${testUrl}" >/dev/null 2>&1; then
        return 0
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -q --spider --timeout="${timeout}" "${testUrl}" >/dev/null 2>&1; then
        return 0
      fi
    else
      return 1
    fi
    sleep "${delay}"
  done

  return 1
}

my_zsh_schedule_offline_retry() {
  # Retry on the next shell after a short interval; leave no persistent sleeper.
  print -r -- "$(( $(date +%s) - MyZshUpdaterCfg[checkIntervalSeconds] + MyZshUpdaterCfg[offlineRetrySeconds] ))" > "${my_zsh_last_check_file}"
}

my_zsh_fetch_stdout() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 5 --max-time "${MyZshUpdaterCfg[downloadTimeoutSeconds]}" "${url}" 2>/dev/null
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q --timeout=10 --tries=1 -O - "${url}" 2>/dev/null
    return $?
  fi
  return 1
}

my_zsh_fetch_to() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 5 --max-time "${MyZshUpdaterCfg[downloadTimeoutSeconds]}" "${url}" -o "${out}"
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q --timeout=10 --tries=1 -O "${out}" "${url}"
    return $?
  fi
  return 1
}

# Public entry point also takes the lock, including manual invocations.
my_zsh_do_update_check() { my_zsh_with_lock _my_zsh_do_update_check; }

_my_zsh_do_update_check() (
  umask 077
  local repo remoteVersion localVersion stage backup hadManaged=0 hadLoader=0
  repo="${MyZshUpdaterCfg[repoRawBase]}"
  remoteVersion=$(my_zsh_fetch_stdout "${repo}/${MyZshUpdaterCfg[remoteVersionPath]}") || return 1
  [[ "$remoteVersion" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || return 1
  localVersion=$(my_zsh_get_local_version)
  [[ "$localVersion" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || localVersion=0.0.0
  if [[ -s "$my_zsh_managed_file" && -s "$my_zsh_config_dir/loader.managed.zsh" ]]; then
    my_zsh_version_lt "$localVersion" "$remoteVersion" || return 0
  fi
  stage=$(mktemp -d "${my_zsh_config_dir}/.update.XXXXXXXX") || return 1
  trap 'rm -rf -- "$stage"' EXIT
  my_zsh_fetch_to "${repo}/${MyZshUpdaterCfg[remoteManagedPath]}" "$stage/managed" || return 1
  my_zsh_fetch_to "${repo}/.zshrc" "$stage/loader" || return 1
  [[ -s "$stage/managed" && -s "$stage/loader" ]] || return 1
  zsh -n "$stage/managed" && zsh -n "$stage/loader" || return 1
  # Reject a mixed release if version.txt changed while downloading.
  [[ "$(my_zsh_fetch_stdout "${repo}/${MyZshUpdaterCfg[remoteVersionPath]}")" == "$remoteVersion" ]] || return 1
  backup=$(mktemp -d "${my_zsh_state_dir}/backup.XXXXXXXX") || return 1
  if [[ -f "$my_zsh_managed_file" ]]; then
    cp -p "$my_zsh_managed_file" "$backup/managed" || return 1
    hadManaged=1
  fi
  if [[ -f "$my_zsh_config_dir/loader.managed.zsh" ]]; then
    cp -p "$my_zsh_config_dir/loader.managed.zsh" "$backup/loader" || return 1
    hadLoader=1
  fi
  print -r -- "$remoteVersion" > "$stage/version" || return 1
  if mv -f "$stage/managed" "$my_zsh_managed_file" &&
     mv -f "$stage/loader" "$my_zsh_config_dir/loader.managed.zsh" &&
     mv -f "$stage/version" "$my_zsh_local_version_file"; then
    [[ -t 1 ]] && print -r -- "[my-zsh] Updated to $remoteVersion. Backup: $backup. Restart shell."
    return 0
  fi
  if (( hadManaged )); then cp -p "$backup/managed" "$my_zsh_managed_file" || return 1
  else rm -f "$my_zsh_managed_file"; fi
  if (( hadLoader )); then cp -p "$backup/loader" "$my_zsh_config_dir/loader.managed.zsh" || return 1
  else rm -f "$my_zsh_config_dir/loader.managed.zsh"; fi
  return 1
)

my_zsh_update_check() {
  local force="${1:-0}"

  # Allow disabling auto-update.
  [[ "${MY_ZSH_AUTOUPDATE:-1}" == "0" ]] && return 0

  (( force )) || my_zsh_should_check_now || return 0

  if ! my_zsh_network_available; then
    echo "$(date +%s)" > "${my_zsh_last_check_file}"
    [[ -t 1 ]] && echo "[my-zsh] Offline. Will retry later."
    my_zsh_schedule_offline_retry
    return 0
  fi

  my_zsh_do_update_check || { my_zsh_schedule_offline_retry; return 1; }
  echo "$(date +%s)" > "${my_zsh_last_check_file}"
}

# --- load managed config (auto-updated) ---
if [[ -f "${my_zsh_managed_file}" ]]; then
  source "${my_zsh_managed_file}"
fi

# --- load user overrides ---
if [[ -f "${my_zsh_local_file}" ]]; then
  source "${my_zsh_local_file}"
fi

if [[ -d "${my_zsh_local_dir}" ]]; then
  for f in "${my_zsh_local_dir}"/*.zsh(N); do
    source "$f"
  done
fi

# Update last: takes effect next shell.
my_zsh_trigger_update_check() {
  # Only check in interactive shells
  [[ -o interactive ]] || return 0

  # Allow disabling auto-update
  [[ "${MY_ZSH_AUTOUPDATE:-1}" == "0" ]] && return 0

  # Only spawn background check if check interval elapsed
  my_zsh_should_check_now || return 0

  # Detach in a disowned background subshell without re-sourcing .zshrc
  ( sleep 3; my_zsh_update_check "$@" ) </dev/null >/dev/null 2>&1 &!
}

if [[ -o interactive ]]; then
  my_zsh_trigger_update_check
fi
# --- end my-zsh loader + auto-updater ---
