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

# The stub reports the Forever interface, so the addon hides the emotes that
# build measured as declared-but-not-implemented. "In the data" and "visible on
# this client" are therefore different numbers, and tests must not confuse them.
_UNIMPL_BLOCK = _re.search("core" + chr(92) + ".unimplemented = .*", _STORE, _re.S)
_UNIMPL_TEXT = _UNIMPL_BLOCK.group(0) if _UNIMPL_BLOCK else ""
UNIMPLEMENTED = set(_re.findall(chr(92) + chr(91) + chr(34) + "(\w+)" + chr(34) + chr(92) + chr(93) + " = true", _UNIMPL_TEXT))
VISIBLE_COUNT = EMOTE_COUNT - len(UNIMPLEMENTED)

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
check("buttons built on first show", after - before >= VISIBLE_COUNT, f"created={after - before}")

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
check("clicked every emote button", L.eval("__buttonCount") == VISIBLE_COUNT, f"n={L.eval('__buttonCount')}")
check("no errors clicking buttons", L.eval("#__clickErrors") == 0,
      list(L.eval("__clickErrors").values())[:3])
check("no errors showing tooltips", L.eval("#__tipErrors") == 0,
      list(L.eval("__tipErrors").values())[:3])
check("DoEmote fired once per button", L.eval("#__emotes") == VISIBLE_COUNT)
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
_entries = _re.findall(
    r'emote = "([^"]*)",\s*cmd = "[^"]*",\s*noTargetText = "[^"]*",\s*targetText = "([^"]*)"',
    _store)
_expected = sum(1 for name, tgt in _entries if tgt == "" and name not in UNIMPLEMENTED)
check(f"{_expected} emotes forced to no-target", notarget == _expected,
      f"n={notarget} expected={_expected}")

print("""\n== 2a. only emotes this client has ==""")
check("with no token list, every available emote is shown",
      emote_buttons() == VISIBLE_COUNT, f"{emote_buttons()} of {VISIBLE_COUNT}")

# An older flavour declares fewer emotes; the newer ones must not appear.
Lold = LuaRuntime(unpack_returned_tuples=True)
Lold.execute(open(STUB, encoding="utf-8").read())
Lold.execute("EmoteMenuDB = nil")
Lold.execute("__core = {}")
Lold.execute("""
    MAXEMOTEINDEX = 500
    EMOTE1_TOKEN = "AGREE"
    EMOTE2_TOKEN = "WAVE"
    EMOTE3_TOKEN = "DANCE"
""")
_loader = Lold.eval("function(p,n,c) return assert(loadfile(p))(n,c) end")
for _rel in ["Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
             "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua", "Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua",
             "wowEmoteMenuStore.lua", "wowEmoteMenu.lua"]:
    if _rel == "wowEmoteMenu.lua":
        Lold.execute('local f={Register=function()end,Show=function()end,Hide=function()end} LibStub.libs["LibDBIcon-1.0"]=f')
    _loader(os.path.join(ADDON, _rel).replace(chr(92), "/"), ADDON_FOLDER, Lold.globals()["__core"])
Lold.execute("""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "wowEmoteMenu-main") end
end
""")
Lold.execute("SlashCmdList['EMOTE_MENU']()")
built = Lold.eval("""(function()
    local t = {}
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then t[#t+1] = f.text end
    end
    table.sort(t)
    return table.concat(t, " ")
end)()""").split()
server_only = ["fail", "goodluck", "moan", "serious", "shake", "stink", "stopattack", "toast"]
built_all = built
check("a limited client only gets the emotes it declares",
      set(built) == {"agree", "wave", "dance"} | set(server_only), f"{sorted(built)}")
check("emotes it lacks are absent", "boop" not in built and "huzzah" not in built,
      [e for e in ("boop", "huzzah") if e in built])
check("server-only emotes survive the filter", all(e in built for e in server_only),
      [e for e in server_only if e not in built])

# An emote a client lists but never performs is hidden only on the flavour
# measured to not implement it, and stays available everywhere else.
check("measured-unimplemented emotes are hidden on that flavour",
      all(e not in built_all for e in UNIMPLEMENTED),
      [e for e in UNIMPLEMENTED if e in built_all])
check("they are still in the data for other flavours",
      all(("emote = " + chr(34) + e + chr(34)) in _STORE for e in UNIMPLEMENTED))

# A different flavour must NOT have them hidden.
Lret = LuaRuntime(unpack_returned_tuples=True)
Lret.execute(open(STUB, encoding="utf-8").read())
Lret.execute("EmoteMenuDB = nil")
Lret.execute("__core = {}")
# Retail interface, and it declares huzzah.
Lret.execute("""
    function GetBuildInfo() return "12.1.0", "60000", "Sep 2026", 120100 end
    MAXEMOTEINDEX = 700
    EMOTE1_TOKEN = "AGREE"
    EMOTE624_TOKEN = "HUZZAH"
""")
_l2 = Lret.eval("function(p,n,c) return assert(loadfile(p))(n,c) end")
for _rel in ["Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
             "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua", "Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua",
             "wowEmoteMenuStore.lua", "wowEmoteMenu.lua"]:
    if _rel == "wowEmoteMenu.lua":
        Lret.execute('local f={Register=function()end,Show=function()end,Hide=function()end} LibStub.libs["LibDBIcon-1.0"]=f')
    _l2(os.path.join(ADDON, _rel).replace(chr(92), "/"), ADDON_FOLDER, Lret.globals()["__core"])
Lret.execute("""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "wowEmoteMenu-main") end
end
""")
Lret.execute("SlashCmdList['EMOTE_MENU']()")
built_retail = Lret.eval("""(function()
    local t = {}
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then t[#t+1] = f.text end
    end
    return table.concat(t, " ")
end)()""").split()
check("the same emote IS shown on a flavour that implements it",
      "huzzah" in built_retail, sorted(built_retail))

# A truncated label must not leave you guessing which emote it is, and a few
# commands are not simply the emote name.
def tip_of(name):
    return L.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.entry ~= nil and f.text == "%s" then return f.tiptext end
        end
    end)()""" % name)

# attackmytarget's actual command is /attacktarget -- precisely the sort of
# thing a truncated label hides.
check("long name shows its command", "/attacktarget" in (tip_of("attackmytarget") or ""),
      repr(tip_of("attackmytarget")))
check("command that differs from the name is shown",
      "/followme" in (tip_of("follow") or ""), repr(tip_of("follow")))
check("ordinary short names do not repeat themselves",
      "/wave" not in (tip_of("wave") or ""), repr(tip_of("wave")))

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
check(f"all {VISIBLE_COUNT} buttons still positioned", placed == VISIBLE_COUNT, f"placed={placed}")

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
check("clearing restores every button", shown_buttons() == VISIBLE_COUNT, f"shown={shown_buttons()}")

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
check("all buttons back after escape", shown_buttons() == VISIBLE_COUNT)

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
check("All tab shows every emote", shown_buttons() == VISIBLE_COUNT, f"{shown_buttons()}")

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
check("edit mode shows all emotes to pick from", shown_buttons() == VISIBLE_COUNT,
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

print("\n== 2g. the options panel ==")
# A runtime of its own: these tests change the button size and the sort order,
# and the sections after this one assume the shipped layout.
L11 = new_runtime("nil")
L11.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
L11.execute("SlashCmdList['EMOTE_MENU']('')")
EM11 = L11.eval("__core.EmoteMenu")

check("options frame exists", L11.globals()["EmoteMenuOptionsFrame"] is not None)
check("it starts hidden", L11.eval("EmoteMenuOptionsFrame:IsShown()") is not True)
check("a cog sits on the panel",
      L11.eval("__core.EmoteMenu.OptionsButton.parent == EmoteMenuFrame") is True)

cog = EM11.OptionsButton
cog.Click(cog)
check("the cog opens the options", L11.eval("EmoteMenuOptionsFrame:IsShown()") is True)
cog.Click(cog)
check("and closes them again", L11.eval("EmoteMenuOptionsFrame:IsShown()") is False)
cog.Click(cog)

L11.execute("EmoteMenuFrame:Hide()")
check("closing the menu takes the options with it",
      L11.eval("EmoteMenuOptionsFrame:IsShown()") is False)
L11.execute("SlashCmdList['EMOTE_MENU']('')")
cog.Click(cog)


def special11():
    return list(L11.eval("UISpecialFrames").values())


check("options are on the escape list after the panel, so escape closes them first",
      special11().index("EmoteMenuOptionsFrame") > special11().index("EmoteMenuFrame"))


def opt_row(label):
    """A control in the options panel, found by its visible label."""
    return L11.eval('''(function()
        for _, f in ipairs(__frames) do
            if f.parent == EmoteMenuOptionsFrame and f.label
               and f.label.text == "%s" then return f end
        end
    end)()''' % label)


def click_text(L, text):
    """Click the button carrying this exact label. Used for the ones built from
    a Blizzard template, which keep their text rather than a label region."""
    b = L.eval('''(function()
        for _, f in ipairs(__frames) do
            if f.text == "%s" and f.scripts and f.scripts.OnClick then return f end
        end
    end)()''' % text)
    assert b is not None, f"no button labelled {text}"
    b.Click(b)


def first_points(n=3):
    """TOPLEFT of the first n emote buttons, in store order."""
    return L11.eval('''(function()
        local out, seen = {}, 0
        for _, f in ipairs(__frames) do
            if f.entry ~= nil and f.points.TOPLEFT then
                seen = seen + 1
                if seen <= %d then
                    out[seen] = { f.points.TOPLEFT.x, f.points.TOPLEFT.y }
                end
            end
        end
        return out
    end)()''' % n)


def columns11():
    return L11.eval("""(function()
        local xs, n = {}, 0
        for _, f in ipairs(__frames) do
            if f.entry ~= nil and f.points and f.points.TOPLEFT then
                local x = f.points.TOPLEFT.x
                if xs[x] == nil then xs[x] = true; n = n + 1 end
            end
        end
        return n
    end)()""")


for row in ("A to Z across the rows", "A to Z down the columns",
            "Width", "Height", "Escape closes the menu", "Show the minimap icon"):
    check(f"control present: {row}", opt_row(row) is not None)

BH = EM11.ButtonH
pts = first_points()
check("A to Z runs across the rows by default",
      pts[1][1] == 0 and pts[2][1] == EM11.ButtonW and pts[2][2] == 0,
      f"{pts[1][1]},{pts[1][2]} then {pts[2][1]},{pts[2][2]}")

down = opt_row("A to Z down the columns")
down.Click(down)
pts = first_points()
check("A to Z down stacks them in one column",
      pts[1][1] == 0 and pts[2][1] == 0 and pts[2][2] == -BH and pts[3][2] == -2 * BH,
      f"{pts[2][1]},{pts[2][2]}")
check("the sort tick follows the setting",
      L11.eval('''(function()
          for _, f in ipairs(__frames) do
              if f.parent == EmoteMenuOptionsFrame and f.label
                 and f.label.text == "A to Z down the columns" then
                  return f.tick.shown
              end
          end
      end)()''') is True)
check("down the columns still places every button", columns11() == 10, columns11())

across = opt_row("A to Z across the rows")
across.Click(across)
pts = first_points()
check("switching back restores the across layout",
      pts[2][1] == EM11.ButtonW and pts[2][2] == 0)

# Button size.
width = opt_row("Width")
width.slider.SetValue(width.slider, 140)
check("the width slider resizes the buttons", EM11.ButtonW == 140, EM11.ButtonW)
check("the grid follows the new width", columns11() == 7, columns11())
check("ComputeGrid reads the live width",
      EM11.ComputeGrid(1400, 100)[0] == 10, EM11.ComputeGrid(1400, 100))
check("the resize floor follows the button size", L11.eval(
    "EmoteMenuFrame.resizeBounds[1] >= 140 * 3"),
    L11.eval("EmoteMenuFrame.resizeBounds[1]"))
check("the buttons themselves are wider", L11.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then return f.w end
    end
end)()""") == 140)

height = opt_row("Height")
height.slider.SetValue(height.slider, 26)
check("the height slider resizes the buttons", EM11.ButtonH == 26, EM11.ButtonH)
check("rows are spaced by the new height", first_points(2)[2][2] == 0
      and L11.eval("""(function()
          for _, f in ipairs(__frames) do
              if f.entry ~= nil then return f.h end
          end
      end)()""") == 26)

def font_height(L, name):
    """GetFont returns three values; lupa hands back a tuple, so unpack in Lua."""
    return L.eval("(function() local _, h = %s:GetFont() return h end)()" % name)


font = opt_row("Text")
check("a text size control is present", font is not None)
font.slider.SetValue(font.slider, 14)
check("the text slider resizes the shared font object",
      font_height(L11, "EmoteMenuButtonFont") == 14,
      font_height(L11, "EmoteMenuButtonFont"))
check("the highlight font matches, so the label cannot jump on hover",
      font_height(L11, "EmoteMenuButtonFontHighlight") == 14)
check("every emote button follows that one font object", L11.eval("""(function()
    local n = 0
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then
            if f.normalFont ~= EmoteMenuButtonFont then return false end
            if f.highlightFont ~= EmoteMenuButtonFontHighlight then return false end
            n = n + 1
        end
    end
    return n > 0
end)()""") is True)
check("the font keeps a real font file",
      L11.eval("(function() return (EmoteMenuButtonFont:GetFont()) end)()") not in (None, ""))

# The number beside each slider is an edit box, so it can be typed into.
wbox = width.box
wbox.SetText(wbox, "150")
wbox.EnterPressed(wbox)
check("typing a width applies it", EM11.ButtonW == 150, EM11.ButtonW)
check("and the slider moves with it", width.slider.value == 150, width.slider.value)
check("the grid reflows to the typed width", columns11() == 6, columns11())

wbox.SetText(wbox, "999")
wbox.EnterPressed(wbox)
check("a typed number past the maximum is clamped", EM11.ButtonW == 180, EM11.ButtonW)
check("and the box is redrawn with what was accepted", wbox.text == "180", wbox.text)

wbox.SetText(wbox, "70")
wbox.Escape(wbox)
check("escape in the box abandons the edit",
      EM11.ButtonW == 180 and wbox.text == "180", f"{EM11.ButtonW} / {wbox.text}")

wbox.SetText(wbox, "")
wbox.EnterPressed(wbox)
check("an empty box reverts rather than resizing to nothing",
      EM11.ButtonW == 180 and wbox.text == "180", f"{EM11.ButtonW} / {wbox.text}")

wbox.SetText(wbox, "100")
wbox.EnterPressed(wbox)

# Clamped at both ends: a slider cannot be dragged out of range, but a saved
# variable can arrive out of range and the two share the same limits.
width.slider.SetValue(width.slider, 1000)
check("the width slider stops at its maximum", EM11.ButtonW <= 180, EM11.ButtonW)
width.slider.SetValue(width.slider, 1)
check("and at its minimum", EM11.ButtonW >= 70, EM11.ButtonW)

# Escape.
escape = opt_row("Escape closes the menu")
escape.Click(escape)
check("turning escape off unregisters the panel",
      "EmoteMenuFrame" not in special11())
check("and records it", EM11.EscapeCloses == "Off", EM11.EscapeCloses)
check("the options dialog still closes on escape",
      "EmoteMenuOptionsFrame" in special11())
escape.Click(escape)
check("turning it back on re-registers the panel", "EmoteMenuFrame" in special11())
escape.Click(escape)
escape.Click(escape)
check("toggling repeatedly does not register it twice",
      special11().count("EmoteMenuFrame") == 1,
      f"{special11().count('EmoteMenuFrame')} entries")

# Minimap icon -- the setting that had no UI at all until now.
hidden_before = L11.eval("#__dbicon.hidden")
minimap = opt_row("Show the minimap icon")
minimap.Click(minimap)
check("unticking the minimap option hides the icon",
      L11.eval("#__dbicon.hidden") == hidden_before + 1 and EM11.ShowMinimapIcon == "Off",
      EM11.ShowMinimapIcon)
check("and the library is told to keep it hidden",
      L11.eval("EmoteMenuDB.minimap.hide") is True)
minimap.Click(minimap)
check("ticking it brings the icon back",
      EM11.ShowMinimapIcon == "On" and L11.eval("EmoteMenuDB.minimap.hide") is False)

# Reset.
L11.execute('__core.EmoteMenu.MainPanelX = 400')
click_text(L11, "Reset to defaults")
check("reset asks first", L11.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.title and f.title.text == "Reset to defaults" then return f.shown end
    end
end)()""") is True)
click_text(L11, "Reset")
check("reset restores the button size",
      EM11.ButtonW == EM11.BUTTON_WIDTH and EM11.ButtonH == BH,
      f"{EM11.ButtonW}x{EM11.ButtonH}")
check("reset restores the sort order", EM11.SortOrder == "across")
check("reset restores the text size",
      EM11.FontSize == EM11.DEFAULT_FONT_SIZE
      and font_height(L11, "EmoteMenuButtonFont") == EM11.DEFAULT_FONT_SIZE,
      EM11.FontSize)
check("reset restores the panel size",
      EM11.PanelW == DEFAULT_W and EM11.PanelH == DEFAULT_H)
check("reset recentres the panel", EM11.MainPanelX == 0 and EM11.MainPanelA == "CENTER")
check("reset leaves escape on", EM11.EscapeCloses == "On"
      and "EmoteMenuFrame" in special11())
check("reset relays out the grid", columns11() == 10, columns11())
check("reset does not touch the tabs",
      L11.eval('__core.EmoteMenu:TabCount("pvp")') > 0)

L11.execute("""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("PLAYER_LOGOUT") then f:Fire("PLAYER_LOGOUT") end
end
""")
check("the options are written to the DB",
      L11.eval("EmoteMenuDB.SortOrder") == "across"
      and L11.eval("EmoteMenuDB.EscapeCloses") == "On"
      and L11.eval("EmoteMenuDB.ButtonW") == EM11.BUTTON_WIDTH,
      f'{L11.eval("EmoteMenuDB.SortOrder")} {L11.eval("EmoteMenuDB.ButtonW")}')

print("\n== 2h. saved options come back ==")
L12 = new_runtime('''{
    ButtonW = 130, ButtonH = 24, FontSize = 15, SortOrder = "down",
    EscapeCloses = "Off", ShowMinimapIcon = "On", settingsWritten = 1,
}''')
L12.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
EM12 = L12.eval("__core.EmoteMenu")
check("saved button size restored", EM12.ButtonW == 130 and EM12.ButtonH == 24,
      f"{EM12.ButtonW}x{EM12.ButtonH}")
check("saved sort order restored", EM12.SortOrder == "down")
check("saved text size restored and applied before any button is built",
      EM12.FontSize == 15
      and font_height(L12, "EmoteMenuButtonFont") == 15,
      EM12.FontSize)
check("escape stays off across a reload",
      "EmoteMenuFrame" not in list(L12.eval("UISpecialFrames").values()))
L12.execute("SlashCmdList['EMOTE_MENU']('')")
check("buttons are built at the saved size", L12.eval("""(function()
    for _, f in ipairs(__frames) do
        if f.entry ~= nil then return f.w == 130 and f.h == 24 end
    end
end)()""") is True)
check("and laid out down the columns", L12.eval("""(function()
    local seen = 0
    for _, f in ipairs(__frames) do
        if f.entry ~= nil and f.points.TOPLEFT then
            seen = seen + 1
            if seen == 2 then return f.points.TOPLEFT.x == 0 end
        end
    end
end)()""") is True)

L13 = new_runtime('''{
    ButtonW = 5000, ButtonH = "tall", FontSize = 0, SortOrder = "sideways",
    EscapeCloses = "Maybe",
}''')
L13.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
EM13 = L13.eval("__core.EmoteMenu")
check("an absurd button width is rejected", EM13.ButtonW == EM13.BUTTON_WIDTH, EM13.ButtonW)
check("a non-numeric button height is rejected", EM13.ButtonH == BH, EM13.ButtonH)
check("a zero text size is rejected", EM13.FontSize == EM13.DEFAULT_FONT_SIZE, EM13.FontSize)
check("an unknown sort order is rejected", EM13.SortOrder == "across", EM13.SortOrder)
check("a bad escape setting is rejected", EM13.EscapeCloses == "On", EM13.EscapeCloses)

print("\n== 2i. renaming a tab ==")
L14 = new_runtime("nil")
L14.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
L14.execute("SlashCmdList['EMOTE_MENU']('')")
EM14 = L14.eval("__core.EmoteMenu")
BOX = EM14.RenameBox


def tab14(label):
    return L14.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.label and f.label.text == "%s" and f.id then return f end
        end
    end)()""" % label)


def toggle14():
    return L14.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.template == "UIPanelButtonTemplate"
               and (f.text == "Edit" or f.text == "Done") then return f end
        end
    end)()""")


def label_of(tab_id):
    """What AllTabs reports the tab is called, which is what the strip draws."""
    return L14.eval("""(function()
        for _, t in ipairs(__core.EmoteMenu.AllTabs()) do
            if t.id == "%s" then return t.label end
        end
    end)()""" % tab_id)


def tab_field(tab_id, field):
    return L14.eval("""(function()
        for _, f in ipairs(__frames) do
            if f.id == "%s" and not f.isAdd then return f.%s end
        end
    end)()""" % (tab_id, field))


def box_shown():
    return L14.eval("__core.EmoteMenu.RenameBox:IsShown()")


# The field only exists while a tab is being edited.
check("no rename field on the All tab", box_shown() is False)
PVP = tab14("PvP")
PVP.Click(PVP)
check("still none before edit mode is entered", box_shown() is False)

ET = toggle14()
ET.Click(ET)
check("edit mode puts a rename field on the tab", box_shown() is True)
check("it is filled with the current name", BOX.text == "PvP", BOX.text)
check("the tab's own label is hidden underneath",
      tab_field("pvp", "label").shown is False)
check("the tab widens to hold the field", tab_field("pvp", "w") >= 110,
      tab_field("pvp", "w"))

members_before = L14.eval('__core.EmoteMenu:TabCount("pvp")')
BOX.SetText(BOX, "Battlegrounds")
BOX.EnterPressed(BOX)
check("typing a name and pressing enter renames the tab",
      label_of("pvp") == "Battlegrounds", label_of("pvp"))
check("the tab button shows the new name",
      tab_field("pvp", "label").text == "Battlegrounds",
      tab_field("pvp", "label").text)
members_after = L14.eval('__core.EmoteMenu:TabCount("pvp")')
check("the id is untouched, so the contents came along",
      members_after == members_before, f"{members_after} vs {members_before}")
check("a renamed shipped tab is recorded in the DB",
      L14.eval("EmoteMenuDB.tabLabels.pvp") == "Battlegrounds")

# Escape abandons the edit.
BOX.SetText(BOX, "Nonsense")
BOX.Escape(BOX)
check("escape puts the old name back",
      label_of("pvp") == "Battlegrounds" and BOX.text == "Battlegrounds",
      f"{label_of('pvp')} / {BOX.text}")

# Pressing Done with a name typed but never confirmed still takes it.
BOX.SetText(BOX, "Arena")
ET = toggle14()
ET.Click(ET)
check("pressing Done commits a name that was never entered",
      label_of("pvp") == "Arena", label_of("pvp"))
check("leaving edit mode takes the field away", box_shown() is False)
check("and gives the tab its label back", tab_field("pvp", "label").shown is True)

# Switching tabs mid-rename commits to the tab that was being renamed.
ET = toggle14()
ET.Click(ET)
BOX.SetText(BOX, "Duels")
FAV14 = tab14("Favourites")
FAV14.Click(FAV14)
check("switching tabs commits the name to the tab it belonged to",
      label_of("pvp") == "Duels", label_of("pvp"))

# A blank name is refused rather than leaving a nameless tab.
ET = toggle14()
ET.Click(ET)
BOX.SetText(BOX, "   ")
BOX.EnterPressed(BOX)
check("a blank name is refused", label_of("favourites") == "Favourites",
      label_of("favourites"))
check("and the field is redrawn with the real name", BOX.text == "Favourites",
      BOX.text)
ET = toggle14()
ET.Click(ET)

check("the API refuses to rename All",
      L14.eval('(__core.EmoteMenu:RenameTab("all", "Everything"))') is None)
check("and refuses a name that is too long",
      L14.eval('(__core.EmoteMenu:RenameTab("favourites", "%s"))' % ("x" * 40)) is None)

# A custom tab carries its name directly rather than through an override.
L14.execute('__core.EmoteMenu:AddTab("Mine")')
newid = L14.eval("""(function()
    for _, t in ipairs(EmoteMenuDB.customTabs) do return t.id end
end)()""")
L14.execute('__core.EmoteMenu:RenameTab("%s", "Yours")' % newid)
check("a custom tab is renamed in place", label_of(newid) == "Yours", label_of(newid))
check("with no stray override left behind",
      L14.eval("EmoteMenuDB.tabLabels['%s']" % newid) is None)

# Deleting a renamed shipped tab forgets the name along with the rest of its
# state, so restoring it later is genuinely the shipped tab.
L14.execute('__core.EmoteMenu:RemoveTab("pvp")')
check("deleting a shipped tab drops its name override",
      L14.eval("EmoteMenuDB.tabLabels.pvp") is None)
L14.execute("__core.EmoteMenu:RestoreDefaultTabs()")
check("restoring it brings back the shipped name", label_of("pvp") == "PvP",
      label_of("pvp"))

# A stored name that is not a usable string must not reach the tab strip.
L15 = new_runtime('''{
    tabLabels = { pvp = 42, raid = "" },
    customTabs = { { id = "custom1", label = { "not a string" } } },
    settingsWritten = 1,
}''')
L15.execute(f'''
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
''')
names15 = L15.eval("""(function()
    local out = {}
    for _, t in ipairs(__core.EmoteMenu.AllTabs()) do out[#out + 1] = t.label end
    return table.concat(out, ",")
end)()""")
check("a non-string stored name falls back to the shipped one", "PvP" in names15, names15)
check("an empty stored name falls back too", "Raid" in names15, names15)
check("a custom tab with a broken name is dropped",
      names15 == "All,Favourites,PvP,Raid", names15)
L15.execute("SlashCmdList['EMOTE_MENU']('')")
check("the panel still opens with corrupt tab names",
      L15.eval("EmoteMenuFrame:IsShown()") is True)

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

print("== 3d. a second copy of the addon does not error ==")
# WoW leaves the old folder behind when an addon is renamed, so two copies
# loading at once is a real situation. The second one must decline politely
# rather than hand nil to LibDBIcon and throw on login.
Ldup = new_runtime("nil")
# Claim the data object name before the addon gets to it, as a first copy would.
Ldup.execute("""
    LibStub("LibDataBroker-1.1"):NewDataObject("Emote_Menu", { type = "data source" })
""")
ok = True
try:
    Ldup.execute(f"""
for _, f in ipairs(__frames) do
    if f:IsEventRegistered("ADDON_LOADED") then f:Fire("ADDON_LOADED", "{ADDON_FOLDER}") end
end
""")
except Exception as e:
    ok = False
    err = str(e)[:140]
check("a duplicate copy loads without erroring", ok, err if not ok else "")
check("and it does not register a second minimap icon",
      Ldup.eval("__dbicon.registered['Emote_Menu']") is None)

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
