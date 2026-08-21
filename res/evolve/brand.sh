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
