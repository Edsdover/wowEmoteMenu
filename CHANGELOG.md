# Changelog

## 1.1.0

### Added

- **An options panel**, opened from the cog at the top right of the menu.
  - **Order.** The list runs A to Z across the rows, or A to Z down the
    columns.
  - **Button size.** Three sliders: width, height and text size. Wider buttons
    mean fewer columns in the same panel, and the grid reflows as the slider
    moves. Every slider's number is an edit box too, so a value can be typed
    straight in rather than hunted for with the mouse.
  - **Escape closes the menu**, which can now be turned off by anyone who wants
    to leave the menu parked on screen.
  - **Show the minimap icon.** This setting has existed since the first release
    with no way to reach it. There is now a tick box for it.
  - **Reset to defaults**, which puts the panel size, position and appearance
    back the way they shipped. Tabs and favourites are deliberately left alone.
- **A key binding.** Under `Emote Menu` in the game's own Key Bindings panel,
  so the menu no longer has to be reached through the minimap or a slash
  command.
- **Right-click the minimap icon for the options**, without opening the menu
  first. Left-click still opens the menu.
- **Filters for sound and animation.** Two toggles beside the search box,
  carrying the same speaker and dancer the buttons do. Turn one on to see only
  the emotes that have it, or both on for the emotes that have both. They reset
  when you log out, so a filter cannot quietly outlive the session that set it.
  While curating a tab both they and the search stop applying, since the whole
  point of that mode is that every emote is there to pick from.
- **Tabs can be renamed.** Press `Edit` and the tab's own name becomes a
  highlighted field with a pencil on it; type a new one and press Enter. `PvP` and `Raid` can be
  renamed as well as your own tabs, and a renamed tab keeps everything in it --
  names and contents were always stored separately, which is what makes this
  safe.

All of it is remembered between sessions, on clients that restore addon
settings -- see the note about the Forever beta below.

### Fixed

- **Two copies of the addon no longer throw an error on login.** Renaming the
  folder in 1.0.0 leaves the old one behind and WoW loads both. The second copy
  now says so in chat and stands down, instead of handing a nil to LibDBIcon.

## 1.0.0

First release since 2024, and a substantial one.

### Please read: your settings will reset once

The addon folder is now `EmoteMenu` instead of `wowEmoteMenu-main`. That old
name only existed because GitHub names its ZIP downloads after the branch, and
proper packaging makes it unnecessary.

WoW names a saved-settings file after the addon folder, so renaming resets panel
position, panel size and minimap icon position. That is the whole cost, and it
happens once. It is being done now rather than later precisely because this
release adds tabs -- doing it after people have curated favourites would throw
that work away instead.

Delete the old `wowEmoteMenu-main` folder after updating; it will not be removed
for you.

### Fixed

- **`/emote` no longer fights the game for the command.** `/emote` is Blizzard's
  own command for custom text emotes, and registering it here meant whichever
  loaded last won. The menu now answers to `/emotemenu` and `/emm`, and
  `/emote waves at the bartender` works again.
- **Renaming the addon folder no longer breaks it.** The load check compared
  against a hardcoded folder name, so any install that renamed the folder got no
  minimap icon and an error when opening the panel.
- **The panel no longer jumps when resized.** Dragging the corner saved the new
  size but not the new position, while the resize itself re-anchors the frame --
  so the panel moved on the next open.
- **Emote text corrected against a live client.** 36 entries were wrong.
  `toast` showed `congratulate`'s text entirely; `blame`, `gaze`, `pounce`,
  `groan`, `incoming`, `encourage` and `doubt` were all reworded; and `spit` no
  longer offers a targeted form on clients that do not have one. Four entries
  also had a stray tab indenting their tooltip.
- **20 emotes that ignore the target** now say so instead of quietly dropping it.

### Added

- **Tabs.** `All`, `Favourites`, `PvP` and `Raid`, plus any you make yourself.
  Press `Edit` to curate one: every emote appears and clicking adds or removes
  it rather than performing it, so a stray click cannot fire an emote at
  whoever you have targeted. Right-click any emote for `Add to` without
  entering edit mode. Tabs wrap onto extra rows on a narrow panel.
- **Search**, matching the emote name, its slash command, and the text the
  server prints -- so "sorry" finds `apologize` and "cheers" finds `drink`.
- **A resizable panel that scrolls.** Drag the bottom-right corner; the columns
  reflow and a scrollbar appears only when it is needed.
- **Animation and sound markers.** A speaker or a dancer on each button, from
  reviewing all 263 emotes in game one at a time.
- **7 emotes restored** that the previous release did not list: `huzzah`,
  `wince`, `quack`, `impressed`, `magnificent`, `lean` and `read`.
- **Emotes your client does not have are hidden**, so older versions show a
  shorter list rather than buttons that do nothing.

### Known issue: WoW: Forever beta

The Forever beta (1.60.1) writes addon settings correctly but never reads them
back, so everything resets on login. This affects every addon, not just this
one, and nothing an addon does can work around it. The panel says so when you
try to edit a tab, and stops saying it once the client is fixed.

Tracked at
<https://us.forums.blizzard.com/en/wow/t/savedvariables-never-load-in-the-beta-%E2%80%94-all-addon-settings-reset-on-login-69913/2354798>

### A note on other versions

The emote text was captured from a live WoW: Forever client by performing every
emote and recording the reply. Other versions may word a few differently. Where
they do, the tooltip is slightly wrong but the emote itself still works
correctly -- please report any you notice.
