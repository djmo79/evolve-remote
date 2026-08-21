#!/bin/sh
# Bakes the Evolve IT server into the client before the build.
#
# RustDesk 1.4.x keeps its default rendezvous server and public key as plain
# consts in libs/hbb_common/src/config.rs (no build-time env hook in OSS), and
# hbb_common is a submodule — so rather than forking the submodule too, the CI
# patches the two consts after checkout. The diff against upstream stays close
# to zero, which is what keeps rebasing onto new releases routine.
#
# EVOLVE_RD_HOST / EVOLVE_RD_KEY come from repository Variables (they are not
# secrets: every shipped client carries them, and the key is the server's
# PUBLIC key — see deploy/rustdesk in the evolve-it-rmm repo for the pair).
#
# perl rather than sed: -i behaves differently between BSD and GNU sed (this
# runs on both macOS and windows/git-bash runners), and the key is base64,
# whose / and + would fight sed's delimiters. $ENV{} interpolation sidesteps
# escaping entirely.
set -eu

: "${EVOLVE_RD_HOST:?EVOLVE_RD_HOST is not set - add it under Settings / Secrets and variables / Actions / Variables}"
: "${EVOLVE_RD_KEY:?EVOLVE_RD_KEY is not set - add it under Settings / Secrets and variables / Actions / Variables}"

CFG=libs/hbb_common/src/config.rs

perl -pi -e 's{^pub const RENDEZVOUS_SERVERS: .*$}{pub const RENDEZVOUS_SERVERS: &[&str] = &["$ENV{EVOLVE_RD_HOST}"];}' "$CFG"
perl -pi -e 's{^pub const RS_PUB_KEY: .*$}{pub const RS_PUB_KEY: &str = "$ENV{EVOLVE_RD_KEY}";}' "$CFG"

# A patch that silently missed its target would ship clients pointed at the
# public RustDesk servers — fail the build instead.
grep -F "pub const RENDEZVOUS_SERVERS: &[&str] = &[\"$EVOLVE_RD_HOST\"];" "$CFG" >/dev/null
grep -F "pub const RS_PUB_KEY: &str = \"$EVOLVE_RD_KEY\";" "$CFG" >/dev/null
if grep -F "rs-ny.rustdesk.com" "$CFG" >/dev/null; then
  echo "public server still present in $CFG" >&2
  exit 1
fi

echo "Baked: rendezvous=$EVOLVE_RD_HOST key=$EVOLVE_RD_KEY"

# ---------------------------------------------------------------- rename
# The user-visible name. Changed here rather than by renaming PRODUCT_NAME,
# because PRODUCT_NAME feeds the built RustDesk.app filename that build.py and
# the CI packaging hardcode all over — chasing that rename into upstream code
# is exactly the rebase burden we are avoiding. Instead:
#   - APP_NAME (Rust) drives the window title, tray, About box and every
#     in-app "RustDesk" string.
#   - CFBundleName / CFBundleDisplayName drive the macOS menu bar and the Dock
#     / Finder label.
# The .app *file* is renamed once, in the CI packaging step, after the build.
#
# The rustdesk:// URL scheme must stay `rustdesk` on both sides — the RMM portal
# mints rustdesk://connection/new/<id> deep links and the endpoints run the
# stock client. But the scheme is NOT independent of the name: get_uri_prefix()
# derives it as "{app_name_lowercased}://", and core_main.rs checks an incoming
# URL against that prefix (and Windows registers it in the registry from it), so
# renaming APP_NAME alone would make the client answer to "evolve it remote://"
# and ignore the portal's links. The scheme is pinned back to rustdesk below.
APP_DISPLAY_NAME="Evolve IT Remote"

perl -pi -e 's{RwLock::new\("RustDesk"\.to_owned\(\)\)}{RwLock::new("'"$APP_DISPLAY_NAME"'".to_owned())}' "$CFG"
grep -F "RwLock::new(\"$APP_DISPLAY_NAME\".to_owned())" "$CFG" >/dev/null || {
  echo "APP_NAME rename missed its target in $CFG" >&2
  exit 1
}

# macOS bundle strings. CFBundleName is normally the $(PRODUCT_NAME) build
# variable; replacing it with a literal (and adding CFBundleDisplayName) renames
# the menu bar and Dock label while leaving PRODUCT_NAME — and thus the build
# paths — as RustDesk. Only runs on the macOS job, where the plist is present.
PLIST=flutter/macos/Runner/Info.plist
if [ -f "$PLIST" ]; then
  perl -0pi -e 's{<key>CFBundleName</key>\s*<string>\$\(PRODUCT_NAME\)</string>}{<key>CFBundleName</key>\n\t<string>'"$APP_DISPLAY_NAME"'</string>\n\t<key>CFBundleDisplayName</key>\n\t<string>'"$APP_DISPLAY_NAME"'</string>}' "$PLIST"
  grep -F "<string>$APP_DISPLAY_NAME</string>" "$PLIST" >/dev/null || {
    echo "CFBundleName rename missed its target in $PLIST" >&2
    exit 1
  }
fi

echo "Renamed app to: $APP_DISPLAY_NAME"

# Pin the URL scheme to rustdesk:// regardless of the display name, so the
# portal's deep links and the stock endpoints keep working. Without this the
# rename above silently repoints the scheme at "evolve it remote://".
COMMON=src/common.rs
perl -0pi -e 's{pub fn get_uri_prefix\(\) -> String \{\s*format!\("\{\}://", get_app_name\(\)\.to_lowercase\(\)\)\s*\}}{pub fn get_uri_prefix() -> String \{\n    "rustdesk://".to_owned()\n\}}' "$COMMON"
grep -F '"rustdesk://".to_owned()' "$COMMON" >/dev/null || {
  echo "URL scheme pin missed its target in $COMMON" >&2
  exit 1
}
echo "Pinned URL scheme: rustdesk://"
