#!/usr/bin/env bash
# Everything CI checks, through the ordaen CLI: build (generated TOCs, locales, load order checks), luacheck,
# forever-lint, busted. The specs load the addons from dist/, as the game does.
#
#   scripts/test.sh                 everything (ordaen check)
#   scripts/test.sh --filter Snap   build, then only busted (extra arguments go to busted)
#
# ordaen lives in the private wow-dev-tools repo (cli/). Install it there with `cargo install --path cli`, or build
# it (`cargo build --release -p ordaen`) and this script finds it in a sibling checkout.
# Lua 5.1, luacheck and busted: on PATH (Linux, CI), or in the WSL distro "Ubuntu" on Windows, which needs
#   apt-get install lua5.1 liblua5.1-0-dev luarocks build-essential
#   luarocks --lua-version=5.1 install busted && luarocks --lua-version=5.1 install luacheck
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ordaen="${ORDAEN:-}"
if [ -z "$ordaen" ]; then
	if command -v ordaen >/dev/null; then
		ordaen=ordaen
	else
		for candidate in "$root/../wow-dev-tools/target/release/ordaen" "$root/../wow-dev-tools/target/release/ordaen.exe"; do
			if [ -x "$candidate" ]; then
				ordaen="$candidate"
				break
			fi
		done
	fi
fi
if [ -z "$ordaen" ]; then
	echo "ordaen not found: install it from wow-dev-tools (cargo install --path cli) or set \$ORDAEN." >&2
	exit 2
fi

if [ $# -gt 0 ]; then
	exec "$ordaen" test --repo "$root" -- "$@"
fi
exec "$ordaen" check --repo "$root"
