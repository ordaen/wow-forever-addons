#!/usr/bin/env bash
# Run the same Lua checks as CI: luacheck, forever-lint (scripts/forever_lint.lua), busted.
#
#   scripts/test.sh                 everything
#   scripts/test.sh --filter Snap   extra arguments go to busted
#
# Linux / CI: needs Lua 5.1 with luacheck and busted on PATH.
# Windows (Git Bash): runs luacheck and busted inside the WSL "Ubuntu" distro, which needs
#   apt-get install lua5.1 liblua5.1-0-dev luarocks build-essential
#   luarocks --lua-version=5.1 install busted && luarocks --lua-version=5.1 install luacheck
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if command -v luacheck >/dev/null && command -v busted >/dev/null; then
	luacheck .
	"$(command -v lua5.1 || command -v lua)" scripts/forever_lint.lua
	busted "$@"
elif command -v wsl.exe >/dev/null && command -v cygpath >/dev/null; then
	# Git Bash path /c/Users/... -> WSL path /mnt/c/Users/...
	wsl_root="/mnt$(cygpath -u "$root")"
	MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu --exec bash -c 'cd "$1" && shift && luacheck . && lua5.1 scripts/forever_lint.lua && busted "$@"' _ "$wsl_root" "$@"
else
	echo "luacheck/busted not found, and no WSL to run them in. See the comment at the top of $0." >&2
	exit 1
fi
