#!/bin/bash
set -e

# ========= Настройки =========
ZSH_DIR="${HOME}/.oh-my-zsh"
ZDOTDIR="${HOME}"
ZSHRC_URL="https://raw.githubusercontent.com/krolchonok/my-zsh/main/.zshrc"
PLUGINS_REPO1="https://github.com/zsh-users/zsh-autosuggestions"
PLUGINS_REPO2="https://github.com/zsh-users/zsh-syntax-highlighting.git"
# =============================

echo "[*] Установка зависимостей..."
sudo apt install -y git zsh curl wget

echo "[*] Установка Oh-My-Zsh..."
# Скачаем и запускаем установщик oh-my-zsh в режиме unattended
export RUNZSH=no
export CHSH=yes
export KEEP_ZSHRC=yes
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --skip-chsh --keep-zshrc

echo "[*] Установка плагинов..."
git clone "$PLUGINS_REPO1" ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || true
git clone "$PLUGINS_REPO2" ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || true

echo "[*] Загрузка конфигурации .zshrc..."
wget -O "${ZDOTDIR}/.zshrc" "$ZSHRC_URL"

echo "[*] Смена стандартной оболочки на zsh..."
chsh -s "$(which zsh)" "$USER"

echo "[*] Установка завершена! Чтобы применить изменения выполните:"
echo "   exec zsh"
