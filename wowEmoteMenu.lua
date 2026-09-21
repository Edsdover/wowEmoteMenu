local addonName, core = ...

local EmoteMenu = {}
core.EmoteMenu = EmoteMenu

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
local addonVersion = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or "unknown"

-- Valid values for the saved-variable validators below. Using lookup tables
-- keeps the checks from turning into long and/or chains where operator
-- precedence quietly skips the type check.
local VALID_ANCHORS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}
local VALID_TOGGLES = { On = true, Off = true }

-- Defaults live on the table from the start so the panel can never be shown
-- with a nil anchor, even if something goes wrong loading saved variables.
EmoteMenu.ShowMinimapIcon = "On"
EmoteMenu.MapPosA = "CENTER"
EmoteMenu.MapPosR = "CENTER"
EmoteMenu.MainPanelA = "CENTER"
EmoteMenu.MainPanelR = "CENTER"
EmoteMenu.MainPanelX = 0
EmoteMenu.MainPanelY = 0

----------------------------------------------------------------------
-- Saved variables
----------------------------------------------------------------------
-- Each loader copies EmoteMenuDB into EmoteMenu, falling back to a default
-- when the stored value is missing or malformed.

-- Load an "On"/"Off" variable
function EmoteMenu:LoadVarChk(var, def)
    local stored = EmoteMenuDB[var]
    if type(stored) == "string" and VALID_TOGGLES[stored] then
        self[var] = stored
    else
        self[var] = def
        EmoteMenuDB[var] = def
    end
end

-- Load a numeric variable, clamped to a valid range
function EmoteMenu:LoadVarNum(var, def, valmin, valmax)
    local stored = EmoteMenuDB[var]
    if type(stored) == "number" and stored >= valmin and stored <= valmax then
        self[var] = stored
    else
        self[var] = def
        EmoteMenuDB[var] = def
    end
end

-- Load an anchor point variable
function EmoteMenu:LoadVarAnc(var, def)
    local stored = EmoteMenuDB[var]
    if type(stored) == "string" and VALID_ANCHORS[stored] then
        self[var] = stored
    else
        self[var] = def
        EmoteMenuDB[var] = def
    end
end

-- Did anything we saved last session actually come back?
--
-- The Forever beta writes SavedVariables correctly but never reads them, so a
-- carefully curated tab silently vanishes on reload. That is a worse experience
-- than not having tabs at all, so say it plainly instead.
--
-- A marker is written at logout and looked for at load. The first ever run
-- cannot be told apart from a broken client -- both have no marker -- so this
-- is only consulted when the player edits something, by which point they have
-- logged out at least once and the answer is real.
local SETTINGS_MARKER = "settingsWritten"

local function CheckSettingsRestored()
    EmoteMenu.settingsRestored = type(EmoteMenuDB) == "table"
        and EmoteMenuDB[SETTINGS_MARKER] ~= nil
end

function EmoteMenu:WarnIfNotPersisting()
    if self.settingsRestored or self.persistWarningShown then return end
    self.persistWarningShown = true
    print("|cff66ccffEmote Menu|r: this client is not restoring addon settings, "
        .. "so tab changes will be lost on reload. It affects every addon, not "
        .. "just this one, and there is nothing an addon can do about it.")
end

-- LibDBIcon used to be handed the root of EmoteMenuDB, so it wrote "hide" and
-- "minimapPos" alongside our own keys. Move them into their own subtable so
-- upgrading users keep the icon where they put it, shown or hidden.
local function MigrateMinimapSettings()
    local minimap = EmoteMenuDB.minimap
    if type(minimap) ~= "table" then
        minimap = {}
        EmoteMenuDB.minimap = minimap
    end
    if minimap.minimapPos == nil and type(EmoteMenuDB.minimapPos) == "number" then
        minimap.minimapPos = EmoteMenuDB.minimapPos
    end
    if minimap.hide == nil and type(EmoteMenuDB.hide) == "boolean" then
        minimap.hide = EmoteMenuDB.hide
    end
    EmoteMenuDB.minimapPos = nil
    EmoteMenuDB.hide = nil

    if minimap.minimapPos == nil then
        minimap.minimapPos = 204
    end

    -- minimap.hide is what actually survives a session, and it is also what a
    -- minimap-button manager writes when the player hides the icon elsewhere.
    -- Seed ShowMinimapIcon from it, otherwise SetMinimapIconShown would push
    -- the default "On" back over it on every login and the icon would reappear.
    if type(minimap.hide) == "boolean" then
        local setting = minimap.hide and "Off" or "On"
        EmoteMenu.ShowMinimapIcon = setting
        EmoteMenuDB.ShowMinimapIcon = setting
    end

    return minimap
end

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------
-- "all" is generated, never stored and never editable. Everything else keeps a
-- set of emote names. Defaults ship in the addon so a tab is useful even when
-- settings cannot be saved; the player's own changes layer on top in the DB.
local TABS = {
    { id = "all",        label = "All",        fixed = true },
    { id = "favourites", label = "Favourites", defaults = {} },
}
EmoteMenu.TABS = TABS

local function TabById(id)
    for _, tab in ipairs(TABS) do
        if tab.id == id then return tab end
    end
end

-- Membership lives under EmoteMenuDB.tabs[id]. Reading goes through here so a
-- missing or malformed DB behaves like an empty tab rather than erroring.
local function TabSet(id, create)
    if type(EmoteMenuDB) ~= "table" then return nil end
    if type(EmoteMenuDB.tabs) ~= "table" then
        if not create then return nil end
        EmoteMenuDB.tabs = {}
    end
    if type(EmoteMenuDB.tabs[id]) ~= "table" then
        if not create then return nil end
        local seeded = {}
        local tab = TabById(id)
        for _, emote in ipairs(tab and tab.defaults or {}) do seeded[emote] = true end
        EmoteMenuDB.tabs[id] = seeded
    end
    return EmoteMenuDB.tabs[id]
end

function EmoteMenu:TabContains(id, emote)
    if id == "all" then return true end
    local set = TabSet(id, false)
    if set then return set[emote] == true end
    -- Nothing stored yet, so fall back to what the tab ships with.
    local tab = TabById(id)
    for _, name in ipairs(tab and tab.defaults or {}) do
        if name == emote then return true end
    end
    return false
end

function EmoteMenu:TabToggle(id, emote)
    if id == "all" then return end
    local set = TabSet(id, true)
    if not set then return end
    set[emote] = (not set[emote]) or nil
    return set[emote] == true
end

function EmoteMenu:TabCount(id)
    if id == "all" then return #(core.emoteTable or {}) end
    local n = 0
    for _, entry in ipairs(core.emoteTable or {}) do
        if self:TabContains(id, entry.emote) then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------
-- Main frame
----------------------------------------------------------------------
local DEFAULT_COLUMNS = 10

-- Wide enough to carry the animation/sound markers at the right edge without
-- squeezing the longest labels ('congratulate').
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 18
-- 11px is a compromise: large enough for the speaker cone to survive
-- downsampling, small enough that two of them plus the longest label
-- ('congratulate') still fit across a button.
local MARKER_SIZE = 11
local MARKER_GAP = 2
local MARKER_AREA = (MARKER_SIZE * 2) + MARKER_GAP + 5

local MARGIN_LEFT = 10          -- gap between the panel edge and the grid
local MARGIN_BOTTOM = 10
local TAB_HEIGHT = 20
local TAB_GAP = 4
-- title row, tab row, search row
local CONTENT_TOP = 92
local SEARCH_HEIGHT = 20
local COUNT_WIDTH = 92          -- 'showing 12 of 256' beside the search box
local SCROLLBAR_WIDTH = 12
local SCROLLBAR_GAP = 4

local MIN_COLUMNS = 3
-- Narrow enough to be genuinely useful docked at the side of the screen, but
-- never so narrow that a button label has nowhere to go.
local MIN_WIDTH = (BUTTON_WIDTH * MIN_COLUMNS) + (MARGIN_LEFT * 2) + SCROLLBAR_WIDTH + SCROLLBAR_GAP
local MIN_HEIGHT = CONTENT_TOP + (BUTTON_HEIGHT * 4) + MARGIN_BOTTOM
local MAX_WIDTH, MAX_HEIGHT = 2400, 1600

-- Opening width is derived so the grid still shows DEFAULT_COLUMNS columns
-- now that the scrollbar has to be accounted for.
local DEFAULT_WIDTH = (BUTTON_WIDTH * DEFAULT_COLUMNS) + (MARGIN_LEFT * 2)
    + SCROLLBAR_WIDTH + SCROLLBAR_GAP

-- Opening height is derived so the whole list fits without scrolling at the
-- opening width, which is how the panel has always looked. Deriving it means
-- adding emotes, or changing the header, adjusts it automatically instead of
-- silently pushing the last row under the bottom edge.
local DEFAULT_ROWS = math.ceil(#(core.emoteTable or {}) / DEFAULT_COLUMNS)
local DEFAULT_HEIGHT = CONTENT_TOP + (DEFAULT_ROWS * BUTTON_HEIGHT) + MARGIN_BOTTOM
-- ...but never taller than the screen it has to open on.
local screenCap = math.floor((UIParent:GetHeight() or 900) * 0.85)
DEFAULT_HEIGHT = math.max(MIN_HEIGHT, math.min(DEFAULT_HEIGHT, screenCap, MAX_HEIGHT))
local widthCap = math.floor((UIParent:GetWidth() or 1200) * 0.9)
DEFAULT_WIDTH = math.max(MIN_WIDTH, math.min(DEFAULT_WIDTH, widthCap, MAX_WIDTH))

EmoteMenu.PanelW = DEFAULT_WIDTH
EmoteMenu.PanelH = DEFAULT_HEIGHT
-- Exposed so the tests can assert against the real defaults.
EmoteMenu.DEFAULT_WIDTH, EmoteMenu.DEFAULT_HEIGHT = DEFAULT_WIDTH, DEFAULT_HEIGHT
EmoteMenu.BUTTON_WIDTH = BUTTON_WIDTH
-- Panel width minus this is the usable grid width, which is what decides the
-- column count.
EmoteMenu.VIEWPORT_INSET = (MARGIN_LEFT * 2) + SCROLLBAR_WIDTH + SCROLLBAR_GAP

-- The .toc targets Classic Era (11509) and Forever (16001), which are different
-- API generations: SetMinResize/SetMaxResize were removed in 10.0 and replaced
-- by SetResizeBounds, so the addon has to cope with either.
local function SetResizeLimits(frame, minW, minH, maxW, maxH)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    elseif frame.SetMinResize then
        frame:SetMinResize(minW, minH)
        frame:SetMaxResize(maxW, maxH)
    end
end

local PageF = CreateFrame("Frame", "EmoteMenuFrame", UIParent)
EmoteMenu.PageF = PageF

-- Register with the Escape-to-close list. UISpecialFrames looks the frame up
-- by name in _G, so the frame has to be named (it is, above).
table.insert(UISpecialFrames, "EmoteMenuFrame")

PageF:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
PageF:Hide()
PageF:SetFrameStrata("HIGH")
PageF:SetClampedToScreen(true)
PageF:EnableMouse(true)
PageF:SetMovable(true)
PageF:SetResizable(true)
SetResizeLimits(PageF, MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
PageF:RegisterForDrag("LeftButton")
PageF:SetScript("OnDragStart", PageF.StartMoving)
PageF:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    -- Save panel position
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    EmoteMenu.MainPanelA = point
    EmoteMenu.MainPanelR = relativePoint
    EmoteMenu.MainPanelX = xOfs
    EmoteMenu.MainPanelY = yOfs
end)

-- Add background color
PageF.t = PageF:CreateTexture(nil, "BACKGROUND")
PageF.t:SetAllPoints()
PageF.t:SetColorTexture(0.05, 0.05, 0.05, 0.9)

-- Add main title
PageF.mt = PageF:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
PageF.mt:SetPoint("TOPLEFT", 16, -14)
PageF.mt:SetText("Emote Menu")

-- Add version text
PageF.v = PageF:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
PageF.v:SetPoint("BOTTOMLEFT", PageF.mt, "BOTTOMRIGHT", 8, 1)
PageF.v:SetJustifyH("LEFT")
PageF.v:SetNonSpaceWrap(true)
PageF.v:SetText("v" .. addonVersion)

-- Add close button
local CloseB = CreateFrame("Button", nil, PageF, "UIPanelCloseButton")
CloseB:SetSize(30, 30)
CloseB:SetPoint("TOPRIGHT", 0, 0)

----------------------------------------------------------------------
-- Search box
----------------------------------------------------------------------
-- Sits on its own row under the title so it can span the panel and stay usable
-- when the panel is dragged narrow. Deliberately NOT focused when the panel
-- opens: an EditBox with focus swallows the movement keys, which would be a
-- nasty surprise for a menu opened mid-play.

local SearchBox = CreateFrame("EditBox", nil, PageF)
local SEARCH_TOP = -(CONTENT_TOP - SEARCH_HEIGHT - 6)
SearchBox:SetPoint("TOPLEFT", MARGIN_LEFT, SEARCH_TOP)
SearchBox:SetPoint("TOPRIGHT",
    -(MARGIN_LEFT + SCROLLBAR_WIDTH + SCROLLBAR_GAP + COUNT_WIDTH), SEARCH_TOP)
SearchBox:SetHeight(SEARCH_HEIGHT)
SearchBox:SetAutoFocus(false)
SearchBox:SetFontObject("GameFontHighlightSmall")
SearchBox:SetTextInsets(6, 20, 0, 0)
SearchBox:SetMaxLetters(40)

SearchBox.bg = SearchBox:CreateTexture(nil, "BACKGROUND")
SearchBox.bg:SetAllPoints()
SearchBox.bg:SetColorTexture(1, 1, 1, 0.07)

SearchBox.hint = SearchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
SearchBox.hint:SetPoint("LEFT", 6, 0)
SearchBox.hint:SetText("Search emotes")

local ClearSearch = CreateFrame("Button", nil, SearchBox)
ClearSearch:SetSize(16, 16)
ClearSearch:SetPoint("RIGHT", -3, 0)
ClearSearch:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
ClearSearch:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
ClearSearch:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
ClearSearch:Hide()

local CountLabel = PageF:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
CountLabel:SetPoint("LEFT", SearchBox, "RIGHT", 6, 0)
CountLabel:SetWidth(COUNT_WIDTH - 10)
CountLabel:SetJustifyH("RIGHT")

----------------------------------------------------------------------
-- Tab strip
----------------------------------------------------------------------
-- Built by hand rather than from a Blizzard tab template: those differ between
-- API generations, and the strip has to grow as the player adds tabs anyway.

local ActiveTab = "all"
local EditMode = false
local TabButtons = {}

local TabStrip = CreateFrame("Frame", nil, PageF)
TabStrip:SetPoint("TOPLEFT", MARGIN_LEFT, -34)
TabStrip:SetPoint("TOPRIGHT", -(MARGIN_LEFT + 80), -34)
TabStrip:SetHeight(TAB_HEIGHT)

-- The lock. Editing is off by default and has to be asked for, so a fast
-- click can never quietly rearrange a tab.
local EditToggle = CreateFrame("Button", nil, PageF, "UIPanelButtonTemplate")
EditToggle:SetSize(70, TAB_HEIGHT)
EditToggle:SetPoint("TOPRIGHT", -MARGIN_LEFT, -34)
EditToggle:SetText("Edit")

local EditBanner = PageF:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
EditBanner:SetPoint("LEFT", SearchBox, "LEFT", 4, 0)
EditBanner:SetPoint("RIGHT", SearchBox, "RIGHT", -4, 0)
EditBanner:SetJustifyH("LEFT")
EditBanner:Hide()

local function MakeTabButton(tab)
    local b = CreateFrame("Button", nil, TabStrip)
    b:SetHeight(TAB_HEIGHT)
    b.id = tab.id

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()

    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(tab.label)
    -- Width follows the label so a longer custom tab name still fits.
    b:SetWidth(math.max(44, b.label:GetStringWidth() + 18))
    return b
end

local function RefreshTabs()
    for _, b in ipairs(TabButtons) do
        local active = (b.id == ActiveTab)
        b.bg:SetColorTexture(1, 1, 1, active and 0.16 or 0.05)
        b.label:SetTextColor(active and 1 or 0.65, active and 0.82 or 0.65,
                             active and 0.25 or 0.65)
    end
    -- "All" is generated from the emote list, so there is nothing to edit.
    -- Hidden rather than disabled: a greyed-out button invites "why can I
    -- not click this?", while an absent one just reads as not applicable.
    -- The tab strip keeps its width either way so the tabs do not shift
    -- sideways as the button comes and goes.
    local editable = ActiveTab ~= "all"
    EditToggle:SetShown(editable)
    EditToggle:SetText(EditMode and "Done" or "Edit")
    EditBanner:SetShown(EditMode)
    SearchBox:SetShown(not EditMode)
    if EditMode then
        local tab = TabById(ActiveTab)
        EditBanner:SetText(("|cffffd100Editing %s|r  -- click emotes to add or remove")
            :format(tab and tab.label or ActiveTab))
    end
end

----------------------------------------------------------------------
-- Scrolling viewport
----------------------------------------------------------------------
-- Deliberately built from bare ScrollFrame and Slider widgets rather than a
-- Blizzard template. Templates come and go between API generations and this
-- addon targets two of them; these core widget types exist in both.

local ScrollF = CreateFrame("ScrollFrame", nil, PageF)
ScrollF:SetPoint("TOPLEFT", MARGIN_LEFT, -CONTENT_TOP)
ScrollF:SetPoint("BOTTOMRIGHT", -(MARGIN_LEFT + SCROLLBAR_WIDTH + SCROLLBAR_GAP), MARGIN_BOTTOM)

local ScrollChild = CreateFrame("Frame", nil, ScrollF)
ScrollChild:SetSize(1, 1)
ScrollF:SetScrollChild(ScrollChild)

local ScrollBar = CreateFrame("Slider", nil, PageF)
ScrollBar:SetOrientation("VERTICAL")
ScrollBar:SetWidth(SCROLLBAR_WIDTH)
ScrollBar:SetPoint("TOPLEFT", ScrollF, "TOPRIGHT", SCROLLBAR_GAP, 0)
ScrollBar:SetPoint("BOTTOMLEFT", ScrollF, "BOTTOMRIGHT", SCROLLBAR_GAP, 0)
ScrollBar:SetValueStep(1)
ScrollBar:SetObeyStepOnDrag(true)
ScrollBar:Hide()

ScrollBar.track = ScrollBar:CreateTexture(nil, "BACKGROUND")
ScrollBar.track:SetAllPoints()
ScrollBar.track:SetColorTexture(1, 1, 1, 0.07)

ScrollBar.thumb = ScrollBar:CreateTexture(nil, "ARTWORK")
ScrollBar.thumb:SetColorTexture(1, 1, 1, 0.30)
ScrollBar.thumb:SetSize(SCROLLBAR_WIDTH, 40)
ScrollBar:SetThumbTexture(ScrollBar.thumb)

ScrollBar:SetScript("OnValueChanged", function(self, value)
    ScrollF:SetVerticalScroll(value)
end)

ScrollF:EnableMouseWheel(true)
ScrollF:SetScript("OnMouseWheel", function(_, delta)
    if not ScrollBar:IsShown() then return end
    local _, maxScroll = ScrollBar:GetMinMaxValues()
    local step = BUTTON_HEIGHT * 3
    local target = ScrollBar:GetValue() - (delta * step)
    ScrollBar:SetValue(math.max(0, math.min(target, maxScroll)))
end)

----------------------------------------------------------------------
-- Resize grip
----------------------------------------------------------------------
local Grip = CreateFrame("Button", nil, PageF)
Grip:SetSize(16, 16)
Grip:SetPoint("BOTTOMRIGHT", -2, 2)
Grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
Grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
Grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

Grip:SetScript("OnMouseDown", function()
    PageF:StartSizing("BOTTOMRIGHT")
end)
Grip:SetScript("OnMouseUp", function()
    PageF:StopMovingOrSizing()
    EmoteMenu.PanelW = math.floor(PageF:GetWidth() + 0.5)
    EmoteMenu.PanelH = math.floor(PageF:GetHeight() + 0.5)
end)

----------------------------------------------------------------------
-- Emote buttons
----------------------------------------------------------------------
-- Show the tooltip for an emote button. Anchored to the panel rather than the
-- button, flipping to whichever side of the panel has room for it.
-- Anchors to PageF explicitly: the buttons' parent is the scroll child, which
-- is taller than the visible area and scrolls out of view.
local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    local pscale = PageF:GetEffectiveScale()
    local gscale = UIParent:GetEffectiveScale()
    local tscale = GameTooltip:GetEffectiveScale()
    local gap = (UIParent:GetRight() * gscale) - (PageF:GetRight() * pscale)
    if gap < (250 * tscale) then
        GameTooltip:SetPoint("TOPRIGHT", PageF, "TOPLEFT", 0, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", PageF, "TOPRIGHT", 0, 0)
    end
    GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
end

-- Assemble a button's tooltip from whichever lines the emote actually has.
-- Three cases beyond the ordinary one:
--   * emotes that ignore the target have only the untargeted line
--   * a few (promise) print only when they have a target
--   * sit, stand, train and mountspecial perform an action but print nothing,
--     so fall back to naming the slash command rather than showing a blank box
local function BuildTooltip(entry)
    local plain, targeted = entry.noTargetText, entry.targetText
    if plain ~= "" and targeted ~= "" then
        return plain .. "|n|n|cff00AAFF" .. targeted
    elseif plain ~= "" then
        return plain
    elseif targeted ~= "" then
        return "|cff00AAFF" .. targeted
    end
    return entry.cmd ~= "" and entry.cmd or entry.emote
end

-- The markers are small and unlabelled, so the tooltip spells them out.
local function MarkerNote(entry)
    if entry.animated and entry.voiced then
        return "|n|cff888888Has an animation and a sound|r"
    elseif entry.animated then
        return "|n|cff888888Has an animation|r"
    elseif entry.voiced then
        return "|n|cff888888Has a sound|r"
    end
    return ""
end

----------------------------------------------------------------------
-- Animation / sound markers
----------------------------------------------------------------------
-- Drawn from plain coloured rectangles rather than texture files. Texture
-- paths differ between Classic Era and modern clients and a missing one renders
-- as a green block with no error to catch, whereas SetColorTexture needs no
-- file at all and looks identical on both.
--
--   sound     three ascending bars, like a volume meter
--   animation three motion lines
--
-- Both sit in the right-hand margin that BUTTON_WIDTH reserves, so they never
-- overlap the label.

local MARKER_SOUND = { 0.98, 0.82, 0.25 }   -- warm gold
local MARKER_ANIM  = { 0.35, 0.78, 0.98 }   -- cool blue

-- "icons" uses the speaker and dancer art in Textures/, "bars" falls back to
-- shapes drawn from plain rectangles. Both exist because a texture file is the
-- clearer picture but only if it survives being twelve pixels across; the bars
-- always read, whatever the size.
local MARKER_STYLE = "icons"
EmoteMenu.MARKER_STYLE = MARKER_STYLE

-- Derived from addonName rather than hardcoded, for the same reason the
-- ADDON_LOADED check is: the folder gets renamed by CurseForge installs and by
-- anyone stripping the "-main" suffix.
local TEXTURE_PATH = "Interface\\AddOns\\" .. addonName .. "\\Textures\\"

local function AddBar(button, colour, x, y, w, h)
    local t = button:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(colour[1], colour[2], colour[3], 0.95)
    t:SetSize(w, h)
    t:SetPoint("BOTTOMRIGHT", x, y)
    return t
end

local function AddIcon(button, colour, file, right)
    local t = button:CreateTexture(nil, "OVERLAY")
    t:SetTexture(TEXTURE_PATH .. file)
    -- The art is white, so one file per shape covers both colours.
    t:SetVertexColor(colour[1], colour[2], colour[3], 1)
    t:SetSize(MARKER_SIZE, MARKER_SIZE)
    t:SetPoint("RIGHT", right, 0)
    return t
end

local function AddMarkers(button, entry)
    local right = -4
    if MARKER_STYLE == "icons" then
        if entry.voiced then
            AddIcon(button, MARKER_SOUND, "sound.tga", right)
            right = right - MARKER_SIZE - MARKER_GAP
        end
        if entry.animated then
            AddIcon(button, MARKER_ANIM, "animation.tga", right)
        end
        return
    end

    if entry.voiced then
        -- Ascending bars, bottom aligned, reading left to right.
        local base = right - MARKER_SIZE
        AddBar(button, MARKER_SOUND, base + 6, 5, 2, 3)
        AddBar(button, MARKER_SOUND, base + 3, 5, 2, 5)
        AddBar(button, MARKER_SOUND, base + 0, 5, 2, 8)
        right = right - MARKER_SIZE - MARKER_GAP
    end
    if entry.animated then
        -- Stacked motion lines, the middle one shorter.
        local base = right - MARKER_SIZE
        AddBar(button, MARKER_ANIM, base, 11, MARKER_SIZE, 2)
        AddBar(button, MARKER_ANIM, base - 2, 8, MARKER_SIZE - 2, 2)
        AddBar(button, MARKER_ANIM, base, 5, MARKER_SIZE, 2)
    end
end

-- Declared up front: the right-click menu below defines ShowEmoteMenu and
-- calls ApplyFilter, while the button OnClick calls both. Without these a
-- later 'local' would shadow the definition with nil.
local ShowEmoteMenu
local ApplyFilter

----------------------------------------------------------------------
-- Right-click menu
----------------------------------------------------------------------
-- A shortcut for adding to a tab without entering edit mode. Built by hand:
-- UIDropDownMenu is deprecated on modern clients and its replacement does not
-- exist on Classic Era, so neither is safe for an addon targeting both.

local ContextMenu = CreateFrame("Frame", nil, UIParent)
ContextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
ContextMenu:SetSize(150, 10)
ContextMenu:Hide()
ContextMenu.rows = {}

ContextMenu.bg = ContextMenu:CreateTexture(nil, "BACKGROUND")
ContextMenu.bg:SetAllPoints()
ContextMenu.bg:SetColorTexture(0.04, 0.04, 0.04, 0.96)

-- Clicking anywhere else dismisses it; without this it would linger.
ContextMenu:SetScript("OnShow", function(self) self.opened = GetTime() end)
ContextMenu:EnableMouse(true)

local CloseContextMenu

local function ContextRow(index)
    local row = ContextMenu.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, ContextMenu)
    row:SetHeight(18)
    row:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 18)
    row:SetPoint("TOPRIGHT", -4, -4 - (index - 1) * 18)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 6, 0)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.12)
    ContextMenu.rows[index] = row
    return row
end

function ShowEmoteMenu(button, entry)
    local n = 0
    for _, tab in ipairs(TABS) do
        if not tab.fixed then
            n = n + 1
            local row = ContextRow(n)
            local inTab = EmoteMenu:TabContains(tab.id, entry.emote)
            row.label:SetText((inTab and "|cff66ff66Remove from|r " or "Add to ")
                .. tab.label)
            row:SetScript("OnClick", function()
                EmoteMenu:TabToggle(tab.id, entry.emote)
                EmoteMenu:WarnIfNotPersisting()
                CloseContextMenu()
                ApplyFilter(SearchBox:GetText())
            end)
            row:Show()
        end
    end
    for i = n + 1, #ContextMenu.rows do ContextMenu.rows[i]:Hide() end

    if n == 0 then return end
    ContextMenu:SetHeight(8 + n * 18)
    ContextMenu:ClearAllPoints()
    ContextMenu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    ContextMenu:Show()
end

function CloseContextMenu()
    ContextMenu:Hide()
end

-- Any click that is not on the menu itself closes it.
ContextMenu:SetScript("OnUpdate", function(self)
    if not self:IsShown() then return end
    if self:IsMouseOver() then return end
    if IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
        -- Ignore the click that opened it.
        if GetTime() - (self.opened or 0) > 0.1 then self:Hide() end
    end
end)

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
-- How many columns fit, and how many rows that needs. Kept free of any frame
-- lookups so the arithmetic can be exercised on its own.
local function ComputeGrid(viewportWidth, count)
    local columns = math.floor(viewportWidth / BUTTON_WIDTH)
    if columns < 1 then columns = 1 end
    local rows = math.ceil(count / columns)
    return columns, rows
end
EmoteMenu.ComputeGrid = ComputeGrid

local NoMatches = ScrollF:CreateFontString(nil, "ARTWORK", "GameFontDisable")
NoMatches:SetPoint("TOP", 0, -24)
NoMatches:SetText("No emotes match that search.")
NoMatches:Hide()

local buttons = {}      -- every emote button, in store order
local visible = {}      -- the subset currently passing the filter
local layoutColumns = 0

-- Match the typed text against the emote's name, its slash command and the
-- text the server prints. Including the printed text is what lets "sorry" find
-- apologize and "cheers" find drink, which is most of the value at 256 entries.
-- Plain find, not a pattern, so typing "%" or "-" cannot error.
local function Matches(entry, needle)
    return (entry.emote:lower():find(needle, 1, true)
         or entry.cmd:lower():find(needle, 1, true)
         or entry.noTargetText:lower():find(needle, 1, true)
         or entry.targetText:lower():find(needle, 1, true)) ~= nil
end

-- Show the scrollbar only when the content actually overflows, and keep the
-- current scroll offset inside the new range when the panel grows.
local function UpdateScrollRange()
    local viewportHeight = ScrollF:GetHeight()
    local contentHeight = ScrollChild:GetHeight()
    local maxScroll = contentHeight - viewportHeight
    if maxScroll < 1 then
        ScrollBar:SetMinMaxValues(0, 0)
        ScrollBar:SetValue(0)
        ScrollBar:Hide()
        ScrollF:SetVerticalScroll(0)
        return
    end
    ScrollBar:SetMinMaxValues(0, maxScroll)
    ScrollBar:Show()
    -- Proportional thumb, floored so it stays grabbable on a long list.
    local visibleFraction = viewportHeight / contentHeight
    ScrollBar.thumb:SetHeight(math.max(20, viewportHeight * visibleFraction))
    if ScrollBar:GetValue() > maxScroll then
        ScrollBar:SetValue(maxScroll)
    end
end

-- Reposition the buttons for the current width. The column count is the only
-- thing that can change their positions, so a resize that does not cross a
-- column boundary skips the loop entirely -- OnSizeChanged fires continuously
-- while dragging the grip.
local function Reflow(force)
    if #buttons == 0 then return end

    local viewportWidth = ScrollF:GetWidth()
    local columns, rows = ComputeGrid(viewportWidth, #visible)

    if force or columns ~= layoutColumns then
        layoutColumns = columns
        for i, button in ipairs(visible) do
            local column = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", column * BUTTON_WIDTH, -row * BUTTON_HEIGHT)
        end
        ScrollChild:SetSize(columns * BUTTON_WIDTH, math.max(1, rows * BUTTON_HEIGHT))
    end

    UpdateScrollRange()
end
EmoteMenu.Reflow = Reflow

-- Rebuild the visible set. Buttons are never destroyed, only shown or hidden,
-- so filtering costs one pass over the list and no frame churn.
function ApplyFilter(text)
    local needle = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    wipe(visible)

    -- In edit mode every emote stays visible so membership can be toggled;
    -- otherwise the tab restricts the list and the search narrows it further.
    for _, button in ipairs(buttons) do
        local inTab = EditMode or EmoteMenu:TabContains(ActiveTab, button.entry.emote)
        if inTab and (needle == "" or Matches(button.entry, needle)) then
            visible[#visible + 1] = button
            button:Show()
        else
            button:Hide()
        end
        button:UpdateMembership()
    end

    if needle == "" then
        CountLabel:SetText(ActiveTab == "all" and ""
            or ("%d of %d"):format(#visible, #buttons))
        ClearSearch:Hide()
    else
        CountLabel:SetText(("%d of %d"):format(#visible, #buttons))
        ClearSearch:Show()
    end
    SearchBox.hint:SetShown(needle == "" and not SearchBox:HasFocus())
    NoMatches:SetShown(#visible == 0)
    if #visible == 0 then
        NoMatches:SetText(needle ~= "" and "No emotes match that search."
            or "This tab is empty. Press Edit to add some.")
    end

    -- A filter changes every position even when the column count has not, and
    -- the old scroll offset is meaningless against a shorter list.
    ScrollBar:SetValue(0)
    Reflow(true)
end
EmoteMenu.ApplyFilter = ApplyFilter

-- Tab buttons are created here rather than with the strip because selecting
-- one has to re-run the filter, which is defined above.
do
    local x = 0
    for _, tab in ipairs(TABS) do
        local b = MakeTabButton(tab)
        b:SetPoint("TOPLEFT", x, 0)
        x = x + b:GetWidth() + TAB_GAP
        b:SetScript("OnClick", function(self)
            if ActiveTab == self.id then return end
            ActiveTab = self.id
            EditMode = false
            RefreshTabs()
            ApplyFilter(SearchBox:GetText())
        end)
        TabButtons[#TabButtons + 1] = b
    end
end

EditToggle:SetScript("OnClick", function()
    if ActiveTab == "all" then return end
    EditMode = not EditMode
    if EditMode then EmoteMenu:WarnIfNotPersisting() end
    RefreshTabs()
    ApplyFilter(SearchBox:GetText())
end)

SearchBox:SetScript("OnTextChanged", function(self) ApplyFilter(self:GetText()) end)
SearchBox:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
SearchBox:SetScript("OnEditFocusLost", function(self)
    self.hint:SetShown(self:GetText() == "")
end)
-- Escape clears the filter first and only gives up focus once it is empty,
-- so a stray Escape does not close the whole panel mid-search.
SearchBox:SetScript("OnEscapePressed", function(self)
    if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
end)
SearchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

ClearSearch:SetScript("OnClick", function()
    SearchBox:SetText("")
    SearchBox:ClearFocus()
end)

-- Build the emote grid. Deferred until the first time the panel is shown so
-- the frames are never created for players who never open the menu.
local buttonsBuilt = false
local function BuildEmoteButtons()
    if buttonsBuilt then return end
    buttonsBuilt = true

    -- TODO: sorting / filtering goes here once there are options for it
    local sortedList = core.emoteTable

    for i, entry in ipairs(sortedList) do
        local emoteString = entry.emote

        -- Parented to the scroll child, not the panel, so they scroll with it.
        -- Positions are left to Reflow(), which depends on the current width.
        local eBtn = CreateFrame("Button", nil, ScrollChild, "UIPanelButtonTemplate")
        eBtn:SetNormalFontObject("GameFontNormalSmall")
        eBtn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        eBtn:SetText(emoteString)
        eBtn.entry = entry

        -- Keep the label centred, but inside the area left of the markers.
        local label = eBtn:GetFontString()
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", 4, 0)
            label:SetPoint("RIGHT", -MARKER_AREA, 0)
            label:SetJustifyH("CENTER")
        end
        AddMarkers(eBtn, entry)
        buttons[i] = eBtn

        -- An empty targetText means the emote ignores the target, so force no
        -- target rather than letting the server silently drop it.
        local ignoresTarget = entry.targetText == ""
        eBtn.tiptext = BuildTooltip(entry) .. MarkerNote(entry)
        eBtn:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowEmoteMenu(self, entry)
                return
            end
            -- In edit mode a click curates the tab. The emote deliberately does
            -- not fire: that is what makes a mis-click harmless.
            if EditMode and ActiveTab ~= "all" then
                EmoteMenu:TabToggle(ActiveTab, emoteString)
                EmoteMenu:WarnIfNotPersisting()
                self:UpdateMembership()
                RefreshTabs()
                return
            end
            if ignoresTarget then
                DoEmote(emoteString, "none")
            else
                DoEmote(emoteString)
            end
        end)

        -- Shown only in edit mode, so the normal grid stays uncluttered.
        eBtn.member = eBtn:CreateTexture(nil, "BORDER")
        eBtn.member:SetAllPoints()
        eBtn.member:Hide()

        function eBtn:UpdateMembership()
            if not EditMode or ActiveTab == "all" then
                self.member:Hide()
                return
            end
            if EmoteMenu:TabContains(ActiveTab, self.entry.emote) then
                self.member:SetColorTexture(0.25, 0.75, 0.30, 0.35)
            else
                self.member:SetColorTexture(1, 1, 1, 0.04)
            end
            self.member:Show()
        end

        eBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        eBtn:SetScript("OnEnter", ShowTooltip)
        eBtn:SetScript("OnLeave", GameTooltip_Hide)
    end
end

-- Reflow while the grip is dragged. Guarded on the buttons existing because
-- this also fires during the SetSize call at load, long before that.
PageF:SetScript("OnSizeChanged", function()
    if buttonsBuilt then Reflow() end
end)

-- Restore size and position, then build and lay out the contents
PageF:SetScript("OnHide", function()
    EditMode = false
    CloseContextMenu()
end)

PageF:SetScript("OnShow", function(self)
    self:SetSize(EmoteMenu.PanelW, EmoteMenu.PanelH)
    self:ClearAllPoints()
    self:SetPoint(EmoteMenu.MainPanelA, UIParent, EmoteMenu.MainPanelR, EmoteMenu.MainPanelX, EmoteMenu.MainPanelY)
    BuildEmoteButtons()
    -- Reapply rather than Reflow: this rebuilds the visible set (which is
    -- empty on the very first show) and forces a full relayout, which also
    -- covers a height change that leaves the column count alone.
    RefreshTabs()
    ApplyFilter(SearchBox:GetText())
end)

----------------------------------------------------------------------
-- Functions
----------------------------------------------------------------------
function EmoteMenu:IsShown()
    return PageF:IsShown()
end

function EmoteMenu:Toggle()
    if self:IsShown() then
        PageF:Hide()
    else
        PageF:Show()
    end
end

----------------------------------------------------------------------
-- Minimap icon
----------------------------------------------------------------------
function EmoteMenu:CreateMiniMapIcon()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end

    local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject("Emote_Menu", {
        type = "data source",
        text = "Emote Menu",
        icon = "Interface\\Icons\\ability_seal",
        OnClick = function()
            EmoteMenu:Toggle()
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("Emote Menu")
        end,
    })

    local minimap = MigrateMinimapSettings()
    icon:Register("Emote_Menu", dataObject, minimap)

    -- TODO: call this again from the options panel once there is one
    self.SetMinimapIconShown = function(self)
        local hide = self.ShowMinimapIcon ~= "On"
        minimap.hide = hide
        if hide then
            icon:Hide("Emote_Menu")
        else
            icon:Show("Emote_Menu")
        end
    end
    self:SetMinimapIconShown()
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
-- Note: /emote and /em belong to Blizzard's custom text-emote command
-- (SLASH_EMOTE*), so do not register those here.
_G.SLASH_EMOTE_MENU1 = "/emotemenu"
_G.SLASH_EMOTE_MENU2 = "/emm"
SlashCmdList["EMOTE_MENU"] = function()
    EmoteMenu:Toggle()
end

----------------------------------------------------------------------
-- Load
----------------------------------------------------------------------
local dbLoader = CreateFrame("Frame")
dbLoader:RegisterEvent("ADDON_LOADED")
dbLoader:RegisterEvent("PLAYER_LOGOUT")

dbLoader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        CheckSettingsRestored()
        _G.EmoteMenuDB = _G.EmoteMenuDB or {}

        -- Load init values if none in DB
        EmoteMenu:LoadVarChk("ShowMinimapIcon", "On")
        EmoteMenu:LoadVarAnc("MapPosA", "CENTER")               -- Map anchor
        EmoteMenu:LoadVarAnc("MapPosR", "CENTER")               -- Map relative
        -- Panel position
        EmoteMenu:LoadVarAnc("MainPanelA", "CENTER")            -- Panel anchor
        EmoteMenu:LoadVarAnc("MainPanelR", "CENTER")            -- Panel relative
        EmoteMenu:LoadVarNum("MainPanelX", 0, -5000, 5000)      -- Panel X axis
        EmoteMenu:LoadVarNum("MainPanelY", 0, -5000, 5000)      -- Panel Y axis
        -- Panel size
        EmoteMenu:LoadVarNum("PanelW", DEFAULT_WIDTH, MIN_WIDTH, MAX_WIDTH)
        EmoteMenu:LoadVarNum("PanelH", DEFAULT_HEIGHT, MIN_HEIGHT, MAX_HEIGHT)

        EmoteMenu:CreateMiniMapIcon()

        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        -- Save current settings to DB
        EmoteMenuDB.ShowMinimapIcon = EmoteMenu.ShowMinimapIcon
        EmoteMenuDB.MapPosA = EmoteMenu.MapPosA
        EmoteMenuDB.MapPosR = EmoteMenu.MapPosR
        -- Panel position
        EmoteMenuDB.MainPanelA = EmoteMenu.MainPanelA
        EmoteMenuDB.MainPanelR = EmoteMenu.MainPanelR
        EmoteMenuDB.MainPanelX = EmoteMenu.MainPanelX
        EmoteMenuDB.MainPanelY = EmoteMenu.MainPanelY
        EmoteMenuDB.PanelW = EmoteMenu.PanelW
        EmoteMenuDB.PanelH = EmoteMenu.PanelH
        EmoteMenuDB[SETTINGS_MARKER] = time and time() or 1
    end
end)
