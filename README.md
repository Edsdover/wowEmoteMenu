## Emote Menu

### This simple addon creates a menu that lists all possible emotes in the game. A tooltip tells you what the emote text will be and a simple click will perform that emote.

### You can access the emote menu by clicking the minimap icon or by typing `/emotemenu` (short form: `/emm`)


### Have fun seeing and using all the emotes so rarely utilized!


![Emote Menu](docs/emote-menu.png)


### A note on other game versions

The emote text was captured from a live WoW: Forever client by performing every
emote and recording what the server replied. Other versions may word a few
differently; where they do the tooltip is slightly off but the emote itself
still works. Emotes your client does not have are hidden rather than shown as
buttons that do nothing.

### Known issues

**WoW: Forever beta (1.60.1, build 69913):** the client writes addon
SavedVariables correctly but never reads them back, so settings reset on every
login. This affects every addon, not just this one, and there is nothing an
addon can do about it. Tracked at
<https://us.forums.blizzard.com/en/wow/t/savedvariables-never-load-in-the-beta-%E2%80%94-all-addon-settings-reset-on-login-69913/2354798>.


### Tabs

**All** lists every emote. **Favourites** starts empty and is yours to fill.

**PvP** and **Raid** come with a starting set of emotes. Press **+** to make
your own tab, and any tab but All can be deleted -- the default ones can be
brought back by right-clicking **+**.

Press **Edit** on a tab to curate it: every emote appears, and clicking one
adds or removes it rather than performing it, so a stray click cannot fire an
emote at whoever you have targeted. Press **Done** when finished. You can also
right-click any emote at any time for *Add to Favourites*.

While editing, tick **Open this tab by default** to choose where the panel
starts each time you log in. During a session it reopens on whichever tab you
used last.

Search works inside the selected tab.

TODO:
1. Add options menu.
2. Add sort
3. Add dropdowns
4. Resizable window with scrolling when it is too small to show every emote
