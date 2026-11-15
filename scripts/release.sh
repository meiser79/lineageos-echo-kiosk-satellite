#!/usr/bin/env bash
# Turn a device's newest build into a GitHub release in the form the Echos'
# system updates look for: tagged <device>-<release>, titled
# "<device name> <release>", with lineageos-echo-kiosk-satellite-<release>-<device>.zip,
# its .sig and its .sha256. See docs/releasing.md.
#
#   DEVICE=rook scripts/release.sh       or   make release DEVICE=rook
#
# The release is the one the device's changelog names on top, and the
# commit it points at is HEAD, which must be clean, on GitHub and no newer
# than the build. The release stays a draft, which no Echo installs, unless
# PUBLISH=1. NOTES=<file> replaces the notes made from the changelog.
# GH_REPO=<owner>/<repo> releases somewhere other than origin's repository.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_DIR="$(realpath "${ECHO_WORKSPACE:-$REPO_ROOT/workspace}")"
TREE="$(realpath "${LINEAGE_TREE:-$WORKSPACE_DIR/lineage-18.1}")"
DEVICE="${DEVICE:-}"
OUT="$TREE/out/target/product/$DEVICE"

die() { echo "ERROR: $*" >&2; exit 1; }

case "$DEVICE" in
  athena|biscuit|checkers|cronos|crown|donut|rook) ;;
  *) die "set DEVICE to athena, biscuit, checkers, cronos, crown, donut or rook" ;;
esac
for tool in gh git openssl sha256sum unzip; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done
gh auth status >/dev/null 2>&1 || die "gh is not logged in (gh auth login)"

CHANGELOG="$REPO_ROOT/CHANGELOG-$DEVICE.md"
NAME="$(bash -c "$(sed -n '/^device_name()/,/^}/p' "$REPO_ROOT/scripts/build.sh"); device_name $DEVICE")"
[[ -n "$NAME" ]] || die "scripts/build.sh has no device_name for $DEVICE"

# The top heading of the changelog is the release, such as
# "## 2026.11.2 - 2026-11-15". An Unreleased one means it is not named yet.
TOP="$(grep -m1 '^## ' "$CHANGELOG" | cut -c4-)"
RELEASE="${TOP%% *}"
[[ "$TOP" != Unreleased ]] || die "rename '## Unreleased' in CHANGELOG-$DEVICE.md to the release, commit and build again"
[[ "$RELEASE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "CHANGELOG-$DEVICE.md starts with '## $TOP', not a release"
TAG="$DEVICE-$RELEASE"

# The tag points at HEAD, so HEAD must be what was built and be on GitHub.
GH_REPO="${GH_REPO:-$(git -C "$REPO_ROOT" remote get-url origin |
  sed -E 's#^(git@github\.com:|ssh://git@github\.com/|https://github\.com/)##; s#\.git$##')}"
[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] || die "the checkout has uncommitted changes"
HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
gh api "repos/$GH_REPO/commits/$HEAD_SHA" --silent 2>/dev/null ||
  die "$GH_REPO does not have HEAD ${HEAD_SHA:0:10} yet: push first"
if gh release view "$TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
  die "$GH_REPO already has a release $TAG"
fi

BUILT="$(ls -t "$OUT"/lineage-18.1-*-"$DEVICE".zip 2>/dev/null | head -n 1)"
[[ -f "$BUILT" ]] || die "no build of $DEVICE in $OUT: run CLEAN=1 make $DEVICE"
(( $(stat -c %Y "$BUILT") >= $(git -C "$REPO_ROOT" log -1 --format=%ct HEAD) )) ||
  die "$(basename "$BUILT") is older than HEAD: run CLEAN=1 make $DEVICE again"

# check-image.sh also fails when the image reports another release than
# the changelog's.
DEVICE="$DEVICE" "$REPO_ROOT/scripts/check-image.sh" "" "$BUILT" ||
  die "the image failed its checks"

DIST="$WORKSPACE_DIR/releases/$TAG"
FILE="lineageos-echo-kiosk-satellite-$RELEASE-$DEVICE.zip"
rm -rf "$DIST"
mkdir -p "$DIST"
cp "$BUILT" "$DIST/$FILE"
"$REPO_ROOT/scripts/sign-release.sh" "$DIST/$FILE"
(cd "$DIST" && sha256sum "$FILE" >"$FILE.sha256")
SHA256="$(cut -d' ' -f1 "$DIST/$FILE.sha256")"

if [[ -n "${NOTES:-}" ]]; then
  [[ -s "$NOTES" ]] || die "NOTES=$NOTES is empty or missing"
  cp "$NOTES" "$DIST/notes.md"
else
  # The release's section of the changelog, then what to download.
  {
    echo "## LineageOS for the $NAME, Kiosk Satellite Edition $RELEASE"
    echo
    awk 'n == 1 && /^## / { exit } /^## / { n++; next } n == 1 && (NF || body) { body = 1; print }' "$CHANGELOG"
    echo "### Download"
    echo
    echo "\`$FILE\`, build \`${HEAD_SHA:0:10}\`."
    echo
    echo "SHA-256: \`$SHA256\`"
    echo
    echo "\`$FILE.sig\` is the release signature, which the device checks before it installs an update. $NAME releases are tagged \`$DEVICE-\`."
  } >"$DIST/notes.md"
fi

DRAFT=(--draft)
[[ "${PUBLISH:-0}" == 1 ]] && DRAFT=()
gh release create "$TAG" "$DIST/$FILE" "$DIST/$FILE.sig" "$DIST/$FILE.sha256" \
  --repo "$GH_REPO" --target "$HEAD_SHA" --title "$NAME $RELEASE" \
  --notes-file "$DIST/notes.md" "${DRAFT[@]}"

if (( ${#DRAFT[@]} )); then
  echo "Created $TAG on $GH_REPO as a draft. Publish it with:"
  echo "  gh release edit $TAG --repo $GH_REPO --draft=false"
else
  echo "Published $TAG on $GH_REPO."
fi
