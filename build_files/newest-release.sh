#!/usr/bin/env bash
# Prints the newest release tag of a GitHub repository (owner/name), or nothing if it has no release
# yet; fails if GitHub can't be asked. Used by build.sh and the workflows.
#
# It reads where the newest release's downloads redirect to (.../releases/download/<tag>/<file>)
# rather than the API (rate-limited) or the release pages (blocked from some build sandboxes).
set -euo pipefail
out=$(curl -sS --retry 5 -o /dev/null -w '%{http_code} %{redirect_url}' \
    "https://github.com/$1/releases/latest/download/SHA256SUMS")
code=${out%% *} url=${out#* }
case $code in
    302) basename "$(dirname "$url")" ;;
    404) ;; # no release yet
    *) echo "Couldn't look up $1's newest release (HTTP $code)" >&2; exit 1 ;;
esac
