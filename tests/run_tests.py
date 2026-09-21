"""Load the Emote Menu addon into a Lua 5.1 runtime against a stubbed WoW API
and exercise the paths a player actually hits."""
import sys, os
from lupa.lua51 import LuaRuntime

ADDON = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STUB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wowstub.lua")
ADDON_FOLDER = "wowEmoteMenu-main"

import re as _re
_STORE = open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "wowEmoteMenuStore.lua"), encoding="utf-8").read()
EMOTE_COUNT = len(_re.findall(r'^        emote = ', _STORE, _re.M))

failures = []
def check(label, cond, detail=""):
    if cond:
        print(f"  PASS  {label}")
    else:
        failures.append(label)
        print(f"  FAIL  {label}  {detail}")

def new_runtime(saved_vars_lua="nil"):
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(STUB, encoding="utf-8").read())
    L.execute(f"EmoteMenuDB = {saved_vars_lua}")
    # Load files in TOC order, each with the (addonName, core) vararg WoW passes.
    L.execute("__core = {}")
    files = [
        "Libs/LibStub/LibStub.lua",
        "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
        "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua",
        "Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua",
        "wowEmoteMenuStore.lua",
        "wowEmoteMenu.lua",
    ]
    loader = L.eval("""
        function(path, addonName, core)
            local f = assert(loadfile(path))
            return f(addonName, core)
        end
    """)
    for rel in files:
        if rel == "wowEmoteMenu.lua":
            # Real LibDBIcon loads fine (proven above) but needs real minimap
            # widgets to Register(). Swap in a recording stub so this test stays
            # focused on the addon's own integration with it.
            L.execute("""
                __dbicon = { registered = {}, shown = {}, hidden = {} }
                local fake = {
                    Register = function(self, name, obj, db)
                        assert(type(db) == "table", "LibDBIcon got a non-table db")
                        __dbicon.registered[name] = { obj = obj, db = db }
                    end,
                    Show = function(self, name) table.insert(__dbicon.shown, name) end,
                    Hide = function(self, name) table.insert(__dbicon.hidden, name) end,
                }
                LibStub.libs["LibDBIcon-1.0"] = fake
            """)
        loader(os.path.join(ADDON, rel).replace("\\", "/"), ADDON_FOLDER, L.globals()["__core"])
    return L


print("== 1. fresh install ==")
L = new_runtime("nil")
g = L.globals()
check("all files loaded without error", True)
check("no stray 'void' global", g["void"] is None, f"void={g['void']}")
check("no generic 'EmoteMenu' global", g["EmoteMenu"] is None, f"EmoteMenu={g['EmoteMenu']}")
check("no stray 'emoteTable' global", g["emoteTable"] is None)
check("frame named EmoteMenuFrame exists", g["EmoteMenuFrame"] is not None)
check("UISpecialFrames has EmoteMenuFrame",
      "EmoteMenuFrame" in list(L.eval("UISpecialFrames").values()))
check(f"emote data on core table ({EMOTE_COUNT})", L.eval("#__core.emoteTable") == EMOTE_COUNT,
      f"count={L.eval('#__core.emoteTable')}")

# Slash commands
slash = L.eval("SlashCmdList")
check("registered SlashCmdList['EMOTE_MENU']", slash["EMOTE_MENU"] is not None)
check("did NOT register /emote", g["SLASH_Emote_Menu1"] is None and
      L.eval('SLASH_EMOTE_MENU1') == "/emotemenu",
      f"SLASH_EMOTE_MENU1={L.eval('SLASH_EMOTE_MENU1')}")
check("second alias is /emm", L.eval("SLASH_EMOTE_MENU2") == "/emm")

# Buttons must not exist before first show
before = L.eval("#__frames")
emote_buttons = lambda: L.eval("""(function()
    local n = 0
    for _, f in ipairs(__frames) do if f.entry ~= nil then n = n + 1 end end
    return n
end)()""")
check("no emote buttons built before first show", emote_buttons() == 0,
      f"found {emote_buttons()}")

# Fire ADDON_LOADED with the real folder name
L.execute(f"""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
""")
check("minimap settings migrated into subtable", L.eval("type(EmoteMenuDB.minimap)") == "table")
check("default minimapPos applied", L.eval("EmoteMenuDB.minimap.minimapPos") == 204)
check("defaults written to DB", L.eval("EmoteMenuDB.MainPanelA") == "CENTER")
check("minimap icon registered with LibDBIcon",
      L.eval("__dbicon.registered['Emote_Menu'] ~= nil"))
check("LibDBIcon got the minimap subtable, not the DB root",
      L.eval("__dbicon.registered['Emote_Menu'].db == EmoteMenuDB.minimap"))
check("icon shown by default", L.eval("#__dbicon.shown") == 1)
check("LDB OnClick toggles the panel", L.eval("""(function()
    local obj = __dbicon.registered['Emote_Menu'].obj
    local before = EmoteMenuFrame:IsShown()
    obj.OnClick(obj, 'LeftButton')
    local after = EmoteMenuFrame:IsShown()
    obj.OnClick(obj, 'LeftButton')
    return before ~= after and EmoteMenuFrame:IsShown() == before
end)()""") is True)

# Open the menu
L.execute("SlashCmdList['EMOTE_MENU']('')")
check("panel is shown after slash command", L.eval("EmoteMenuFrame:IsShown()") is True)
after = L.eval("#__frames")
check("buttons built on first show", after - before >= EMOTE_COUNT, f"created={after - before}")

# Reopening must not duplicate buttons
L.execute("SlashCmdList['EMOTE_MENU']('')")
L.execute("SlashCmdList['EMOTE_MENU']('')")
check("panel hidden then shown again", L.eval("EmoteMenuFrame:IsShown()") is True)
check("buttons not rebuilt on reopen", L.eval("#__frames") == after,
      f"{L.eval('#__frames')} vs {after}")

print("\n== 2. every button clicks and tooltips ==")
L.execute("""
__clickErrors = {}
__tipErrors = {}
__buttonCount = 0
for _, f in ipairs(__frames) do
    if f.entry ~= nil then
        __buttonCount = __buttonCount + 1
        local ok, err = pcall(f.Click, f)
        if not ok then table.insert(__clickErrors, tostring(err)) end
        local ok2, err2 = pcall(f.Enter, f)
        if not ok2 then table.insert(__tipErrors, tostring(err2)) end
        pcall(f.Leave, f)
    end
end
""")
check("clicked every emote button", L.eval("__buttonCount") == EMOTE_COUNT, f"n={L.eval('__buttonCount')}")
check("no errors clicking buttons", L.eval("#__clickErrors") == 0,
      list(L.eval("__clickErrors").values())[:3])
check("no errors showing tooltips", L.eval("#__tipErrors") == 0,
      list(L.eval("__tipErrors").values())[:3])
check("DoEmote fired once per button", L.eval("#__emotes") == EMOTE_COUNT)
check("all DoEmote tokens are lowercase",
      L.eval("""(function()
          for _, e in ipairs(__emotes) do
              if e.token ~= string.lower(e.token) then return e.token end
          end
          return true
      end)()""") is True)
notarget = L.eval("""(function()
    local n = 0
    for _, e in ipairs(__emotes) do if e.target == "none" then n = n + 1 end end
    return n
end)()""")
# Derived from the data rather than hardcoded, so correcting an emote's
# targetText cannot silently break this assertion.
import re as _re
_store = open(os.path.join(ADDON, "wowEmoteMenuStore.lua"), encoding="utf-8").read()
_expected = len(_re.findall(r'targetText = ""', _store))
check(f"{_expected} emotes forced to no-target", notarget == _expected,
      f"n={notarget} expected={_expected}")

print("\n== 2b. resize reflows the grid ==")
core = L.globals()["__core"]
EM = core.EmoteMenu
F = L.globals()["EmoteMenuFrame"]
DEFAULT_W = EM.DEFAULT_WIDTH
DEFAULT_H = EM.DEFAULT_HEIGHT

# Pure layout arithmetic, independent of any frame.
BW = EM.BUTTON_WIDTH
INSET = EM.VIEWPORT_INSET
# Widths expressed in buttons, so changing BUTTON_WIDTH cannot invalidate these.
for viewport, count, want_cols in ((BW * 10, EMOTE_COUNT, 10), (BW * 3, EMOTE_COUNT, 3),
                                   (BW, EMOTE_COUNT, 1), (BW // 2, EMOTE_COUNT, 1),
                                   (BW * 20, EMOTE_COUNT, 20)):
    cols, rows = EM.ComputeGrid(viewport, count)
    import math as _m
    ok = cols == want_cols and rows == _m.ceil(count / want_cols)
    check(f"ComputeGrid({viewport}px) -> {want_cols} cols", ok, f"got {cols} cols / {rows} rows")

def grid_state():
    """Distinct x offsets across the buttons = the live column count."""
    return L.eval("""(function()
        local xs, n = {}, 0
        for _, f in ipairs(__frames) do
            if f.entry ~= nil and f.points and f.points.TOPLEFT then
                local x = f.points.TOPLEFT.x
                if xs[x] == nil then xs[x] = true; n = n + 1 end
            end
        end
        return n
    end)()""")

check("default size lays out 10 columns", grid_state() == 10, f"got {grid_state()}")

# Narrow the panel: fewer columns, more rows, scrollbar appears.
narrow_cols = 4
F.Resize(F, BW * narrow_cols + INSET, DEFAULT_H)
check(f"narrowing reflows to {narrow_cols} columns", grid_state() == narrow_cols,
      f"got {grid_state()}")

wide_cols = 13
F.Resize(F, BW * wide_cols + INSET, DEFAULT_H)
check(f"widening reflows to {wide_cols} columns", grid_state() == wide_cols,
      f"got {grid_state()}")

# Back to default.
F.Resize(F, DEFAULT_W, DEFAULT_H)
check("returns to 10 columns at default width", grid_state() == 10, f"got {grid_state()}")

def scrollbar_shown():
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.frameType == "Slider" then return f.shown == true end
        end
        return nil
    end)()""")

def scroll_max():
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.frameType == "Slider" then return f.maxVal or 0 end
        end
    end)()""")

check("no scrollbar when everything fits", scrollbar_shown() is False,
      f"shown={scrollbar_shown()} max={scroll_max()}")

F.Resize(F, DEFAULT_W, 300)
check("scrollbar appears when too short", scrollbar_shown() is True,
      f"shown={scrollbar_shown()} max={scroll_max()}")
check("scroll range is positive", scroll_max() > 0, f"max={scroll_max()}")

F.Resize(F, DEFAULT_W, DEFAULT_H)
check("scrollbar hides again when it fits", scrollbar_shown() is False,
      f"shown={scrollbar_shown()}")

# Every button must still be reachable after all that resizing.
placed = L.eval("""(function()
    local n = 0
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.points and f.points.TOPLEFT then
            n = n + 1
        end
    end
    return n
end)()""")
check(f"all {EMOTE_COUNT} buttons still positioned", placed == EMOTE_COUNT, f"placed={placed}")

check("buttons live in the scroll child, not the panel", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then
            return f.parent ~= EmoteMenuFrame and f.parent ~= nil
        end
    end
end)()""") is True)

check("panel is resizable with bounds set", L.eval(
    "EmoteMenuFrame.resizable == true and EmoteMenuFrame.resizeBounds ~= nil"))

print("\n== 2c. search filters the grid ==")

def box():
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.frameType == "EditBox" then return f end
        end
    end)()""")

SB = box()
check("a search box exists", SB is not None)
check("search box does not steal focus on open",
      SB.autoFocus is False, f"autoFocus={SB.autoFocus}")

def shown_buttons():
    return L.eval("""(function()
        local n = 0
        for _, f in ipairs(__frames) do
            if f.entry ~= nil and f.shown then n = n + 1 end
        end
        return n
    end)()""")

def count_label():
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.frameType == "Frame" and f.name == "EmoteMenuFrame" then end
        end
        return __core.EmoteMenu and "" or ""
    end)()""")

SB.Type(SB, "wave")
n = shown_buttons()
check("typing narrows the grid", 0 < n < EMOTE_COUNT, f"shown={n}")
check("matched button is the right one", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.shown and f.text == "wave" then return true end
    end
    return false
end)()""") is True)

SB.Type(SB, "")
check("clearing restores every button", shown_buttons() == EMOTE_COUNT, f"shown={shown_buttons()}")

# Matching the printed text is what makes the search worth having.
SB.Type(SB, "sorry")
check("matches the server text, not just the name", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.shown and f.text == "apologize" then return true end
    end
    return false
end)()""") is True)

SB.Type(SB, "/followme")
check("matches the slash command too", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.shown and f.text == "follow" then return true end
    end
    return false
end)()""") is True)

# A pattern character must not blow up a plain substring search.
ok = True
try:
    for junk in ("%", "-", "[", "%s", "((("):
        SB.Type(SB, junk)
except Exception as e:
    ok = False
check("pattern characters do not error", ok)

SB.Type(SB, "zzzznothing")
check("no matches hides every button", shown_buttons() == 0, f"shown={shown_buttons()}")
check("no-match message is shown", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.text == "No emotes match that search." then return f.shown end
    end
end)()""") is True)

# Escape clears the filter before it gives up focus, so it cannot close the panel
# out from under a search.
SB.Type(SB, "dance")
SB.Escape(SB)
check("escape clears the filter first", SB.GetText(SB) == "", repr(SB.GetText(SB)))
check("all buttons back after escape", shown_buttons() == EMOTE_COUNT)

# Filtering while narrow must still lay out correctly.
F.Resize(F, BW * 4 + INSET, 400)
SB.Type(SB, "wave")
placed_ok = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.shown then
            if not (f.points and f.points.TOPLEFT) then return false end
        end
    end
    return true
end)()""")
check("filtered buttons are positioned when narrow", placed_ok is True)
SB.Type(SB, "")
F.Resize(F, DEFAULT_W, DEFAULT_H)

print("\n== 2d. animation / sound markers ==")

# A marker is an OVERLAY texture parented to a button. Count them per button.
L.execute("""
__markers = {}
for _, f in ipairs(__frames) do
    if f.frameType == "Texture" and f.layer == "OVERLAY" and f.parent and f.parent.entry ~= nil then
        local name = f.parent.text
        __markers[name] = (__markers[name] or 0) + 1
    end
end
""")

def marks(token):
    return L.eval("""(__markers["%s"] or 0)""" % token)

store = {}
import re as _re2
for m in _re2.finditer(r'emote = "([^"]*)",\s*cmd = "[^"]*",\s*noTargetText = "[^"]*",\s*targetText = "[^"]*",\s*animated = (\w+),\s*voiced = (\w+)', _STORE):
    store[m.group(1)] = (m.group(2) == "true", m.group(3) == "true")

both = [t for t,(a,v) in store.items() if a and v]
anim = [t for t,(a,v) in store.items() if a and not v]
snd  = [t for t,(a,v) in store.items() if v and not a]
none = [t for t,(a,v) in store.items() if not a and not v]
print(f"  (store says: both={len(both)} anim={len(anim)} sound={len(snd)} neither={len(none)})")

# An icon marker is one texture; a bar marker is three. Derive it rather than
# hardcoding, so switching MARKER_STYLE does not fail the suite spuriously.
PER = 1 if EM.MARKER_STYLE == "icons" else 3
print(f"  (marker style: {EM.MARKER_STYLE}, {PER} texture(s) per marker)")
if both: check(f"both gets {PER*2} textures", marks(both[0]) == PER*2, f"{both[0]}={marks(both[0])}")
if anim: check(f"animation only gets {PER}", marks(anim[0]) == PER, f"{anim[0]}={marks(anim[0])}")
if snd:  check(f"sound only gets {PER}", marks(snd[0]) == PER, f"{snd[0]}={marks(snd[0])}")
if none: check("neither gets no markers", marks(none[0]) == 0, f"{none[0]}={marks(none[0])}")

mismatch = [t for t,(a,v) in store.items() if marks(t) != (PER if a else 0) + (PER if v else 0)]
check("every button matches its flags", not mismatch, f"{len(mismatch)} wrong: {mismatch[:5]}")

if EM.MARKER_STYLE == "icons":
    paths = L.eval("""(function()
        local t = {}
        for _, f in ipairs(__frames) do
            if f.frameType == "Texture" and f.texture then t[f.texture] = true end
        end
        local out = {}
        for k in pairs(t) do out[#out+1] = k end
        return table.concat(out, "|")
    end)()""").split("|")
    paths = [p for p in paths if p]
    check("marker textures reference the addon folder", all(ADDON_FOLDER in p for p in paths), paths[:2])
    import os as _os
    files = [_os.path.join(ADDON, "Textures", _os.path.basename(p.replace(chr(92), "/"))) for p in paths]
    check("marker texture files exist on disk", all(_os.path.isfile(f) for f in files),
          [f for f in files if not _os.path.isfile(f)])

# Markers must never overlap the label.
check("label is inset away from the markers", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then
            local fs = f.fontString
            if fs and fs.points and fs.points.RIGHT then
                return fs.points.RIGHT.x < 0
            end
        end
    end
end)()""") is True)

# The tooltip has to say what the markers mean.
if both:
    tip = L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.entry ~= nil and f.text == "%s" then return f.tiptext end
        end
    end)()""" % both[0])
    check("tooltip explains the markers", "animation and a sound" in (tip or ""), repr(tip)[-60:])

print("\n== 2e. tabs and edit mode ==")

def tab(label):
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.label and f.label.text == "%s" and f.id then return f end
        end
    end)()""" % label)

def edit_toggle():
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.template == "UIPanelButtonTemplate"
               and (f.text == "Edit" or f.text == "Done") then return f end
        end
    end)()""")

ALL, FAV = tab("All"), tab("Favourites")
check("All and Favourites tabs exist", ALL is not None and FAV is not None)
check("Edit button is hidden on All, not just disabled",
      edit_toggle().shown is False, f"shown={edit_toggle().shown}")
check("All tab shows every emote", shown_buttons() == EMOTE_COUNT, f"{shown_buttons()}")

FAV.Click(FAV)
check("Favourites starts empty", shown_buttons() == 0, f"{shown_buttons()}")
check("empty tab explains itself", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.text and f.text:find("This tab is empty") then return f.shown end
    end
end)()""") is True)
check("Edit button appears on a real tab", edit_toggle().shown is True,
      f"shown={edit_toggle().shown}")

# Entering edit mode reveals every emote so membership can be toggled.
ET = edit_toggle()
ET.Click(ET)
check("edit mode shows all emotes to pick from", shown_buttons() == EMOTE_COUNT,
      f"{shown_buttons()}")
check("edit toggle now reads Done", edit_toggle().text == "Done", edit_toggle().text)

# The whole point of the mode: a click curates and must NOT fire the emote.
before_emotes = L.eval("#__emotes")
wave = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.text == "wave" then return f end
    end
end)()""")
wave.Click(wave)
check("clicking in edit mode does not perform the emote",
      L.eval("#__emotes") == before_emotes,
      f"{L.eval(chr(35)+chr(95)+chr(95)+chr(101)+chr(109)+chr(111)+chr(116)+chr(101)+chr(115))} vs {before_emotes}")
check("emote added to the tab", L.eval('__core.EmoteMenu:TabContains("favourites", "wave")') is True)

wave.Click(wave)
check("clicking again removes it", L.eval('__core.EmoteMenu:TabContains("favourites", "wave")') is False)
wave.Click(wave)

# Leaving edit mode, the tab shows only its members.
ET = edit_toggle()
ET.Click(ET)
check("leaving edit mode filters to members", shown_buttons() == 1, f"{shown_buttons()}")
check("that member is wave", L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.shown then return f.text end
    end
end)()""") == "wave")

# Membership is written where it can be saved.
check("membership stored in the DB", L.eval('EmoteMenuDB.tabs.favourites.wave') is True)

# Right-click works without entering edit mode.
ALL.Click(ALL)
dance = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.text == "dance" then return f end
    end
end)()""")
before_emotes = L.eval("#__emotes")
dance.Click(dance, "RightButton")
check("right-click does not perform the emote", L.eval("#__emotes") == before_emotes)
row = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.label and f.label.text and f.label.text:find("Favourites")
           and f.label.text:find("Add to") then return f end
    end
end)()""")
check("right-click offers Add to Favourites", row is not None)
if row:
    row.Click(row)
    check("right-click adds to the tab",
          L.eval('__core.EmoteMenu:TabContains("favourites", "dance")') is True)

# The persistence warning has to be somewhere it cannot be missed, because a
# chat line scrolls away.
FAV.Click(FAV)
ET = edit_toggle()
ET.Enter(ET)
tip = L.eval("""(function()
    return table.concat(__tooltipLines or {}, " | ")
end)()""")
check("edit tooltip explains the mode",
      "performed while editing" in tip, tip[:90])
check("edit tooltip warns changes will be lost",
      "lost when you reload" in tip, tip[:120])
ET.Leave(ET)

ET.Click(ET)
banner = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.text and f.text:find("Editing") then return f.text end
    end
end)()""")
check("edit banner carries the warning too", "lost on reload" in (banner or ""), repr(banner))
ET = edit_toggle(); ET.Click(ET)

# Searching inside a tab narrows within it, it does not escape it.
FAV.Click(FAV)
SB.Type(SB, "wave")
check("search stays inside the active tab", shown_buttons() == 1, f"{shown_buttons()}")
SB.Type(SB, "cheer")
check("search cannot show non-members", shown_buttons() == 0, f"{shown_buttons()}")
SB.Type(SB, "")
ALL.Click(ALL)

print("\n== 2f. creating and deleting tabs ==")

check("PvP and Raid ship with contents",
      L.eval('__core.EmoteMenu:TabCount("pvp")') > 0 and
      L.eval('__core.EmoteMenu:TabCount("raid")') > 0,
      f"pvp={L.eval(chr(39)+chr(39))}")

# Every shipped default must be a real emote, or it is a dead entry nobody can
# see and nobody can fix.
bad = L.eval("""(function()
    local known, missing = {}, {}
    for _, e in ipairs(__core.emoteTable) do known[e.emote] = true end
    for _, tab in ipairs(__core.EmoteMenu.TABS) do
        for _, name in ipairs(tab.defaults or {}) do
            if not known[name] then missing[#missing + 1] = tab.id .. ":" .. name end
        end
    end
    return table.concat(missing, " ")
end)()""")
check("shipped tab contents are all real emotes", bad == "", bad)

def tab_count():
    return L.eval("""(function()
        local n = 0
        for _, f in ipairs(__frames) do if f.id and f.shown then n = n + 1 end end
        return n
    end)()""")

before_tabs = tab_count()
check("a + tab is offered", L.eval("""(function()
    for _, f in ipairs(__frames) do if f.isAdd and f.shown then return true end end
    return false
end)()""") is True)

# Creating a tab
L.execute('__core.EmoteMenu:AddTab("Roleplay")')
check("custom tab created", L.eval('__core.EmoteMenu:IsCustomTab("custom1")') is True)
check("custom tab stored in the DB", L.eval("#EmoteMenuDB.customTabs") == 1)
err = L.eval('select(2, __core.EmoteMenu:AddTab(""))')
check("a blank name is refused", err is not None, repr(err))
err = L.eval('select(2, __core.EmoteMenu:AddTab(string.rep("x", 40)))')
check("an over-long name is refused", err is not None, repr(err))

# Frames must be reused, not recreated, or every reopen leaks a frame per tab.
L.execute("SlashCmdList['EMOTE_MENU']('')")   # hide
L.execute("SlashCmdList['EMOTE_MENU']('')")   # show: pool grows for the new tab
frames_before = L.eval("#__frames")
L.execute("SlashCmdList['EMOTE_MENU']('')")   # hide
L.execute("SlashCmdList['EMOTE_MENU']('')")   # show again: must reuse
check("reopening does not leak tab frames", L.eval("#__frames") == frames_before,
      f"{L.eval(chr(35)+chr(95)+chr(95)+chr(102)+chr(114)+chr(97)+chr(109)+chr(101)+chr(115))} vs {frames_before}")

# Deleting takes its membership with it.
L.execute('__core.EmoteMenu:TabToggle("custom1", "wave")')
check("custom tab holds an emote", L.eval('__core.EmoteMenu:TabContains("custom1", "wave")') is True)
L.execute('__core.EmoteMenu:RemoveTab("custom1")')
check("custom tab removed", L.eval('__core.EmoteMenu:IsCustomTab("custom1")') is False)
check("its membership went with it", L.eval("EmoteMenuDB.tabs.custom1") is None)
# Shipped tabs can be removed and brought back; "All" cannot go at all,
# because without it there would be no route back to the full list.
check("All can never be deleted", L.eval('__core.EmoteMenu:RemoveTab("all")') is False)
check("a shipped tab can be removed", L.eval('__core.EmoteMenu:RemoveTab("pvp")') is True)
check("removed shipped tab disappears from the strip", L.eval("""(function()
    for _, t in ipairs(__core.EmoteMenu.AllTabs()) do
        if t.id == "pvp" then return false end
    end
    return true
end)()""") is True)
check("restore is offered once something is hidden",
      L.eval('__core.EmoteMenu:HasHiddenTabs()') is True)
L.execute('__core.EmoteMenu:RestoreDefaultTabs()')
check("restoring brings it back with its shipped contents",
      L.eval('__core.EmoteMenu:TabCount("pvp")') > 0,
      L.eval('__core.EmoteMenu:TabCount("pvp")'))

# Wrapping: a narrow panel puts tabs on more rows and everything below moves.
F.Resize(F, DEFAULT_W, DEFAULT_H)
wide_viewport = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.frameType == "ScrollFrame" then return f:GetHeight() end
    end
end)()""")
for name in ("Roleplay", "Greetings", "Dancing", "Silly"):
    L.execute(f'__core.EmoteMenu:AddTab("{name}")')
L.execute("SlashCmdList['EMOTE_MENU']('')")
L.execute("SlashCmdList['EMOTE_MENU']('')")
F.Resize(F, EM.BUTTON_WIDTH * 3 + EM.VIEWPORT_INSET, DEFAULT_H)
narrow_viewport = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.frameType == "ScrollFrame" then return f:GetHeight() end
    end
end)()""")
check("narrow panel wraps tabs and shrinks the grid area",
      narrow_viewport < wide_viewport, f"wide={wide_viewport} narrow={narrow_viewport}")
for i in range(4):
    L.execute('__core.EmoteMenu:RemoveTab("custom%d")' % (i + 2))
L.execute("SlashCmdList['EMOTE_MENU']('')")
L.execute("SlashCmdList['EMOTE_MENU']('')")
F.Resize(F, DEFAULT_W, DEFAULT_H)
check("widening restores the grid area",
      L.eval("""(function()
          for _, f in ipairs(__frames) do
              if f.frameType == "ScrollFrame" then return f:GetHeight() end
          end
      end)()""") == wide_viewport)

# Within a session the panel returns to the tab last used, whatever the
# default says -- a default you keep navigating away from is just friction.
RAID = tab("Raid")
RAID.Click(RAID)
L.execute("SlashCmdList['EMOTE_MENU']('')")   # hide
L.execute("SlashCmdList['EMOTE_MENU']('')")   # show
check("reopening returns to the last used tab",
      shown_buttons() == L.eval('__core.EmoteMenu:TabCount("raid")'),
      f"{shown_buttons()} vs raid={L.eval(chr(39)+chr(39))}")
ALL = tab("All")
ALL.Click(ALL)

# The search box stops growing well before the panel does.
def search_width():
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.frameType == "EditBox" and f.parent == EmoteMenuFrame then
                return f:GetWidth()
            end
        end
    end)()""")

F.Resize(F, DEFAULT_W, DEFAULT_H)
wide = search_width()
check("search box is capped on a wide panel", wide <= 260, f"{wide}px at {DEFAULT_W}px")
F.Resize(F, 1800, DEFAULT_H)
check("still capped when the panel is wider still", search_width() == wide,
      f"{search_width()} vs {wide}")
F.Resize(F, EM.BUTTON_WIDTH * 3 + EM.VIEWPORT_INSET, DEFAULT_H)
narrow = search_width()
check("but it does shrink on a narrow panel", narrow < wide, f"{narrow} vs {wide}")
check("and never shrinks to nothing", narrow >= 80, f"{narrow}")
F.Resize(F, DEFAULT_W, DEFAULT_H)

# The checkbox is how the default gets set; the right-click that used to do it
# was not discoverable.
FAV = tab("Favourites")
FAV.Click(FAV)
ET = edit_toggle(); ET.Click(ET)
chk = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.tick and f.label and f.label.text == "Open this tab by default" then return f end
    end
end)()""")
check("edit mode offers a default-tab checkbox", chk is not None)
check("checkbox is hidden outside edit mode or on All", chk.shown is True)
check("checkbox starts unticked", chk.tick.shown is False)
chk.Click(chk)
check("ticking it sets the default", L.eval('__core.EmoteMenu.DefaultTab') == "favourites",
      L.eval('__core.EmoteMenu.DefaultTab'))
check("tick is now shown", chk.tick.shown is True)
chk.Click(chk)
check("unticking returns the default to All",
      L.eval('__core.EmoteMenu.DefaultTab') == "all")
ET = edit_toggle(); ET.Click(ET)
check("checkbox hidden again after leaving edit mode", chk.shown is False)
ALL = tab("All"); ALL.Click(ALL)

# The default only decides the FIRST open after logging in, so that path needs
# a fresh runtime rather than a reopen.
L9 = new_runtime('{ DefaultTab = "pvp", settingsWritten = 1 }')
L9.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
L9.execute("SlashCmdList['EMOTE_MENU']('')")
shown9 = L9.eval("""(function()
    local n = 0
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.shown then n = n + 1 end
    end
    return n
end)()""")
check("first open of a session uses the default tab",
      shown9 == L9.eval('__core.EmoteMenu:TabCount("pvp")'),
      f"{shown9} vs {L9.eval(chr(39)+chr(39))}")
check("a default tab that no longer exists falls back to All",
      L9.eval('__core.EmoteMenu.DefaultTab') == "pvp")

L10 = new_runtime('{ DefaultTab = "ghosttab", settingsWritten = 1 }')
L10.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
check("an unknown stored default is rejected",
      L10.eval('__core.EmoteMenu.DefaultTab') == "all",
      L10.eval('__core.EmoteMenu.DefaultTab'))

print("\n== 3. drag saves position, logout persists it ==")
L.execute("""
local f = EmoteMenuFrame
f.scripts.OnDragStart(f)
f.scripts.OnDragStop(f)
for _, fr in ipairs(__frames) do
    if fr:IsEventRegistered("PLAYER_LOGOUT") then fr:Fire("PLAYER_LOGOUT") end
end
""")
check("drag wrote panel anchor", L.eval("EmoteMenuDB.MainPanelA") == "CENTER")
check("drag wrote panel x", L.eval("EmoteMenuDB.MainPanelX") == 12, L.eval("EmoteMenuDB.MainPanelX"))
check("drag wrote panel y", L.eval("EmoteMenuDB.MainPanelY") == -34, L.eval("EmoteMenuDB.MainPanelY"))
check("still no 'void' global after drag", L.globals()["void"] is None)

print("\n== 3b. panel size persists ==")
F = L.globals()["EmoteMenuFrame"]
F.Resize(F, 640, 400)
F.scripts.OnMouseUp = None
# Drive the grip the way a mouse-up after dragging would.
L.execute("""
for _, f in ipairs(__frames) do
    if f.scripts and f.scripts.OnMouseUp and f.parent == EmoteMenuFrame then
        f.scripts.OnMouseUp(f)
    end
end
""")
check("grip records the new width", L.eval("__core.EmoteMenu.PanelW") == 640,
      L.eval("__core.EmoteMenu.PanelW"))
check("grip records the new height", L.eval("__core.EmoteMenu.PanelH") == 400,
      L.eval("__core.EmoteMenu.PanelH"))
L.execute("""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("PLAYER_LOGOUT") then f:Fire("PLAYER_LOGOUT") end
end
""")
check("size written to the DB", L.eval("EmoteMenuDB.PanelW") == 640 and
      L.eval("EmoteMenuDB.PanelH") == 400,
      f'{L.eval("EmoteMenuDB.PanelW")}x{L.eval("EmoteMenuDB.PanelH")}')

print("\n== 3c. resizing keeps the panel where it is ==")
# Regression: the grip saved size but not position, while StartSizing
# re-anchors the frame internally. The stale anchor made the panel jump on the
# next open.
F = L.globals()["EmoteMenuFrame"]
L.execute('__core.EmoteMenu.MainPanelA = "CENTER"')
L.execute('__core.EmoteMenu.MainPanelX = 999')
grip = L.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.scripts and f.scripts.OnMouseDown and f.parent == EmoteMenuFrame
           and f.scripts.OnMouseUp then return f end
    end
end)()""")
check("resize grip exists", grip is not None)
grip.scripts.OnMouseDown(grip)
F.Resize(F, 700, 400)
grip.scripts.OnMouseUp(grip)
check("resize records the new size",
      L.eval("__core.EmoteMenu.PanelW") == 700 and L.eval("__core.EmoteMenu.PanelH") == 400,
      f'{L.eval("__core.EmoteMenu.PanelW")}x{L.eval("__core.EmoteMenu.PanelH")}')
check("resize also records the position",
      L.eval("__core.EmoteMenu.MainPanelX") != 999,
      f'x={L.eval("__core.EmoteMenu.MainPanelX")}')
check("sizing starts from a top-left anchor",
      L.eval("__core.EmoteMenu.MainPanelA") is not None)
F.Resize(F, DEFAULT_W, DEFAULT_H)

print("\n== 4. upgrade from an old SavedVariables file ==")
L2 = new_runtime("""{
    ShowMinimapIcon = "On",
    MapPosA = "CENTER", MapPosR = "CENTER",
    MainPanelA = "TOPLEFT", MainPanelR = "TOPLEFT",
    MainPanelX = 250, MainPanelY = -120,
    minimapPos = 87.5, hide = false,
}""")
L2.execute(f"""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
""")
check("old minimapPos migrated", L2.eval("EmoteMenuDB.minimap.minimapPos") == 87.5,
      L2.eval("EmoteMenuDB.minimap.minimapPos"))
check("old hide migrated", L2.eval("EmoteMenuDB.minimap.hide") is False)
check("old root keys cleaned up", L2.eval("EmoteMenuDB.minimapPos") is None
      and L2.eval("EmoteMenuDB.hide") is None)
check("saved panel position preserved", L2.eval("EmoteMenuDB.MainPanelX") == 250)
L2.execute("SlashCmdList['EMOTE_MENU']('')")
check("panel opens at saved anchor",
      L2.eval("EmoteMenuFrame.point[1]") == "TOPLEFT", L2.eval("EmoteMenuFrame.point[1]"))

print("\n== 4b. a hidden icon stays hidden across the migration ==")
L2b = new_runtime("""{ ShowMinimapIcon = "On", minimapPos = 12, hide = true }""")
L2b.execute(f"""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
""")
check("legacy hide=true migrated", L2b.eval("EmoteMenuDB.minimap.hide") is True,
      L2b.eval("EmoteMenuDB.minimap.hide"))
check("icon hidden, not shown", L2b.eval("#__dbicon.hidden") == 1 and L2b.eval("#__dbicon.shown") == 0,
      f"shown={L2b.eval('#__dbicon.shown')} hidden={L2b.eval('#__dbicon.hidden')}")
check("ShowMinimapIcon seeded to Off", L2b.eval("EmoteMenuDB.ShowMinimapIcon") == "Off",
      L2b.eval("EmoteMenuDB.ShowMinimapIcon"))

print("\n== 4c. a visible icon stays visible ==")
L2c = new_runtime("""{ minimapPos = 12, hide = false }""")
L2c.execute(f"""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
""")
check("legacy hide=false migrated", L2c.eval("EmoteMenuDB.minimap.hide") is False)
check("icon shown", L2c.eval("#__dbicon.shown") == 1 and L2c.eval("#__dbicon.hidden") == 0)
check("ShowMinimapIcon stays On", L2c.eval("EmoteMenuDB.ShowMinimapIcon") == "On")

print("\n== 5. corrupt SavedVariables fall back to defaults ==")
L3 = new_runtime("""{
    ShowMinimapIcon = "Maybe",
    MainPanelA = "SIDEWAYS", MainPanelR = 42,
    MainPanelX = "lots", MainPanelY = 99999,
}""")
L3.execute(f"""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
""")
check("bad toggle rejected", L3.eval("EmoteMenuDB.ShowMinimapIcon") == "On")
check("bad anchor rejected", L3.eval("EmoteMenuDB.MainPanelA") == "CENTER")
check("non-string anchor rejected", L3.eval("EmoteMenuDB.MainPanelR") == "CENTER")
check("non-number coord rejected", L3.eval("EmoteMenuDB.MainPanelX") == 0)
check("out-of-range coord rejected", L3.eval("EmoteMenuDB.MainPanelY") == 0)
L3.execute("SlashCmdList['EMOTE_MENU']('')")
check("panel still opens with corrupt DB", L3.eval("EmoteMenuFrame:IsShown()") is True)

print("\n== 6. folder renamed (the old bug) ==")
L4 = new_runtime("nil")
L4.execute("""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "SomeOtherAddon") end
end
""")
ok, err = True, ""
try:
    L4.execute("SlashCmdList['EMOTE_MENU']('')")
except Exception as e:
    ok, err = False, str(e)[:160]
check("opening before our ADDON_LOADED does not error", ok, err)

print()
if failures:
    print(f"{len(failures)} FAILURE(S): " + ", ".join(failures))
    sys.exit(1)
print("All checks passed.")
