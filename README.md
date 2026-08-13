# MY-ZSH

Автоматически обновляемая и оптимизированная конфигурация ZSH.

Установка:
`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/install.sh)"`

Для Termux:
`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/termux_zsh.sh)"`

## Быстрые команды
- **`mkcd <папка>`** / **`take`** — создать папку и сразу перейти в нее.
- **`gclone <url>`** / **`gclcd`** — клонировать git-репозиторий и сразу перейти в него.
- **`zsh-faq`** / **`myzsh-faq`** — посмотреть справку по встроенным командам прямо в оболочке.
- Полная справка: см. [FAQ.md](FAQ.md).

## Как хранить свои изменения
- `~/.zshrc` — загрузчик + фоновое автообновление.
- Основная конфигурация обновляется в `~/.config/my-zsh/zshrc.managed`.
- Твои личные настройки добавляй в `~/.zshrc.local` или в `~/.zshrc.d/*.zsh` (они не перезаписываются).

## Отключить автообновление
Добавь в `~/.zshrc.local`:
`export MY_ZSH_AUTOUPDATE=0`

# MICRO
Конфиг micro лежит в репо: `.microrc` и `.config/micro/syntax/shell.yaml`.

Установить вручную:
`wget -O ~/.microrc https://raw.githubusercontent.com/ushst/my-zsh/main/.microrc`
`mkdir -p ~/.config/micro/syntax && wget -O ~/.config/micro/syntax/shell.yaml https://raw.githubusercontent.com/ushst/my-zsh/main/.config/micro/syntax/shell.yaml`

# NANO
`sudo wget -O ~/.nanorc https://raw.githubusercontent.com/ushst/my-zsh/main/.nanorc`

# MSFCONSOLE
`mkdir -p ~/.msf4 && wget -O ~/.msf4/msfconsole.rc https://raw.githubusercontent.com/ushst/my-zsh/main/msfconsole.rc`
