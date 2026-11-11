#!/usr/bin/env bash
# Everything that checks the addons: the lunatype suite (../lunatype), which checks, formats, builds and runs every
# addon here against its snapshots. -j16 keeps the build from taking the whole machine.
#
#   scripts/test.sh             everything
#   scripts/test.sh -Dupdate    everything, writing the snapshots anew
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root/../lunatype"
exec zig build test -j16 -Daddons="$root/addons" "$@"
