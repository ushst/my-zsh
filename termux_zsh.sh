#!/bin/bash
# Wrapper for unified install.sh
exec bash "$(dirname "$0")/install.sh" "$@"
