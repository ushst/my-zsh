# VERSION=1.0.0
# --- zshrc auto-updater (github.com/ushst/my-zsh) ---
typeset -gA UpdaterCfg
UpdaterCfg[repoRawBase]="https://raw.githubusercontent.com/ushst/my-zsh/main"
UpdaterCfg[remoteZshrcPath]=".zshrc"
UpdaterCfg[remoteVersionPath]="version.txt"
UpdaterCfg[checkIntervalSeconds]=0   # 6 часов

localZshrc="${HOME}/.zshrc"
localStateDir="${XDG_STATE_HOME:-${HOME}/.local/state}/zsh-updater"
mkdir -p "${localStateDir}"

lastCheckFile="${localStateDir}/last_check"
localVersionFile="${localStateDir}/local_version"
lockFile="${localStateDir}/lock"

get_local_version() {
  if [[ -f "${localVersionFile}" ]]; then cat "${localVersionFile}"; return; fi
  if [[ -f "${localZshrc}" ]]; then sed -n 's/^# *VERSION=\(.*\)$/\1/p' "${localZshrc}" | head -n1; fi
}

version_lt() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]]; }

should_check_now() {
  now=$(date +%s)
  [[ ! -f "${lastCheckFile}" ]] && return 0
  last=$(<"${lastCheckFile}")
  (( now - last >= UpdaterCfg[checkIntervalSeconds] ))
}

with_lock() { exec 9>"${lockFile}"; flock -n 9 || return 1; "$@"; }

update_local_version_cache() { echo "$1" > "${localVersionFile}"; }

zshrc_update_check() {
  should_check_now || return 0
  with_lock _do_update_check
  echo "$(date +%s)" > "${lastCheckFile}"
}

_do_update_check() {
  local repo="${UpdaterCfg[repoRawBase]}"
  local rverPath="${UpdaterCfg[remoteVersionPath]}"
  local rcfgPath="${UpdaterCfg[remoteZshrcPath]}"

  remoteVersion="$(curl -fsSL "${repo}/${rverPath}" 2>/dev/null || true)"
  [[ -n "${remoteVersion}" ]] || return 0

  localVersion="$(get_local_version)"; [[ -n "${localVersion}" ]] || localVersion="0.0.0"

  if version_lt "${localVersion}" "${remoteVersion}"; then
    tmpNew="${localStateDir}/.zshrc.new"
    backup="${localStateDir}/zshrc.backup.$(date +%Y%m%d-%H%M%S)"

    # Полоса проверки (простая имитация)
    if [[ -t 1 ]]; then
      echo -n "[zsh-updater] Проверка"
      for i in 1 2 3; do
        sleep 0.3
        echo -n "."
      done
      echo
    fi

    if curl -fsSL "${repo}/${rcfgPath}" -o "${tmpNew}"; then
      grep -q "^# *VERSION=${remoteVersion}\b" "${tmpNew}" || { rm -f "${tmpNew}"; return 0; }
      cp -f "${localZshrc}" "${backup}" 2>/dev/null || true
      mv -f "${tmpNew}" "${localZshrc}"
      update_local_version_cache "${remoteVersion}"
      [[ -t 1 ]] && echo "[zsh-updater] Обновлено до ${remoteVersion}. Бэкап: ${backup}. Перезапусти shell."
    fi
  fi
}

# Теперь не в фоне, а тихо при старте
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
