# Tools

Throwaway addons and scripts used to produce and verify the addon's data. None
of this ships: `sync.ps1` excludes `tools/`, so it never reaches the AddOns
folder, and nothing here is listed in the .toc.

Both addons are standalone. To use one, copy its folder into
`Interface/AddOns/` and reload.

## EmoteCapture

Performs every emote the client declares in `EMOTE*_TOKEN`, with and without a
target, and records exactly what the server prints back. This is how
`wowEmoteMenuStore.lua` is generated.

Worth keeping because the data will need rebuilding: the emote list and its
wording differ between builds. Forever reworded several emotes and made others
ignore their target, so data taken from retail does not match.

    /emotecapture start     -- target something first
    /emotecapture stop
    /emotecapture status

Then log out or `/reload` so the file is written, and:

    python tools/EmoteCapture/build_store.py \
        ".../WTF/Account/<acct>/SavedVariables/EmoteCapture.lua"

Things learned the hard way, all handled in the code:

- **The server rate-limits emotes.** At 0.4s spacing a long run loses a
  contiguous block of replies; 2.5s is safe. A first attempt also mistook the
  rate limit for emotes that do not exist.
- **Do not time out a reply after one step.** An earlier version discarded any
  reply that arrived slightly late and counted it as silence, which wrongly
  marked `wave`, `welcome` and `whistle` as textless while they printed fine in
  chat.
- **The client's token list is not the server's.** `fail`, `goodluck`, `moan`,
  `serious`, `shake`, `stink`, `stopattack` and `toast` are absent from
  `EMOTE*_TOKEN` yet the server performs them, so a capture never sees them.
  `build_store.py` carries them over from the existing store; do not let a
  capture delete them.
- **Silence is ambiguous.** It can mean the emote prints nothing but still acts
  (`sit`, `stand`, `train`), or that it is not implemented at all. Only testing
  in game tells them apart, hence the hand-maintained lists in
  `build_store.py`.
- **SavedVariables are written but never restored on the Forever beta**, so the
  tool cannot read back its own earlier output. `Captured.lua` exists to carry
  results across a reload, because addon files do load normally.

## SVRepro

Two-file reproduction for the beta bug where SavedVariables are written
correctly but never read back. Prints a login counter that should increase every
login and stays at 1 while the bug is present.

Kept as a canary: when it finally counts past 1, the client is fixed and the
addon's own settings will start persisting again.

Reported at
<https://us.forums.blizzard.com/en/wow/t/savedvariables-never-load-in-the-beta-%E2%80%94-all-addon-settings-reset-on-login-69913/2354798>
