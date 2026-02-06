# ZSH
`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/install.sh)"`

`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/termux_zsh.sh)"`

## Как теперь хранить свои изменения
- `~/.zshrc` это загрузчик + автообновление managed-конфига.
- Основная конфигурация обновляется в `~/.config/my-zsh/zshrc.managed`.
- Твои личные настройки добавляй в `~/.zshrc.local` или в файлы `~/.zshrc.d/*.zsh` (они не будут перезаписываться).
- Установщик ставит `~/.zshrc` один раз. Повторный запуск `install.sh`/`termux_zsh.sh` не перезапишет его, если там уже my-zsh loader.

## Отключить автообновление
Добавь в `~/.zshrc.local`:
`export MY_ZSH_AUTOUPDATE=0`

# MICRO
Конфиг micro лежит в репо: `.microrc` и `.config/micro/syntax/shell.yaml`.

Установить вручную:
`wget -O ~/.microrc https://raw.githubusercontent.com/ushst/my-zsh/main/.microrc`
`mkdir -p ~/.config/micro/syntax && wget -O ~/.config/micro/syntax/shell.yaml https://raw.githubusercontent.com/ushst/my-zsh/main/.config/micro/syntax/shell.yaml`

Или через установщик: он спросит, ставить ли micro-конфиг.
Можно без вопросов:
`MY_ZSH_INSTALL_MICRO=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/install.sh)"`


# NANO
`sudo wget -O ~/.nanorc https://raw.githubusercontent.com/ushst/my-zsh/main/.nanorc`

# MSFCONSOLE
`mkdir -p ~/.msf4 && wget -O ~/.msf4/msfconsole.rc https://raw.githubusercontent.com/ushst/my-zsh/main/msfconsole.rc`

Или через установщик: он спросит, ставить ли msfconsole-конфиг.
Можно без вопросов:
`MY_ZSH_INSTALL_MSFCONSOLE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/install.sh)"`
