#!@bash@/bin/bash
set -euo pipefail

PATH=@path@

if [[ $# -gt 1 ]]; then
    cat >&2 <<EOF

USAGE: nix run .#deploy [-- <github_release_tag>]

Builds bootstrap zip ball and source code tar ball (for usage as a channel or
flake) and uploads them to a GitHub release.

If no tag is given, one is generated from the current date and time
(e.g. 2026-05-27-143022). The GitHub repo is detected from 'git remote'.

Examples:
$ nix run .#deploy                   # auto tag, auto repo
$ nix run .#deploy -- '2026-05-27'   # custom tag, auto repo

EOF
    exit 1
fi

# this allows to run this script from every place in this git repo
REPO_DIR="$(git rev-parse --show-toplevel)"
cd "$REPO_DIR"

RELEASE_TAG="${1:-$(date +%Y-%m-%d-%H%M%S)}"

# detect GitHub repo from git remote (supports both https and ssh remotes)
REMOTE_URL="$(git remote get-url origin)"
if [[ "$REMOTE_URL" =~ github\.com[:/](.+/.+?)(\.git)?$ ]]; then
    GITHUB_REPO="${BASH_REMATCH[1]%.git}"
else
    echo "Could not detect GitHub repo from remote: $REMOTE_URL" >&2
    exit 1
fi

PUBLIC_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}"
: ${ARCHES:=aarch64 x86_64}

SOURCE_FILE="source.tar.gz"

function log() {
    echo "> $*"
}


if [[ "$PUBLIC_URL" =~ ^github:(.*)/(.*)/(.*) ]]; then
    export NIX_ON_DROID_CHANNEL_URL="https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/archive/${BASH_REMATCH[3]}.tar.gz"
else
    [[ "$PUBLIC_URL" =~ ^https?:// ]] || \
    [[ "$PUBLIC_URL" =~ ^file:/// ]] || \
        { echo "unsupported url $PUBLIC_URL" >&2; exit 1; }
    export NIX_ON_DROID_CHANNEL_URL="$PUBLIC_URL"
fi
# special case for local / CI testing
if [[ "$PUBLIC_URL" =~ ^file:///(.*)/archive.tar.gz ]]; then
    export NIX_ON_DROID_FLAKE_URL="/${BASH_REMATCH[1]}/unpacked"
else
    export NIX_ON_DROID_FLAKE_URL="$PUBLIC_URL/$SOURCE_FILE"
fi
log "NIX_ON_DROID_CHANNEL_URL=$NIX_ON_DROID_CHANNEL_URL"
log "NIX_ON_DROID_FLAKE_URL=$NIX_ON_DROID_FLAKE_URL"


UPLOADS=()
for arch in $ARCHES; do
    log "building $arch bootstrapZip..."
    BOOTSTRAP_ZIP="$(nix build --no-link --print-out-paths --impure ".#bootstrapZip-${arch}")"
    UPLOADS+=($BOOTSTRAP_ZIP/bootstrap-$arch.zip)
done


log "creating tar ball of current HEAD..."
git archive --prefix nix-on-droid/ --output "$SOURCE_FILE" HEAD
UPLOADS+=($SOURCE_FILE)


log "uploading artifacts..."
if gh release view "$RELEASE_TAG" &>/dev/null; then
    gh release upload "$RELEASE_TAG" "${UPLOADS[@]}" --clobber
else
    gh release create "$RELEASE_TAG" "${UPLOADS[@]}" --title "$RELEASE_TAG" --notes ""
fi
