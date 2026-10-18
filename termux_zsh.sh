#!/bin/bash
# Works both from a checkout and through bash -c.
set -e
if [[ -f "${BASH_SOURCE[0]}" && -f "$(dirname "${BASH_SOURCE[0]}")/install.sh" ]]; then
  exec bash "$(dirname "${BASH_SOURCE[0]}")/install.sh" "$@"
fi
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
url="https://raw.githubusercontent.com/ushst/my-zsh/main/install.sh"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL --connect-timeout 5 --max-time 30 "$url" -o "$installer"
else
  wget -q --timeout=10 --tries=1 -O "$installer" "$url"
fi
[[ -s "$installer" ]]
bash -n "$installer"
bash "$installer" "$@"
