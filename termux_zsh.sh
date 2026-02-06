#!/bin/bash
set -e

# ========= Настройки =========
ZSH_DIR="${HOME}/.oh-my-zsh"
ZDOTDIR="${HOME}"
ZSHRC_URL="https://raw.githubusercontent.com/ushst/my-zsh/main/.zshrc"
ZSHRC_MANAGED_URL="https://raw.githubusercontent.com/ushst/my-zsh/main/zshrc.managed"
PLUGINS_REPO1="https://github.com/zsh-users/zsh-autosuggestions"
PLUGINS_REPO2="https://github.com/zsh-users/zsh-syntax-highlighting.git"
# =============================

echo "[*] Установка зависимостей..."
pkg install -y git zsh curl wget which

echo "[*] Установка Oh-My-Zsh..."
# Скачаем и запускаем установщик oh-my-zsh в режиме unattended
export RUNZSH=no
export CHSH=yes
export KEEP_ZSHRC=yes
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --skip-chsh --keep-zshrc

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
  wget -O "${ZDOTDIR}/.zshrc" "$ZSHRC_URL"
fi

echo "[*] Загрузка managed-конфига (auto-updated)..."
mkdir -p "${HOME}/.config/my-zsh" || true
wget -O "${HOME}/.config/my-zsh/zshrc.managed" "$ZSHRC_MANAGED_URL"

# Если установка проходит в Termux — заменим "sudo apt install" на "apt install" в managed-конфиге
if [ -n "$TERMUX_VERSION" ] || ( [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]] ); then
  echo "[*] Обнаружен Termux — адаптирую managed-конфиг (замена 'sudo apt install' -> 'apt install')..."
  if grep -q "sudo apt install" "${HOME}/.config/my-zsh/zshrc.managed" 2>/dev/null; then
    # делаем inplace замену и удаляем бэкап, если он создастся
    sed -i.bak 's/sudo apt install/apt install/g' "${HOME}/.config/my-zsh/zshrc.managed" || true
    rm -f "${HOME}/.config/my-zsh/zshrc.managed.bak" || true
    echo "[*] Замена выполнена."
  else
    echo "[*] В managed-конфиге не найдено 'sudo apt install' — ничего менять не нужно."
  fi
fi

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
MICRORC_URL="https://raw.githubusercontent.com/ushst/my-zsh/main/.microrc"
MICRO_SHELL_SYNTAX_URL="https://raw.githubusercontent.com/ushst/my-zsh/main/.config/micro/syntax/shell.yaml"

if [ "${MY_ZSH_INSTALL_MICRO:-}" = "1" ] || ( [ "${MY_ZSH_INSTALL_MICRO:-}" != "0" ] && ask_yes_no "[?] Установить конфиг для micro ( .microrc + syntax )?" "N" ); then
  echo "[*] Установка конфига micro..."
  backup_if_exists "${HOME}/.microrc"
  wget -O "${HOME}/.microrc" "$MICRORC_URL"
  mkdir -p "${HOME}/.config/micro/syntax" || true
  backup_if_exists "${HOME}/.config/micro/syntax/shell.yaml"
  wget -O "${HOME}/.config/micro/syntax/shell.yaml" "$MICRO_SHELL_SYNTAX_URL"
fi

# msfconsole
MSFCONSOLE_RC_URL="https://raw.githubusercontent.com/ushst/my-zsh/main/msfconsole.rc"

if [ "${MY_ZSH_INSTALL_MSFCONSOLE:-}" = "1" ] || ( [ "${MY_ZSH_INSTALL_MSFCONSOLE:-}" != "0" ] && ask_yes_no "[?] Установить конфиг для msfconsole ( alias s -> search )?" "N" ); then
  echo "[*] Установка конфига msfconsole..."
  mkdir -p "${HOME}/.msf4" || true
  backup_if_exists "${HOME}/.msf4/msfconsole.rc"
  wget -O "${HOME}/.msf4/msfconsole.rc" "$MSFCONSOLE_RC_URL"
fi

echo "[*] Смена стандартной оболочки на zsh..."
chsh -s "$(which zsh)" "$USER"

echo "[*] Установка завершена! Запускаю новую сессию zsh..."
exec zsh
