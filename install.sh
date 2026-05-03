#!/bin/bash
set -e

# ========= Настройки =========
ZSH_DIR="${HOME}/.oh-my-zsh"
ZDOTDIR="${HOME}"
REPO_BASE="https://raw.githubusercontent.com/ushst/my-zsh/main"
ZSHRC_URL="${REPO_BASE}/.zshrc"
ZSHRC_MANAGED_URL="${REPO_BASE}/zshrc.managed"
PLUGINS_REPO1="https://github.com/zsh-users/zsh-autosuggestions"
PLUGINS_REPO2="https://github.com/zsh-users/zsh-syntax-highlighting.git"
# =============================

download_file() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  else
    wget -q -O "$out" "$url"
  fi
}

echo "[*] Установка зависимостей..."
if [ -n "$TERMUX_VERSION" ] || [[ "$PREFIX" == *"com.termux"* ]]; then
  pkg install -y git zsh curl wget which
else
  # Debian/Ubuntu check
  if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y git zsh curl wget
  else
    echo "[!] Предупреждение: Не удалось найти apt. Пожалуйста, установите git, zsh, curl и wget вручную."
  fi
fi

echo "[*] Установка Oh-My-Zsh..."
# Скачаем и запускаем установщик oh-my-zsh в режиме unattended
export RUNZSH=no
export CHSH=yes
export KEEP_ZSHRC=yes
if command -v curl >/dev/null 2>&1; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --skip-chsh --keep-zshrc
else
  sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --skip-chsh --keep-zshrc
fi

echo "[*] Установка плагинов..."
git clone "$PLUGINS_REPO1" ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || true
git clone "$PLUGINS_REPO2" ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || true

echo "[*] Установка загрузчика .zshrc (my-zsh)..."
# Ставим loader один раз: если он уже установлен, не перезаписываем ~/.zshrc.
if [ -f "${ZDOTDIR}/.zshrc" ] && grep -q "my-zsh loader + auto-updater" "${ZDOTDIR}/.zshrc" 2>/dev/null; then
  echo "[*] ~/.zshrc уже установлен как my-zsh loader — пропускаю."
else
  # Не теряем существующий ~/.zshrc: делаем бэкап, если он есть.
  if [ -f "${ZDOTDIR}/.zshrc" ]; then
    cp -f "${ZDOTDIR}/.zshrc" "${ZDOTDIR}/.zshrc.backup.$(date +%Y%m%d-%H%M%S)" || true
  fi
  download_file "$ZSHRC_URL" "${ZDOTDIR}/.zshrc"
fi

echo "[*] Загрузка managed-конфига (auto-updated)..."
mkdir -p "${HOME}/.config/my-zsh" || true
download_file "$ZSHRC_MANAGED_URL" "${HOME}/.config/my-zsh/zshrc.managed"

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
    cp -f "$p" "$p.backup.$ts" 2>/dev/null || true
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
if [ -n "$TERMUX_VERSION" ]; then
  chsh -s zsh
else
  chsh -s "$(which zsh)" "$USER" || true
fi

echo "[*] Установка завершена! Запускаю новую сессию zsh..."
exec zsh
