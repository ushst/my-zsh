# --- zshrc auto-updater (github.com/ushst/my-zsh) ---
typeset -gA UpdaterCfg
UpdaterCfg[repoRawBase]="https://raw.githubusercontent.com/ushst/my-zsh/main"
UpdaterCfg[remoteZshrcPath]=".zshrc"
UpdaterCfg[remoteVersionPath]="version.txt"
UpdaterCfg[checkIntervalSeconds]=21600   # 6 часов
UpdaterCfg[offlineRetrySeconds]=300       # повторная попытка через 5 минут, если сети нет
UpdaterCfg[networkCheckRetries]=3
UpdaterCfg[networkRetryDelaySeconds]=1
UpdaterCfg[networkCheckTimeoutSeconds]=2

localZshrc="${HOME}/.zshrc"
localStateDir="${XDG_STATE_HOME:-${HOME}/.local/state}/zsh-updater"
mkdir -p "${localStateDir}"

lastCheckFile="${localStateDir}/last_check"
localVersionFile="${localStateDir}/local_version"
lockFile="${localStateDir}/lock"
deferredFlag="${localStateDir}/deferred_check_scheduled"

get_local_version() {
  [[ -f "${localVersionFile}" ]] && cat "${localVersionFile}" && return
  echo "0.0.0"
}

version_lt() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" && "$1" != "$2" ]]; }

should_check_now() {
  now=$(date +%s)
  [[ ! -f "${lastCheckFile}" ]] && return 0
  last=$(<"${lastCheckFile}")
  (( now - last >= UpdaterCfg[checkIntervalSeconds] ))
}

with_lock() { exec 9>"${lockFile}"; flock -n 9 || return 1; "$@"; }

update_local_version_cache() { echo "$1" > "${localVersionFile}"; }

network_available() {
  local testUrl="${UpdaterCfg[repoRawBase]}/${UpdaterCfg[remoteVersionPath]}"
  local retries=${UpdaterCfg[networkCheckRetries]}
  local delay=${UpdaterCfg[networkRetryDelaySeconds]}
  local timeout=${UpdaterCfg[networkCheckTimeoutSeconds]}

  for (( attempt = 1; attempt <= retries; attempt++ )); do
    if curl -fsI --max-time "${timeout}" "${testUrl}" >/dev/null 2>&1; then
      return 0
    fi
    sleep "${delay}"
  done

  return 1
}

schedule_offline_retry() {
  local delay="${UpdaterCfg[offlineRetrySeconds]}"
  [[ -f "${deferredFlag}" ]] && return 0

  echo "${delay}" > "${deferredFlag}"
  (
    sleep "${delay}"
    rm -f "${deferredFlag}"
    zshrc_update_check 1
  ) >/dev/null 2>&1 &
}

zshrc_update_check() {
  local force="${1:-0}"

  (( force )) || should_check_now || return 0

  if ! network_available; then
    echo "$(date +%s)" > "${lastCheckFile}"
    [[ -t 1 ]] && echo "[zsh-updater] Сети нет. Повторим проверку позже."
    schedule_offline_retry
    return 0
  fi

  with_lock _do_update_check
  echo "$(date +%s)" > "${lastCheckFile}"
}

_do_update_check() {
  local repo="${UpdaterCfg[repoRawBase]}"
  local rverPath="${UpdaterCfg[remoteVersionPath]}"
  local rcfgPath="${UpdaterCfg[remoteZshrcPath]}"

  remoteVersion="$(curl -fsSL "${repo}/${rverPath}" 2>/dev/null || true)"
  [[ -n "${remoteVersion}" ]] || return 0

  localVersion="$(get_local_version)"

  if version_lt "${localVersion}" "${remoteVersion}"; then
    tmpNew="${localStateDir}/.zshrc.new"
    backup="${localStateDir}/zshrc.backup.$(date +%Y%m%d-%H%M%S)"

    # простая «полоса проверки»
    if [[ -t 1 ]]; then
      echo -n "[zsh-updater] Проверка"
      for i in 1 2 3; do sleep 0.2; echo -n "."; done
      echo
    fi

    if curl -fsSL "${repo}/${rcfgPath}" -o "${tmpNew}"; then
      cp -f "${localZshrc}" "${backup}" 2>/dev/null || true
      mv -f "${tmpNew}" "${localZshrc}"
      update_local_version_cache "${remoteVersion}"
      [[ -t 1 ]] && echo "[zsh-updater] Обновлено до ${remoteVersion}. Бэкап: ${backup}. Перезапусти shell."
    fi
  fi
}

zshrc_update_check
# --- end zshrc auto-updater ---

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="avit"

# Plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)
source $ZSH/oh-my-zsh.sh

# User configuration
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)"
  fi
}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Custom aliases and functions
alias untargz='tar -xvzf'

function a() {
    if [ "$1" = "i" ]; then
        shift
        sudo apt install "$@"
    else
        echo "Неизвестная команда: a $1"
    fi
}

extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xvjf "$1"    ;;
      *.tar.gz)    tar xvzf "$1"    ;;
      *.tar.xz)    tar xvJf "$1"    ;;
      *.tar)       tar xvf "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.zip)       unzip "$1"       ;;
      *.rar)       unrar x "$1"     ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "Неизвестный формат: $1" ;;
    esac
  else
    echo "Файл не найден: $1"
  fi
}
alias x='extract'
