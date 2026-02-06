# --- my-zsh loader + auto-updater (github.com/ushst/my-zsh) ---
# This file is intended to stay small and stable.
# Your personal config should go to ~/.zshrc.local or ~/.zshrc.d/*.zsh

typeset -gA MyZshUpdaterCfg
MyZshUpdaterCfg[repoRawBase]="https://raw.githubusercontent.com/ushst/my-zsh/main"
MyZshUpdaterCfg[remoteVersionPath]="version.txt"
MyZshUpdaterCfg[remoteManagedPath]="zshrc.managed"
MyZshUpdaterCfg[checkIntervalSeconds]=21600   # 6 hours
MyZshUpdaterCfg[offlineRetrySeconds]=300      # retry in 5 minutes if offline
MyZshUpdaterCfg[networkCheckRetries]=3
MyZshUpdaterCfg[networkRetryDelaySeconds]=1
MyZshUpdaterCfg[networkCheckTimeoutSeconds]=2

my_zsh_state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/my-zsh"
my_zsh_config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/my-zsh"
mkdir -p "${my_zsh_state_dir}" "${my_zsh_config_dir}" 2>/dev/null || true

my_zsh_last_check_file="${my_zsh_state_dir}/last_check"
my_zsh_local_version_file="${my_zsh_state_dir}/local_version"
my_zsh_lock_dir="${my_zsh_state_dir}/lockdir"
my_zsh_deferred_flag="${my_zsh_state_dir}/deferred_check_scheduled"

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
  (( now - last >= MyZshUpdaterCfg[checkIntervalSeconds] ))
}

my_zsh_with_lock() {
  # Portable lock (no flock dependency): mkdir is atomic on POSIX filesystems.
  if mkdir "${my_zsh_lock_dir}" 2>/dev/null; then
    "$@"
    rmdir "${my_zsh_lock_dir}" 2>/dev/null || true
    return 0
  fi
  return 1
}

my_zsh_network_available() {
  local testUrl retries delay timeout attempt
  testUrl="${MyZshUpdaterCfg[repoRawBase]}/${MyZshUpdaterCfg[remoteVersionPath]}"
  retries=${MyZshUpdaterCfg[networkCheckRetries]}
  delay=${MyZshUpdaterCfg[networkRetryDelaySeconds]}
  timeout=${MyZshUpdaterCfg[networkCheckTimeoutSeconds]}

  for (( attempt = 1; attempt <= retries; attempt++ )); do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsI --max-time "${timeout}" "${testUrl}" >/dev/null 2>&1; then
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

my_zsh_update_local_version_cache() { echo "$1" > "${my_zsh_local_version_file}"; }

my_zsh_schedule_offline_retry() {
  local delay="${MyZshUpdaterCfg[offlineRetrySeconds]}"
  [[ -f "${my_zsh_deferred_flag}" ]] && return 0

  echo "${delay}" > "${my_zsh_deferred_flag}"
  (
    sleep "${delay}"
    rm -f "${my_zsh_deferred_flag}"
    my_zsh_update_check 1
  ) >/dev/null 2>&1 &
}

my_zsh_fetch_to() {
  local url out
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${out}"
    return $?
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -O "${out}" "${url}"
    return $?
  fi
  return 1
}

my_zsh_do_update_check() {
  local repo remoteVersion localVersion tmpNew backup

  repo="${MyZshUpdaterCfg[repoRawBase]}"
  remoteVersion="$( (command -v curl >/dev/null 2>&1 && curl -fsSL "${repo}/${MyZshUpdaterCfg[remoteVersionPath]}" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && wget -q -O - "${repo}/${MyZshUpdaterCfg[remoteVersionPath]}" 2>/dev/null) || true )"
  [[ -n "${remoteVersion}" ]] || return 0

  localVersion="$(my_zsh_get_local_version)"

  # If managed file doesn't exist yet, treat it like version 0.0.0.
  if [[ ! -f "${my_zsh_managed_file}" ]]; then
    localVersion="0.0.0"
  fi

  if my_zsh_version_lt "${localVersion}" "${remoteVersion}"; then
    tmpNew="${my_zsh_state_dir}/zshrc.managed.new"
    backup="${my_zsh_state_dir}/managed.backup.$(date +%Y%m%d-%H%M%S)"

    if [[ -t 1 ]]; then
      echo -n "[my-zsh] Checking updates"
      for i in 1 2 3; do sleep 0.2; echo -n "."; done
      echo
    fi

    if my_zsh_fetch_to "${repo}/${MyZshUpdaterCfg[remoteManagedPath]}" "${tmpNew}"; then
      cp -f "${my_zsh_managed_file}" "${backup}" 2>/dev/null || true
      mv -f "${tmpNew}" "${my_zsh_managed_file}"
      my_zsh_update_local_version_cache "${remoteVersion}"
      [[ -t 1 ]] && echo "[my-zsh] Updated managed config to ${remoteVersion}. Backup: ${backup}. Restart shell."
    fi
  fi
}

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

  my_zsh_with_lock my_zsh_do_update_check || true
  echo "$(date +%s)" > "${my_zsh_last_check_file}"
}

my_zsh_trigger_update_check() {
  # Run in background to avoid slowing shell startup.
  ( my_zsh_update_check "$@" ) &!
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
my_zsh_trigger_update_check
# --- end my-zsh loader + auto-updater ---

