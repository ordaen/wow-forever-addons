#!/usr/bin/env bash
# Import the in-game API dump into api/forever/<version>-<build>/ (see scripts/api_import.lua).
#
#   scripts/api-import.sh [path to SavedVariables/OrdaenCore_Debug.lua]
#
# In game first: Ordaen Dev window -> "Dump game API" (it reloads, which writes the file). The window is
# part of the dev-only addon OrdaenCore_Debug in the private wow-dev-tools repo.
# Afterwards click "Clear API dump" there; the dump is a few MB of SavedVariables.
# Runs in the ordaen CLI's own Lua (`ordaen lua`), or lua5.1 on PATH when ordaen isn't installed (needs lfs).
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

if command -v ordaen >/dev/null; then
	# Windows: ordaen's own Lua 5.1 (Git Bash paths like /c/... become C:/... for it)
	if command -v cygpath >/dev/null; then saved="$(cygpath -m "$saved")"; fi
	ordaen lua scripts/api_import.lua "$saved" . # in $root (cd above)
elif command -v lua5.1 >/dev/null || command -v lua >/dev/null; then
	lua="$(command -v lua5.1 || command -v lua)"
	"$lua" scripts/api_import.lua "$saved" "$root"
else
	echo "Neither ordaen nor Lua 5.1 found (install the ordaen CLI from wow-dev-tools)." >&2
	exit 1
fi
