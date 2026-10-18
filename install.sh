#!/bin/bash
set -e
umask 077

# ========= Настройки =========
export ZSH="${ZSH:-${HOME}/.oh-my-zsh}"
ZDOTDIR="${ZDOTDIR:-${HOME}}"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/my-zsh"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/my-zsh"
INSTALL_TMP=$(mktemp -d)
cleanup_install() {
  rm -rf -- "$INSTALL_TMP"
  if [[ ${install_lock_owned:-0} == 1 ]]; then
    rm -f "$STATE_DIR/lockdir/pid"
    rmdir "$STATE_DIR/lockdir" 2>/dev/null || true
  fi
  local pending
  for pending in "${managed_new:-}" "${loader_new:-}" "${entry_new:-}"; do
    [[ -z "$pending" ]] || rm -f -- "$pending"
  done
}
trap cleanup_install EXIT
REPO_BASE="https://raw.githubusercontent.com/ushst/my-zsh/main"
ZSHRC_URL="${REPO_BASE}/.zshrc"
ZSHRC_MANAGED_URL="${REPO_BASE}/zshrc.managed"
# =============================

download_file() {
  local url="$1" out="$2" tmp
  mkdir -p "$(dirname "$out")"
  tmp=$(mktemp "${out}.tmp.XXXXXXXX") || return 1
  if ! {
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL --connect-timeout 5 --max-time 30 "$url" -o "$tmp"
    else
      wget -q --timeout=10 --tries=1 -O "$tmp" "$url"
    fi
  }; then
    rm -f "$tmp"
    return 1
  fi
  if [[ ! -s "$tmp" ]]; then rm -f "$tmp"; return 1; fi
  mv -f "$tmp" "$out"
}

echo "[*] Установка зависимостей..."
if [ -n "$TERMUX_VERSION" ] || [[ "$PREFIX" == *"com.termux"* ]]; then
  pkg install -y git zsh curl wget which
else
  # Debian/Ubuntu check
  if command -v apt >/dev/null 2>&1; then
    if (( EUID == 0 )); then
      apt update && apt install -y git zsh curl wget
    else
      sudo apt update && sudo apt install -y git zsh curl wget
    fi
  else
    for dependency in git zsh; do
      command -v "$dependency" >/dev/null || { echo "[!] Установите $dependency вручную." >&2; exit 1; }
    done
  fi
fi

echo "[*] Установка Oh-My-Zsh..."
# Скачаем и запускаем установщик oh-my-zsh в режиме unattended
export RUNZSH=no
export CHSH=yes
export KEEP_ZSHRC=yes
if [[ ! -f "$ZSH/oh-my-zsh.sh" ]]; then
  download_file "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "$INSTALL_TMP/omz.sh"
  sh "$INSTALL_TMP/omz.sh" --unattended --skip-chsh --keep-zshrc
fi

echo "[*] Установка плагинов..."
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  plugin_dir="${ZSH_CUSTOM:-$ZSH/custom}/plugins/$plugin"
  if [[ ! -f "$plugin_dir/$plugin.zsh" && ! -f "$plugin_dir/$plugin.plugin.zsh" ]]; then
    if [[ -e "$plugin_dir" ]]; then
      echo "[!] Неполная установка плагина: $plugin_dir" >&2
      exit 1
    fi
    git clone "https://github.com/zsh-users/$plugin.git" "$plugin_dir"
  fi
done

echo "[*] Проверка новых конфигов..."
download_file "$ZSHRC_URL" "$INSTALL_TMP/loader"
download_file "$ZSHRC_MANAGED_URL" "$INSTALL_TMP/managed"
zsh -n "$INSTALL_TMP/loader"
zsh -n "$INSTALL_TMP/managed"
mkdir -p "$ZDOTDIR" "$CONFIG_DIR" "$STATE_DIR" "$HOME/.zshrc.d"
# Do not replace files while a background update or another installer is running.
if ! mkdir "$STATE_DIR/lockdir" 2>/dev/null; then
  echo "[!] Обновление уже выполняется. Повторите установку после его завершения." >&2
  exit 1
fi
install_lock_owned=1
printf '%s\n' "$$" > "$STATE_DIR/lockdir/pid"
backup_dir=$(mktemp -d "$STATE_DIR/install-backup.XXXXXXXX")
# Preserve personal additions after the old loader's end marker, in load order.
if [[ -f "$ZDOTDIR/.zshrc" ]]; then
  cp -p "$ZDOTDIR/.zshrc" "$backup_dir/zshrc"
  if grep -q '^# --- end my-zsh loader + auto-updater ---$' "$ZDOTDIR/.zshrc"; then
    awk 'found { print } /^# --- end my-zsh loader \+ auto-updater ---$/ { found=1 }' "$ZDOTDIR/.zshrc" > "$INSTALL_TMP/legacy"
  elif grep -q 'my-zsh loader + auto-updater' "$ZDOTDIR/.zshrc"; then
    echo "[!] Неизвестная версия загрузчика; исходный файл сохранён: $backup_dir/zshrc" >&2
    exit 1
  else
    cp "$ZDOTDIR/.zshrc" "$INSTALL_TMP/legacy"
  fi
  if [[ -s "$INSTALL_TMP/legacy" ]]; then
    zsh -n "$INSTALL_TMP/legacy"
  fi
fi
# Stage files on their destination filesystems before replacing anything.
managed_new=$(mktemp "$CONFIG_DIR/.managed.XXXXXXXX")
loader_new=$(mktemp "$CONFIG_DIR/.loader.XXXXXXXX")
entry_new=$(mktemp "$ZDOTDIR/.zshrc.XXXXXXXX")
cp "$INSTALL_TMP/managed" "$managed_new"
cp "$INSTALL_TMP/loader" "$loader_new"
cp "$INSTALL_TMP/loader" "$entry_new"
for name in zshrc.managed loader.managed.zsh; do
  if [[ -f "$CONFIG_DIR/$name" ]]; then cp -p "$CONFIG_DIR/$name" "$backup_dir/$name"; fi
done
if [[ -s "$INSTALL_TMP/legacy" ]]; then
  legacy=$(mktemp "$HOME/.zshrc.d/zz-legacy.XXXXXXXX.zsh")
  cp "$INSTALL_TMP/legacy" "$legacy"
fi
if ! { mv -f "$managed_new" "$CONFIG_DIR/zshrc.managed" &&
       mv -f "$loader_new" "$CONFIG_DIR/loader.managed.zsh" &&
       mv -f "$entry_new" "$ZDOTDIR/.zshrc"; }; then
  for name in zshrc.managed loader.managed.zsh; do
    if [[ -f "$backup_dir/$name" ]]; then cp -p "$backup_dir/$name" "$CONFIG_DIR/$name"
    else rm -f "$CONFIG_DIR/$name"; fi
  done
  [[ ! -f "$backup_dir/zshrc" ]] || cp -p "$backup_dir/zshrc" "$ZDOTDIR/.zshrc"
  [[ -z "${legacy:-}" ]] || rm -f "$legacy"
  rm -f "$managed_new" "$loader_new" "$entry_new"
  exit 1
fi
# Let the updater establish the release version rather than cache a mixed release.
rm -f "$STATE_DIR/local_version"
echo "[*] Резервная копия: $backup_dir"

echo "[*] Создаю файл для пользовательских правок: ~/.zshrc.local (если его нет)..."
if [ ! -f "${HOME}/.zshrc.local" ]; then
  cat > "${HOME}/.zshrc.local" <<'EOF'
# Your custom zsh config goes here.
# This file will NOT be overwritten by my-zsh updates.
EOF
fi

# ========= Optional configs =========
ask_yes_no() {
  # Usage: ask_yes_no "Question" "N|Y"
  local question default reply
  question="$1"
  default="${2:-N}"

  # Non-interactive shell: honor default.
  if [ ! -t 0 ]; then
    [ "${default}" = "Y" ] && return 0 || return 1
  fi

  read -r -p "${question} [y/N]: " reply
  reply="${reply:-$default}"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

backup_if_exists() {
  local p ts
  p="$1"
  ts="$(date +%Y%m%d-%H%M%S)"
  if [ -f "$p" ]; then
    cp -p "$p" "$p.backup.$ts"
  fi
}

# Micro
MICRORC_URL="${REPO_BASE}/.microrc"
MICRO_SHELL_SYNTAX_URL="${REPO_BASE}/.config/micro/syntax/shell.yaml"

if [ "${MY_ZSH_INSTALL_MICRO:-}" = "1" ] || ( [ "${MY_ZSH_INSTALL_MICRO:-}" != "0" ] && ask_yes_no "[?] Установить конфиг для micro ( .microrc + syntax )?" "N" ); then
  echo "[*] Установка конфига micro..."
  backup_if_exists "${HOME}/.microrc"
  download_file "$MICRORC_URL" "${HOME}/.microrc"
  mkdir -p "${HOME}/.config/micro/syntax" || true
  backup_if_exists "${HOME}/.config/micro/syntax/shell.yaml"
  download_file "$MICRO_SHELL_SYNTAX_URL" "${HOME}/.config/micro/syntax/shell.yaml"
fi

# msfconsole
MSFCONSOLE_RC_URL="${REPO_BASE}/msfconsole.rc"

if [ "${MY_ZSH_INSTALL_MSFCONSOLE:-}" = "1" ] || ( [ "${MY_ZSH_INSTALL_MSFCONSOLE:-}" != "0" ] && ask_yes_no "[?] Установить конфиг для msfconsole ( alias s -> search )?" "N" ); then
  echo "[*] Установка конфига msfconsole..."
  mkdir -p "${HOME}/.msf4" || true
  backup_if_exists "${HOME}/.msf4/msfconsole.rc"
  download_file "$MSFCONSOLE_RC_URL" "${HOME}/.msf4/msfconsole.rc"
fi

echo "[*] Смена стандартной оболочки на zsh..."
if [ -n "$TERMUX_VERSION" ] || [[ "$PREFIX" == *com.termux* ]]; then
  chsh -s zsh
else
  chsh -s "$(which zsh)" "$USER" || true
fi

echo "[*] Установка завершена! Запускаю новую сессию zsh..."
if [[ -t 0 && -t 1 ]]; then exec zsh; fi
