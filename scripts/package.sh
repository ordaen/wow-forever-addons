#!/usr/bin/env bash
# Package one addon with the BigWigs packager, from its release build (`ordaen build --profile release`).
#
#   scripts/package.sh <AddonName> [<tag>]
#
# The packager only works on the root of a git checkout (it looks for "$topdir/.git"),
# so in this monorepo we copy the addon into a throwaway git repo first. With a tag
# (e.g. OrdaenMinimap-v1.2.0) the build is a "release" and uploads to CurseForge /
# Wago when CF_API_KEY / WAGO_API_TOKEN are set and the TOC has the project IDs.
# Without a tag it is an alpha build and nothing is uploaded.
#
# Output: .release/<AddonName>-<version>.zip
# Works in CI (ubuntu) and locally in Git Bash (needs curl; jq only for uploads).
set -euo pipefail

PACKAGER_VERSION="v2.7.0"

addon="${1:?usage: scripts/package.sh <AddonName> [<tag>]}"
tag="${2:-}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$root/addons/$addon/addon.jsonc" ] || { echo "No addon at $root/addons/$addon" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The zip holds the release build: generated TOC/.pkgmeta/locales, Debug calls stripped, dev files left out.
# ordaen is the private build tool (wow-dev-tools); CI downloads a pinned release, locally it is on PATH or $ORDAEN.
"${ORDAEN:-ordaen}" build --repo "$root" --profile release --out "$work/dist" "$addon"
src="$work/dist/$addon"

packager="$work/release.sh"
curl -fsSL -o "$packager" "https://raw.githubusercontent.com/BigWigsMods/packager/$PACKAGER_VERSION/release.sh"

repo="$work/$addon"
mkdir -p "$repo"
cp -a "$src/." "$repo/"
(
	cd "$repo"
	git init -q -b main
	git add -A
	git -c user.name=packager -c user.email=packager@localhost -c commit.gpgsign=false \
		commit -qm "${tag:-snapshot}"
	if [ -n "$tag" ]; then git -c tag.gpgsign=false tag "$tag"; fi
)

args=(-t "$repo" -r "$root/.release")
if [ -n "$tag" ]; then
	version="${tag##*-v}" # OrdaenMinimap-v1.2.0 -> 1.2.0
	args+=(-n "{package-name}-$version:$version")
else
	args+=(-d) # snapshot: never upload
fi

if ! command -v zip >/dev/null; then
	echo "zip not found (normal in Git Bash): building the folder only, no zip/upload." >&2
	args+=(-z -d)
fi

# Unset GitHub ref vars so the packager doesn't try to match the monorepo's ref inside the temp repo.
env -u GITHUB_REF -u GITHUB_REF_NAME bash "$packager" "${args[@]}"
