# Evolve IT Remote — the branded client fork

This is `rustdesk/rustdesk` at **1.4.9** (the version verified end-to-end
against the Evolve IT RMM — see `docs/rustdesk.md` in the `evolve-it-rmm`
repo) plus exactly two additions, both under our control and both tiny on
purpose so upstream rebases stay routine:

- `res/evolve/brand.sh` — patches the default rendezvous server and public
  key in `libs/hbb_common/src/config.rs` at build time. The values come from
  repository **Variables** (`EVOLVE_RD_HOST`, `EVOLVE_RD_KEY`); they are not
  secrets — every shipped client carries them.
- `.github/workflows/evolve-build.yml` — upstream's own build jobs, copied
  verbatim and trimmed to what Evolve IT deploys (Windows x64, macOS arm64 +
  x86_64), with the brand step inserted after each checkout. Trigger it
  manually from the Actions tab (`workflow_dispatch`).

## Getting builds

1. Push this repo to GitHub (**public** — GPLv3 obliges publishing the fork
   once binaries are distributed to client machines).
2. Settings → Secrets and variables → Actions → **Variables**: add
   `EVOLVE_RD_HOST` (the address endpoints reach the server at) and
   `EVOLVE_RD_KEY` (`deploy/rustdesk/data/id_ed25519.pub` on the server).
3. Actions → *Build Evolve IT Remote* → Run workflow. Unsigned artifacts land
   on the run (and a prerelease tagged `evolve`); signing activates by adding
   upstream's usual secrets (`MACOS_P12_BASE64`, `MACOS_P12_PASSWORD`,
   `MACOS_NOTARIZE_JSON`) once certificates exist.

The result: install once on a technician machine and it talks to our server
with zero manual network setup; the `rustdesk://` deep links from the RMM
device page work as-is.

## Deliberately NOT done yet: renaming

The app still calls itself RustDesk. A full rename (name, bundle ids, icons,
`com.carriez.*` paths) cascades into the RMM's provisioning script — which
writes `RustDesk2.toml` under the *stock* paths — and into the deep-link
scheme the portal generates. Rename endpoint + viewer + provisioning together
in one coordinated change, or not at all. Display-level branding (window
title, icon) is the sane first step when we get there, and it needs actual
design assets first.

## Rebasing on a new upstream release

```sh
git fetch upstream --tags
git merge <new-tag>        # brand.sh + evolve-build.yml rarely conflict
```

Then re-check three things against the new `flutter-build.yml`: the env block,
the job bodies (re-copy, re-trim, re-insert the brand steps — the workflow
header comment describes the exact edits), and that `config.rs` still declares
`RENDEZVOUS_SERVERS` / `RS_PUB_KEY` the way `brand.sh` expects — its greps
fail the build if not.
