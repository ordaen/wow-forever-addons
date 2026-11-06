#!/usr/bin/env bash
# Import the in-game API dump into api/forever/<version>-<build>/ (see scripts/api_import.lua).
#
#   scripts/api-import.sh [path to SavedVariables/OrdaenCore_Debug.lua]
#
# In game first: Ordaen Dev window -> "Dump game API" (it reloads, which writes the file). The window is
# part of the dev-only addon OrdaenCore_Debug in the private wow-dev-tools repo.
# Afterwards click "Clear API dump" there; the dump is a few MB of SavedVariables.
# Linux / CI: needs lua5.1 (or lua) on PATH. Windows (Git Bash): runs it in the WSL "Ubuntu" distro.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

saved="${1:-}"
if [ -z "$saved" ]; then
	# Newest OrdaenCore_Debug.lua across WoW accounts.
	saved="$(ls -t "/c/Program Files (x86)/World of Warcraft/_forever_/WTF/Account/"*/SavedVariables/OrdaenCore_Debug.lua 2>/dev/null | head -1 || true)"
fi
if [ -z "$saved" ] || [ ! -f "$saved" ]; then
	echo "OrdaenCore_Debug.lua not found; pass its path as the first argument." >&2
	exit 1
fi

if command -v lua5.1 >/dev/null || command -v lua >/dev/null; then
	lua="$(command -v lua5.1 || command -v lua)"
	"$lua" scripts/api_import.lua "$saved" "$root"
elif command -v wsl.exe >/dev/null && command -v cygpath >/dev/null; then
	wsl_root="/mnt$(cygpath -u "$root")"
	wsl_saved="/mnt$(cygpath -u "$saved")"
	MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu --exec bash -c \
		'cd "$1" && lua=$(command -v lua5.1 || command -v lua) && "$lua" scripts/api_import.lua "$2" "$1"' \
		_ "$wsl_root" "$wsl_saved"
else
	echo "No Lua found, and no WSL to run it in." >&2
	exit 1
fi
