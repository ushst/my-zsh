# MY-ZSH

Автоматически обновляемая и оптимизированная конфигурация ZSH.

Установка:
`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/install.sh)"`

Для Termux:
`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ushst/my-zsh/main/termux_zsh.sh)"`

## Быстрые команды
- **`mkcd <папка>`** / **`take`** — создать папку и сразу перейти в нее.
- **`gclone <author/repo или url>`** / **`gclcd`** — клонировать git-репозиторий и сразу перейти в него.
- **`zsh-faq`** / **`myzsh-faq`** — посмотреть справку по встроенным командам прямо в оболочке.
- Полная справка: см. [FAQ.md](FAQ.md).

## Как хранить свои изменения
- `~/.zshrc` (или `$ZDOTDIR/.zshrc`) — стабильный входной загрузчик; автообновление его не перезаписывает.
- Логика загрузки обновляется отдельно в `~/.config/my-zsh/loader.managed.zsh`.
- Основная конфигурация обновляется в `~/.config/my-zsh/zshrc.managed`. Учитываются `XDG_CONFIG_HOME` и `XDG_STATE_HOME`.
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

## Обновление старой установки

Старый автообновлятор сначала получит новый `zshrc.managed`. При следующем
интерактивном запуске он в фоне обновит старый загрузчик, сохранив личные
дополнения после конечного маркера на прежнем месте. Резервная копия находится в
`~/.local/state/my-zsh/loader-migration.*/zshrc.backup` (учитывается `XDG_STATE_HOME`).
При ошибке загрузки или синтаксиса исходный `.zshrc` сохраняется. Изменения,
сделанные во время скачивания, не перезаписываются. Затем обновления загрузчика
будут поступать в отдельный `loader.managed.zsh`. Повторная установка не нужна.

Можно обновиться и вручную повторным запуском установщика. Он сохраняет копии
в `~/.local/state/my-zsh/install-backup.*`, а дополнения после конечного маркера
переносит в `~/.zshrc.d/zz-legacy.*.zsh`. Для обычного `.zshrc` сохраняется и
подключается весь прежний конфиг. Неизвестный загрузчик без конечного маркера
не заменяется автоматически: потребуется ручной перенос.

Автообновление проверяет непустое содержимое и синтаксис обоих конфигов,
сохраняет резервные копии и при ошибке замены восстанавливает предыдущие файлы.
Версия записывается только после успешной замены. После сетевой ошибки следующая
проверка разрешена через 5 минут при открытии нового shell; фоновых таймеров нет.
Новый конфиг применяется при следующем запуске оболочки.

`gclone <url-или-путь> [каталог] [опции git clone...]` поддерживает локальные
репозитории и опции с аргументами, например `gclone URL --depth 1`.
Для GitHub можно указать `gclone author/repo-name`: это сокращение для
`https://github.com/author/repo-name.git`. Существующий локальный путь имеет
приоритет; для явного локального пути используй `./author/repo-name`.
При установленном NVM сокращение `npm s` всегда означает `npm start`.

## Проверки

Требуются Python 3, Bash, Zsh и Git. Тесты работают без сети во временных каталогах:

```sh
python3 -m unittest discover -s tests -v
zsh -n .zshrc
zsh -n zshrc.managed
bash -n install.sh
bash -n termux_zsh.sh
```
