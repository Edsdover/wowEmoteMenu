# Tests

Loads the addon into a real Lua 5.1 interpreter against a stubbed WoW API and
exercises the paths a player actually hits. No game client involved, so it runs
in seconds and catches regressions the moment they are written.

This matters more than usual here: the WoW: Forever beta does not restore
SavedVariables at all, so persistence cannot currently be verified in game. The
save and load logic is verified here instead.

## Running

    python -m pip install lupa
    python tests/run_tests.py

Exit status is non-zero if any check fails.

## Layout

- `wowstub.lua` — the fake WoW API: frames, textures, tooltips, scroll frames,
  sliders, events and slash commands. Unknown widget methods become recorded
  no-ops so embedded libraries load, while everything the addon itself depends
  on is implemented properly. Frame sizes derive from TOPLEFT/BOTTOMRIGHT
  anchors the way the real client does, which the scrolling layout relies on.
- `run_tests.py` — the checks themselves.

## What is covered

- Loads cleanly; no globals leak
- Every emote button clicks and tooltips without error, and calls DoEmote with
  the right token and target
- Buttons are built lazily on first show, and not rebuilt on reopen
- Reflow: column count against viewport width, live resize from 10 to 4 to 13
  columns, scrollbar appearing and hiding, all buttons still positioned
- Panel position and size survive drag, grip release and logout
- Upgrading from the old SavedVariables layout, including a hidden minimap icon
- Corrupt saved variables fall back to defaults without breaking the panel
- Opening the panel before ADDON_LOADED does not error

Expectations are derived from the data where possible rather than hardcoded --
for example the count of emotes with no targeted form is read from the store
file, so correcting an emote's text cannot produce a phantom failure.
