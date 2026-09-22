local addonName, core = ...

local EmoteMenu = {}
core.EmoteMenu = EmoteMenu

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
local addonVersion = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or "unknown"

-- Derived from addonName rather than hardcoded, for the same reason the
-- ADDON_LOADED check is: the folder gets renamed by CurseForge installs and by
-- anyone stripping the "-main" suffix.
local TEXTURE_PATH = "Interface\\AddOns\\" .. addonName .. "\\Textures\\"

-- Valid values for the saved-variable validators below. Using lookup tables
-- keeps the checks from turning into long and/or chains where operator
-- precedence quietly skips the type check.
local VALID_ANCHORS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}
local VALID_TOGGLES = { On = true, Off = true }
local VALID_SORTS = { across = true, down = true }

-- Defaults live on the table from the start so the panel can never be shown
-- with a nil anchor, even if something goes wrong loading saved variables.
EmoteMenu.ShowMinimapIcon = "On"
EmoteMenu.MapPosA = "CENTER"
EmoteMenu.MapPosR = "CENTER"
EmoteMenu.MainPanelA = "CENTER"
EmoteMenu.MainPanelR = "CENTER"
EmoteMenu.MainPanelX = 0
EmoteMenu.MainPanelY = 0
EmoteMenu.DefaultTab = "all"
EmoteMenu.SortOrder = "across"
EmoteMenu.EscapeCloses = "On"

----------------------------------------------------------------------
-- Saved variables
----------------------------------------------------------------------
-- Each loader copies EmoteMenuDB into EmoteMenu, falling back to a default
-- when the stored value is missing or malformed.

-- Load a string variable that has to be one of a known set of values
function EmoteMenu:LoadVarSet(var, def, valid)
    local stored = EmoteMenuDB[var]
    if type(stored) == "string" and valid[stored] then
        self[var] = stored
    else
        self[var] = def
        EmoteMenuDB[var] = def
    end
end

-- Load an "On"/"Off" variable
function EmoteMenu:LoadVarChk(var, def)
    self:LoadVarSet(var, def, VALID_TOGGLES)
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
    self:LoadVarSet(var, def, VALID_ANCHORS)
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
-- The shipped contents of PvP and Raid are a guess at what is useful, which
-- would be a problem if they were permanent. They are not: every tab is
-- editable and the player can make their own, so these only need to be a
-- reasonable starting point rather than correct.
local TABS = {
    { id = "all",        label = "All",        fixed = true },
    { id = "favourites", label = "Favourites", defaults = {} },
    { id = "pvp",        label = "PvP", defaults = {
        "attackmytarget", "charge", "stopattack", "incoming", "helpme",
        "healme", "oom", "flee", "threaten", "taunt", "victory", "surrender",
        "rude", "spit", "mock", "cheer", "laugh", "point", "bye", "ready",
    } },
    { id = "raid",       label = "Raid", defaults = {
        "oom", "healme", "helpme", "incoming", "ready", "wait", "follow",
        "thank", "congratulate", "cheer", "applaud", "apologize", "brb",
        "golfclap", "agree", "nod", "clap", "bow",
    } },
}
EmoteMenu.TABS = TABS

-- Tabs the player made. Kept as a list so their order is stable, and merged
-- after the shipped ones by AllTabs().
local function CustomTabs()
    if type(EmoteMenuDB) ~= "table" then return {} end
    if type(EmoteMenuDB.customTabs) ~= "table" then EmoteMenuDB.customTabs = {} end
    return EmoteMenuDB.customTabs
end

-- Shipped tabs cannot be removed from the addon, so deleting one records it as
-- hidden instead. They can be brought back, which a custom tab cannot be.
local function HiddenTabs()
    if type(EmoteMenuDB) ~= "table" then return {} end
    if type(EmoteMenuDB.hiddenTabs) ~= "table" then EmoteMenuDB.hiddenTabs = {} end
    return EmoteMenuDB.hiddenTabs
end

-- Renaming a shipped tab cannot change the addon's own table, so the new name
-- is recorded against the id and applied on the way out. A tab the player made
-- carries its name directly and needs none of this.
local function TabLabels()
    if type(EmoteMenuDB) ~= "table" then return {} end
    if type(EmoteMenuDB.tabLabels) ~= "table" then EmoteMenuDB.tabLabels = {} end
    return EmoteMenuDB.tabLabels
end

local MAX_TAB_LABEL = 18

-- Anything read back out of the DB is treated as suspect: a stored name reaches
-- the screen, so a wrong type or an absurd length has to fall back rather than
-- be drawn.
local function ValidLabel(label)
    return type(label) == "string" and label ~= "" and #label <= MAX_TAB_LABEL
end

local function AllTabs()
    local list = {}
    local hidden = HiddenTabs()
    local renamed = TabLabels()
    for _, tab in ipairs(TABS) do
        -- "All" is the one tab that always exists; without it an empty tab list
        -- would leave no way back to the full set.
        if tab.fixed or not hidden[tab.id] then
            local custom = not tab.fixed and renamed[tab.id] or nil
            if ValidLabel(custom) and custom ~= tab.label then
                -- A copy, so the addon's own table keeps the shipped name and
                -- restoring a deleted tab is not left holding an old edit.
                list[#list + 1] = { id = tab.id, label = custom,
                                    fixed = tab.fixed, defaults = tab.defaults }
            else
                list[#list + 1] = tab
            end
        end
    end
    for _, tab in ipairs(CustomTabs()) do
        if type(tab) == "table" and tab.id and ValidLabel(tab.label) then
            list[#list + 1] = tab
        end
    end
    return list
end

function EmoteMenu:HasHiddenTabs()
    for _ in pairs(HiddenTabs()) do return true end
    return false
end

function EmoteMenu:RestoreDefaultTabs()
    local hidden = HiddenTabs()
    for id in pairs(hidden) do hidden[id] = nil end
end
EmoteMenu.AllTabs = AllTabs

local function TabById(id)
    for _, tab in ipairs(AllTabs()) do
        if tab.id == id then return tab end
    end
end

-- Ids are generated rather than derived from the label, so two tabs can share a
-- name and renaming later cannot orphan the membership stored against the id.
local function NewTabId()
    local n = 1
    while TabById("custom" .. n) do n = n + 1 end
    return "custom" .. n
end

-- Trim and check a name a player typed. Shared so creating and renaming cannot
-- drift apart on what they accept.
local function CleanLabel(label)
    label = tostring(label or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if label == "" then return nil, "A tab needs a name." end
    if #label > MAX_TAB_LABEL then return nil, "That name is too long." end
    return label
end
EmoteMenu.MAX_TAB_LABEL = MAX_TAB_LABEL

function EmoteMenu:AddTab(label)
    local err
    label, err = CleanLabel(label)
    if not label then return nil, err end
    local custom = CustomTabs()
    if #custom >= 8 then return nil, "That is as many tabs as will fit." end
    local tab = { id = NewTabId(), label = label }
    custom[#custom + 1] = tab
    return tab
end

-- Ids never change, so membership, the default-tab setting and anything else
-- stored against a tab survives being renamed without being touched.
function EmoteMenu:RenameTab(id, label)
    local tab = TabById(id)
    if not tab or tab.fixed then return nil, "That tab cannot be renamed." end

    local err
    label, err = CleanLabel(label)
    if not label then return nil, err end

    for _, entry in ipairs(CustomTabs()) do
        if entry.id == id then
            entry.label = label
            return label
        end
    end

    local labels = TabLabels()
    -- Back to the shipped name rather than storing a copy of it, so the
    -- override only exists while it is actually overriding something.
    for _, shipped in ipairs(TABS) do
        if shipped.id == id then
            labels[id] = (label ~= shipped.label) and label or nil
            return label
        end
    end
    return nil, "That tab cannot be renamed."
end

function EmoteMenu:RemoveTab(id)
    local tab = TabById(id)
    if tab and tab.fixed then return false end   -- "All" always stays

    local custom = CustomTabs()
    for i, entry in ipairs(custom) do
        if entry.id == id then
            table.remove(custom, i)
            if type(EmoteMenuDB.tabs) == "table" then EmoteMenuDB.tabs[id] = nil end
            return true
        end
    end

    -- A shipped tab: hide it and drop whatever was stored against it, so
    -- restoring later brings back the shipped contents rather than an old edit.
    for _, shipped in ipairs(TABS) do
        if shipped.id == id then
            HiddenTabs()[id] = true
            if type(EmoteMenuDB.tabs) == "table" then EmoteMenuDB.tabs[id] = nil end
            TabLabels()[id] = nil
            return true
        end
    end
    return false
end

function EmoteMenu:IsCustomTab(id)
    for _, tab in ipairs(CustomTabs()) do
        if tab.id == id then return true end
    end
    return false
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
-- The shipped size. The live values are EmoteMenu.ButtonW/ButtonH, which the
-- options panel changes, so anything that lays out the grid must read those
-- rather than these.
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 18
local MIN_BUTTON_W, MAX_BUTTON_W = 70, 180
local MIN_BUTTON_H, MAX_BUTTON_H = 14, 30
EmoteMenu.ButtonW = BUTTON_WIDTH
EmoteMenu.ButtonH = BUTTON_HEIGHT

-- The button labels point at font objects of this addon's own rather than at
-- GameFontNormalSmall directly. Every label that shares an object follows it
-- when its size changes, so resizing the text is one call and not a walk over
-- 256 buttons.
--
-- Two objects, because a Button swaps to its highlight font under the mouse.
-- Setting both is also what stops the label changing size as the pointer
-- passes over it, which the template's own defaults would have done.
local MIN_FONT_SIZE, MAX_FONT_SIZE = 8, 18

-- The face and flags of a stock font object, falling back to the client's
-- standard font if it cannot be read -- a font object with no font set at all
-- renders nothing, so there has to be an answer here.
local function FontFaceOf(name)
    local source = _G[name]
    if source and source.GetFont then
        local file, height, flags = source:GetFont()
        if file then return file, height, flags end
    end
    return _G.STANDARD_TEXT_FONT or "Fonts" .. string.char(92) .. "FRIZQT__.TTF", 10, ""
end

local _, measuredFontSize = FontFaceOf("GameFontNormalSmall")
local DEFAULT_FONT_SIZE = math.floor((measuredFontSize or 10) + 0.5)
if DEFAULT_FONT_SIZE < MIN_FONT_SIZE or DEFAULT_FONT_SIZE > MAX_FONT_SIZE then
    DEFAULT_FONT_SIZE = 10
end
EmoteMenu.FontSize = DEFAULT_FONT_SIZE
EmoteMenu.DEFAULT_FONT_SIZE = DEFAULT_FONT_SIZE

local function MakeButtonFont(name, sourceName, r, g, b)
    if not CreateFont then return nil end
    local font = CreateFont(name)
    local source = _G[sourceName]
    if source and source.GetFont and font.SetFontObject then
        -- Brings the colour, shadow and justification across; only the size is
        -- ours to set.
        font:SetFontObject(source)
    elseif font.SetTextColor then
        font:SetTextColor(r, g, b)
    end
    return font
end

local ButtonFont = MakeButtonFont("EmoteMenuButtonFont", "GameFontNormalSmall", 1, 0.82, 0)
local ButtonFontHigh = MakeButtonFont("EmoteMenuButtonFontHighlight",
    "GameFontHighlightSmall", 1, 1, 1)

local function ApplyFontSize()
    local size = EmoteMenu.FontSize
    if ButtonFont then
        local file, _, flags = FontFaceOf("GameFontNormalSmall")
        ButtonFont:SetFont(file, size, flags)
    end
    if ButtonFontHigh then
        local file, _, flags = FontFaceOf("GameFontHighlightSmall")
        ButtonFontHigh:SetFont(file, size, flags)
    end
end
ApplyFontSize()
EmoteMenu.ApplyFontSize = ApplyFontSize
-- 11px is a compromise: large enough for the speaker cone to survive
-- downsampling, small enough that two of them plus the longest label
-- ('congratulate') still fit across a button.
local MARKER_SIZE = 11
local MARKER_GAP = 2
local MARKER_AREA = (MARKER_SIZE * 2) + MARKER_GAP + 5
local MARKER_SOUND = { 0.98, 0.82, 0.25 }   -- warm gold
local MARKER_ANIM  = { 0.35, 0.78, 0.98 }   -- cool blue

local MARGIN_LEFT = 10          -- gap between the panel edge and the grid
local MARGIN_BOTTOM = 10
local TAB_HEIGHT = 20
local TAB_GAP = 4
-- title row, tab row, search row
local CONTENT_TOP = 92
local SEARCH_HEIGHT = 20
local COUNT_WIDTH = 92          -- 'showing 12 of 256' beside the search box
-- The two marker filters, which sit in the gap the search box leaves when it
-- stops growing.
local FILTER_SIZE = 16
local FILTER_GAP = 3
local FILTER_AREA = (FILTER_SIZE * 2) + FILTER_GAP + 12
-- A single-line field stretched across a wide panel looks like a mistake, so
-- it stops growing well before the panel does. It still shrinks on a narrow
-- one, where the space genuinely is scarce.
local SEARCH_MAX_WIDTH = 260
local SCROLLBAR_WIDTH = 12
local SCROLLBAR_GAP = 4

local MIN_COLUMNS = 3
-- Narrow enough to be genuinely useful docked at the side of the screen, but
-- never so narrow that a button label has nowhere to go. Computed against the
-- smallest button anyone can ask for, because that is the floor a saved panel
-- width has to be allowed to reach; the live limit follows the current button
-- size and is set by UpdateResizeLimits below.
local MIN_WIDTH = (MIN_BUTTON_W * MIN_COLUMNS) + (MARGIN_LEFT * 2) + SCROLLBAR_WIDTH + SCROLLBAR_GAP
local MIN_HEIGHT = CONTENT_TOP + (MIN_BUTTON_H * 4) + MARGIN_BOTTOM
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
EmoteMenu.BUTTON_WIDTH = BUTTON_WIDTH   -- the default, for tests
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
--
-- Optional, because a menu someone wants parked on screen should not vanish
-- the moment they press Escape for something else. Removing the entry rather
-- than intercepting the key means Escape still reaches whatever else wants it.
local function SetEscapeCloses(enabled)
    local present = false
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "EmoteMenuFrame" then
            -- Walking backwards, the first hit is the one to keep; anything
            -- earlier is a duplicate from an earlier toggle.
            if present or not enabled then
                table.remove(UISpecialFrames, i)
            else
                present = true
            end
        end
    end
    -- Put back at the front rather than the end. The game walks the list from
    -- the end, so the options dialog -- registered after this at load and never
    -- moved -- stays behind the panel and is the one Escape reaches first.
    if enabled and not present then
        table.insert(UISpecialFrames, 1, "EmoteMenuFrame")
    end
end
EmoteMenu.SetEscapeCloses = SetEscapeCloses
SetEscapeCloses(true)

PageF:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
PageF:Hide()
PageF:SetFrameStrata("HIGH")
PageF:SetClampedToScreen(true)
PageF:EnableMouse(true)
PageF:SetMovable(true)
PageF:SetResizable(true)

-- Three columns and four rows of whatever a button currently costs. The
-- options panel can change that, so the limit is recalculated rather than
-- fixed: at 180-wide buttons the old floor would have shown a single column.
local function UpdateResizeLimits()
    SetResizeLimits(PageF,
        math.max(MIN_WIDTH, (EmoteMenu.ButtonW * MIN_COLUMNS) + EmoteMenu.VIEWPORT_INSET),
        math.max(MIN_HEIGHT, CONTENT_TOP + (EmoteMenu.ButtonH * 4) + MARGIN_BOTTOM),
        MAX_WIDTH, MAX_HEIGHT)
end
UpdateResizeLimits()
PageF:RegisterForDrag("LeftButton")
PageF:SetScript("OnDragStart", PageF.StartMoving)
-- Record wherever the frame actually ended up. Both moving and resizing have
-- to call this: StartSizing re-anchors the frame internally so the corner being
-- dragged stays put, which means the stored anchor is stale the moment a resize
-- finishes. Saving size alone left the panel jumping to a new spot on reopen.
local function SavePlacement(self)
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if not point then return end
    EmoteMenu.MainPanelA = point
    EmoteMenu.MainPanelR = relativePoint
    EmoteMenu.MainPanelX = xOfs
    EmoteMenu.MainPanelY = yOfs
end

-- Re-anchor to the top-left corner without moving the frame. Sizing from
-- BOTTOMRIGHT keeps the top-left fixed, so starting from any other anchor makes
-- the frame lurch as WoW converts between them.
local function AnchorTopLeft(self)
    local left, top = self:GetLeft(), self:GetTop()
    if not left or not top then return end
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

PageF:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    SavePlacement(self)
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

-- Declared here because the search box, the marker filters and the tab strip
-- all re-run it, and every one of them is built above the definition. A later
-- 'local' would shadow it with nil.
local ApplyFilter

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
    -(MARGIN_LEFT + SCROLLBAR_WIDTH + SCROLLBAR_GAP + COUNT_WIDTH + FILTER_AREA),
    SEARCH_TOP)
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

----------------------------------------------------------------------
-- Marker filters
----------------------------------------------------------------------
-- Two toggles carrying the same speaker and dancer as the buttons do, because
-- the icons already mean something by the time anyone finds these. They answer
-- a question the grid otherwise cannot -- "which of these make a sound?" --
-- and the answer is data that was gathered by hand, one emote at a time, so it
-- may as well be usable rather than only decorative.
--
-- Always the art rather than the bar fallback: at 16 pixels the shapes read
-- clearly, which is the whole reason the fallback exists at 11.
--
-- Deliberately not saved. A filter that survives a reload is a filter someone
-- will hit weeks later wondering where half their emotes went.

local function MakeFilterToggle(file, colour, title, body)
    local button = CreateFrame("Button", nil, PageF)
    button:SetSize(FILTER_SIZE, FILTER_SIZE)
    button.colour = colour

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(TEXTURE_PATH .. file)
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(FILTER_SIZE - 4, FILTER_SIZE - 4)

    button.title, button.body = title, body
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(self.title)
        GameTooltip:AddLine(self.body, 0.8, 0.8, 0.8, true)
        if EmoteMenu.FilterVoiced and EmoteMenu.FilterAnimated then
            GameTooltip:AddLine("Both are on, so only emotes that have both "
                .. "are shown.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local VoicedFilter = MakeFilterToggle("sound.tga", MARKER_SOUND,
    "Only emotes with a sound",
    "Narrows the list to emotes that play a sound. Click again to show them all.")
local AnimatedFilter = MakeFilterToggle("animation.tga", MARKER_ANIM,
    "Only emotes with an animation",
    "Narrows the list to emotes with an animation. Click again to show them all.")

VoicedFilter:SetPoint("LEFT", SearchBox, "RIGHT", 6, 0)
AnimatedFilter:SetPoint("LEFT", VoicedFilter, "RIGHT", FILTER_GAP, 0)

-- Lit like the active tab is, so "on" means the same thing in both places.
local function PaintFilter(button, on)
    button.bg:SetColorTexture(1, 1, 1, on and 0.16 or 0.05)
    local c = button.colour
    button.icon:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.45)
end

local function RefreshFilters()
    PaintFilter(VoicedFilter, EmoteMenu.FilterVoiced)
    PaintFilter(AnimatedFilter, EmoteMenu.FilterAnimated)
end

VoicedFilter:SetScript("OnClick", function()
    EmoteMenu.FilterVoiced = not EmoteMenu.FilterVoiced
    RefreshFilters()
    ApplyFilter(SearchBox:GetText())
end)
AnimatedFilter:SetScript("OnClick", function()
    EmoteMenu.FilterAnimated = not EmoteMenu.FilterAnimated
    RefreshFilters()
    ApplyFilter(SearchBox:GetText())
end)
RefreshFilters()

EmoteMenu.VoicedFilter, EmoteMenu.AnimatedFilter = VoicedFilter, AnimatedFilter

local CountLabel = PageF:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
CountLabel:SetPoint("LEFT", AnimatedFilter, "RIGHT", 6, 0)
CountLabel:SetWidth(COUNT_WIDTH - 10)
CountLabel:SetJustifyH("RIGHT")

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
    local step = EmoteMenu.ButtonH * 3
    local target = ScrollBar:GetValue() - (delta * step)
    ScrollBar:SetValue(math.max(0, math.min(target, maxScroll)))
end)

----------------------------------------------------------------------
-- Tab strip
----------------------------------------------------------------------
-- Built by hand rather than from a Blizzard tab template: those differ between
-- API generations, and the strip has to grow as the player adds tabs anyway.

local ActiveTab = "all"
-- Not saved: the default decides where the first open after logging in
-- lands, and after that the panel returns to whatever tab was last used.
local sessionTab = nil
local EditMode = false
local TabButtons = {}

local TAB_TOP = 34
local TabStrip = CreateFrame("Frame", nil, PageF)
TabStrip:SetPoint("TOPLEFT", MARGIN_LEFT, -TAB_TOP)
TabStrip:SetPoint("TOPRIGHT", -MARGIN_LEFT, -TAB_TOP)
TabStrip:SetHeight(TAB_HEIGHT)

-- The lock. Editing is off by default and has to be asked for, so a fast
-- click can never quietly rearrange a tab.
local EditToggle = CreateFrame("Button", nil, PageF, "UIPanelButtonTemplate")
EditToggle:SetSize(64, TAB_HEIGHT)
EditToggle:SetText("Edit")

-- Explains the mode before it is entered, and carries the persistence warning
-- where the decision is actually made rather than only in chat.
EditToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(EditMode and "Finish editing" or "Edit this tab")
    GameTooltip:AddLine(
        "Click emotes to add or remove them from this tab. They are not "
        .. "performed while editing, so a stray click is harmless.",
        0.8, 0.8, 0.8, true)
    if not EmoteMenu.settingsRestored then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Changes will be lost when you reload.", 1, 0.5, 0.25, true)
        GameTooltip:AddLine(
            "This client is not restoring addon settings. It affects every "
            .. "addon, not just this one.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end)
EditToggle:SetScript("OnLeave", GameTooltip_Hide)

local DeleteTab = CreateFrame("Button", nil, PageF, "UIPanelButtonTemplate")
DeleteTab:SetSize(80, TAB_HEIGHT)
DeleteTab:SetText("Delete tab")
DeleteTab:Hide()

-- Hand-built checkbox. UICheckButtonTemplate exists on both targets but
-- brings its own sizing and art; this only needs a box and a tick.
local DefaultCheck = CreateFrame("Button", nil, PageF)
DefaultCheck:SetHeight(TAB_HEIGHT)
DefaultCheck:Hide()

DefaultCheck.box = DefaultCheck:CreateTexture(nil, "BACKGROUND")
DefaultCheck.box:SetSize(13, 13)
DefaultCheck.box:SetPoint("LEFT", 0, 0)
DefaultCheck.box:SetColorTexture(1, 1, 1, 0.14)

DefaultCheck.tick = DefaultCheck:CreateTexture(nil, "ARTWORK")
DefaultCheck.tick:SetSize(7, 7)
DefaultCheck.tick:SetPoint("CENTER", DefaultCheck.box, "CENTER")
DefaultCheck.tick:SetColorTexture(0.98, 0.82, 0.25, 1)
DefaultCheck.tick:Hide()

DefaultCheck.label = DefaultCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
DefaultCheck.label:SetPoint("LEFT", DefaultCheck.box, "RIGHT", 5, 0)
DefaultCheck.label:SetText("Open this tab by default")
DefaultCheck:SetWidth(13 + 5 + DefaultCheck.label:GetStringWidth() + 4)

DefaultCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Open this tab by default")
    GameTooltip:AddLine("Which tab the panel starts on each time you log in. "
        .. "While playing it reopens on whichever tab you used last.",
        0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
DefaultCheck:SetScript("OnLeave", GameTooltip_Hide)

local EditBanner = PageF:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
EditBanner:SetPoint("LEFT", SearchBox, "LEFT", 4, 0)
EditBanner:SetPoint("RIGHT", SearchBox, "RIGHT", -4, 0)
EditBanner:SetJustifyH("LEFT")
EditBanner:Hide()

-- Renaming happens where the name already is: in edit mode the active tab's
-- label becomes this field, sitting exactly over it. A dialog would have worked
-- too, but a tab name is one short string and asking for a whole modal to
-- change it reads as heavier than the job.
--
-- Not focused automatically. An EditBox with focus swallows the movement keys,
-- which is a nasty surprise for a panel opened mid-play, so the field is made
-- obvious instead and waits to be clicked.
local RENAME_MIN_WIDTH = 110

local RenameBox = CreateFrame("EditBox", nil, TabStrip)
RenameBox:SetFrameLevel((TabStrip:GetFrameLevel() or 0) + 5)
RenameBox:SetAutoFocus(false)
RenameBox:SetMaxLetters(MAX_TAB_LABEL)
RenameBox:SetFontObject("GameFontHighlightSmall")
RenameBox:SetJustifyH("CENTER")
-- Room on the right for the pencil, so a long name cannot run under it.
RenameBox:SetTextInsets(4, 15, 0, 0)
RenameBox:Hide()

-- A gold wash rather than the flat grey the other fields use: this one has to
-- announce itself, because nothing else about a tab suggests its name can be
-- typed over.
RenameBox.bg = RenameBox:CreateTexture(nil, "BACKGROUND")
RenameBox.bg:SetAllPoints()
RenameBox.bg:SetColorTexture(0.98, 0.82, 0.25, 0.20)

-- A one-pixel frame around it, built from four strips. Cheap, and it survives
-- every client generation, which a border texture would not.
RenameBox.edges = {}
for i = 1, 4 do
    local edge = RenameBox:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(0.98, 0.82, 0.25, 0.75)
    RenameBox.edges[i] = edge
end
RenameBox.edges[1]:SetPoint("TOPLEFT")
RenameBox.edges[1]:SetPoint("TOPRIGHT")
RenameBox.edges[1]:SetHeight(1)
RenameBox.edges[2]:SetPoint("BOTTOMLEFT")
RenameBox.edges[2]:SetPoint("BOTTOMRIGHT")
RenameBox.edges[2]:SetHeight(1)
RenameBox.edges[3]:SetPoint("TOPLEFT")
RenameBox.edges[3]:SetPoint("BOTTOMLEFT")
RenameBox.edges[3]:SetWidth(1)
RenameBox.edges[4]:SetPoint("TOPRIGHT")
RenameBox.edges[4]:SetPoint("BOTTOMRIGHT")
RenameBox.edges[4]:SetWidth(1)

-- The gold wash alone is easy to read past, so the field carries a pencil as
-- well. Faint on purpose: it has one job, which is to say that the name can be
-- typed over, and that job is done the moment someone clicks. It leaves at that
-- point rather than sitting there for the cursor to run into.
RenameBox.pencil = RenameBox:CreateTexture(nil, "OVERLAY")
RenameBox.pencil:SetTexture(TEXTURE_PATH .. "pencil.tga")
RenameBox.pencil:SetVertexColor(0.98, 0.82, 0.25, 0.55)
RenameBox.pencil:SetSize(11, 11)
RenameBox.pencil:SetPoint("RIGHT", -3, 0)

-- Selecting the lot on focus means the common case -- replacing the name
-- outright -- is one click and then typing.
RenameBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
    self.pencil:Hide()
end)
RenameBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Rename this tab")
    GameTooltip:AddLine("Type a new name and press Enter. Escape puts the old "
        .. "one back.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
RenameBox:SetScript("OnLeave", GameTooltip_Hide)

local TabPool = {}

local function MakeTabButton(tab, index)
    local b = TabPool[index]
    if not b then
        b = CreateFrame("Button", nil, TabStrip)
        b:SetHeight(TAB_HEIGHT)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.label = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        b.label:SetPoint("CENTER")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        TabPool[index] = b
    end
    b.id = tab.id
    b.isAdd = nil

    b.label:SetText(tab.label)
    -- Width follows the label so a longer custom tab name still fits.
    b:SetWidth(math.max(40, b.label:GetStringWidth() + 18))
    return b
end

-- The header grows with the number of tab rows, so everything below it is
-- anchored against a value rather than a constant.
local contentTop = CONTENT_TOP
local tabRows = 1

local function HeaderHeight(rows)
    return TAB_TOP + rows * (TAB_HEIGHT + TAB_GAP) + SEARCH_HEIGHT + 12
end

-- Lay the tabs out left to right, wrapping when the row runs out of width.
-- Wrapping rather than shrinking or scrolling: shrinking makes labels
-- unreadable and scrolling hides tabs behind a control nobody looks for, while
-- a second row costs only the height it uses.
local function LayoutTabs()
    local avail = math.max(60, TabStrip:GetWidth())
    local x, row = 0, 0
    for _, b in ipairs(TabButtons) do
        if not b:IsShown() then
        elseif x > 0 and x + b:GetWidth() > avail then
            row = row + 1
            x = 0
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -row * (TAB_HEIGHT + TAB_GAP))
            x = b:GetWidth() + TAB_GAP
        else
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, -row * (TAB_HEIGHT + TAB_GAP))
            x = x + b:GetWidth() + TAB_GAP
        end
    end
    tabRows = row + 1
    TabStrip:SetHeight(tabRows * (TAB_HEIGHT + TAB_GAP))

    local newTop = HeaderHeight(tabRows)
    if newTop ~= contentTop then
        contentTop = newTop
        ScrollF:ClearAllPoints()
        ScrollF:SetPoint("TOPLEFT", MARGIN_LEFT, -contentTop)
        ScrollF:SetPoint("BOTTOMRIGHT",
            -(MARGIN_LEFT + SCROLLBAR_WIDTH + SCROLLBAR_GAP), MARGIN_BOTTOM)
    end
    local searchTop = -(TAB_TOP + tabRows * (TAB_HEIGHT + TAB_GAP) + 4)
    local room = PageF:GetWidth() - (MARGIN_LEFT * 2)
        - SCROLLBAR_WIDTH - SCROLLBAR_GAP - COUNT_WIDTH - FILTER_AREA
    SearchBox:ClearAllPoints()
    SearchBox:SetPoint("TOPLEFT", MARGIN_LEFT, searchTop)
    SearchBox:SetWidth(math.max(80, math.min(SEARCH_MAX_WIDTH, room)))
end

local function ActiveTabButton()
    for _, b in ipairs(TabButtons) do
        if b.id == ActiveTab and not b.isAdd then return b end
    end
end

local function RefreshTabs()
    -- The tab being edited widens to hold the field, so the name has somewhere
    -- to grow into rather than the field being narrower than the word in it.
    local renaming = EditMode and ActiveTab ~= "all"
    for _, b in ipairs(TabButtons) do
        local editing = renaming and b.id == ActiveTab and not b.isAdd
        b.label:SetShown(not editing)
        local natural = math.max(40, b.label:GetStringWidth() + 18)
        b:SetWidth(editing and math.max(RENAME_MIN_WIDTH, natural) or natural)
    end

    RenameBox:SetShown(renaming)
    if renaming then
        local button = ActiveTabButton()
        if button then
            RenameBox:ClearAllPoints()
            RenameBox:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
            RenameBox:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
            -- Never while it is being typed in: a rename in progress outranks
            -- whatever redraw brought us here.
            RenameBox.pencil:SetShown(not RenameBox:HasFocus())
            if not RenameBox:HasFocus() then
                local tab = TabById(ActiveTab)
                RenameBox:SetText(tab and tab.label or "")
            end
        else
            RenameBox:Hide()
        end
    end

    for _, b in ipairs(TabButtons) do
        local active = (b.id == ActiveTab)
        if b.isAdd then
            b.bg:SetColorTexture(1, 1, 1, 0.05)
            b.label:SetTextColor(0.65, 0.65, 0.65)
        else
            b.bg:SetColorTexture(1, 1, 1, active and 0.16 or 0.05)
            b.label:SetTextColor(active and 1 or 0.65, active and 0.82 or 0.65,
                                 active and 0.25 or 0.65)
        end
    end
    -- "All" is generated from the emote list, so there is nothing to edit.
    -- Hidden rather than disabled: a greyed-out button invites "why can I
    -- not click this?", while an absent one just reads as not applicable.
    -- The tab strip keeps its width either way so the tabs do not shift
    -- sideways as the button comes and goes.
    local editable = ActiveTab ~= "all"
    EditToggle:SetShown(editable)
    EditToggle:SetText(EditMode and "Done" or "Edit")
    EditToggle:ClearAllPoints()
    EditToggle:SetPoint("TOPRIGHT", -MARGIN_LEFT,
        -(TAB_TOP + tabRows * (TAB_HEIGHT + TAB_GAP) + 4))
    -- Deleting is editing, so it only appears in edit mode. That keeps the
    -- browsing state to a single button and puts the destructive action out of
    -- reach of an accidental click.
    DeleteTab:SetShown(EditMode and ActiveTab ~= "all")
    DeleteTab:ClearAllPoints()
    DeleteTab:SetPoint("RIGHT", EditToggle, "LEFT", -4, 0)

    local showCheck = EditMode and ActiveTab ~= "all"
    DefaultCheck:SetShown(showCheck)
    DefaultCheck:ClearAllPoints()
    DefaultCheck:SetPoint("TOPLEFT", MARGIN_LEFT,
        -(TAB_TOP + tabRows * (TAB_HEIGHT + TAB_GAP) + 4))
    DefaultCheck.tick:SetShown(EmoteMenu.DefaultTab == ActiveTab)

    if showCheck then
        local spare = PageF:GetWidth() - (MARGIN_LEFT * 2) - 150   -- Edit + Delete
        local labelled = spare > (DefaultCheck.label:GetStringWidth() + 140)
        DefaultCheck.label:SetShown(labelled)
        DefaultCheck:SetWidth(labelled
            and (13 + 5 + DefaultCheck.label:GetStringWidth() + 4) or 13)
    end

    EditBanner:ClearAllPoints()
    EditBanner:SetPoint("LEFT", DefaultCheck, "RIGHT", 12, 0)
    EditBanner:SetPoint("RIGHT", DeleteTab, "LEFT", -8, 0)
    EditBanner:SetShown(EditMode)
    SearchBox:SetShown(not EditMode)
    VoicedFilter:SetShown(not EditMode)
    AnimatedFilter:SetShown(not EditMode)
    if EditMode then
        local tab = TabById(ActiveTab)
        local text = ("|cffffd100Editing %s|r  -- click emotes to add or remove")
            :format(tab and tab.label or ActiveTab)
        -- On screen for as long as the curating lasts, which a chat line
        -- is not: chat scrolls away and is easily missed entirely.
        if not EmoteMenu.settingsRestored then
            text = text .. "   |cffff7f3fchanges will be lost on reload|r"
        end
        EditBanner:SetText(text)
    end
end

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
    AnchorTopLeft(PageF)
    PageF:StartSizing("BOTTOMRIGHT")
end)
Grip:SetScript("OnMouseUp", function()
    PageF:StopMovingOrSizing()
    EmoteMenu.PanelW = math.floor(PageF:GetWidth() + 0.5)
    EmoteMenu.PanelH = math.floor(PageF:GetHeight() + 0.5)
    SavePlacement(PageF)
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

-- A long label is truncated on the button, and the tooltip otherwise shows the
-- emote's text rather than its name -- so "attackmyt..." leaves you guessing.
-- Naming the command fixes that, and also covers the handful whose command is
-- not simply the emote name, such as follow being /followme.
local function CommandNote(entry)
    if entry.cmd == "" then return "" end
    local truncated = #entry.emote > 11
    local differs = entry.cmd ~= ("/" .. entry.emote)
    if not truncated and not differs then return "" end
    return "|n|cff888888" .. entry.cmd .. "|r"
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

-- "icons" uses the speaker and dancer art in Textures/, "bars" falls back to
-- shapes drawn from plain rectangles. Both exist because a texture file is the
-- clearer picture but only if it survives being twelve pixels across; the bars
-- always read, whatever the size.
local MARKER_STYLE = "icons"
EmoteMenu.MARKER_STYLE = MARKER_STYLE

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

-- Declared up front: the right-click menu below defines ShowEmoteMenu, and the
-- button OnClick calls it. Without this a later 'local' would shadow the
-- definition with nil.
local ShowEmoteMenu

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
    for _, tab in ipairs(AllTabs()) do
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
    local columns = math.floor(viewportWidth / EmoteMenu.ButtonW)
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
local layoutRows = 0

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

-- Reposition the buttons for the current width. Only the shape of the grid can
-- change their positions, so a resize that does not cross a column boundary
-- skips the loop entirely -- OnSizeChanged fires continuously while the grip is
-- being dragged.
local function Reflow(force)
    if #buttons == 0 then return end

    local viewportWidth = ScrollF:GetWidth()
    local columns, rows = ComputeGrid(viewportWidth, #visible)

    -- Down-column order depends on the row count as well, which changes with
    -- the filter even when the width has not.
    if force or columns ~= layoutColumns or rows ~= layoutRows then
        layoutColumns, layoutRows = columns, rows
        local down = EmoteMenu.SortOrder == "down"
        for i, button in ipairs(visible) do
            local column, row
            if down then
                column = math.floor((i - 1) / rows)
                row = (i - 1) % rows
            else
                column = (i - 1) % columns
                row = math.floor((i - 1) / columns)
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", column * EmoteMenu.ButtonW, -row * EmoteMenu.ButtonH)
        end
        ScrollChild:SetSize(columns * EmoteMenu.ButtonW,
            math.max(1, rows * EmoteMenu.ButtonH))
    end

    UpdateScrollRange()
end
EmoteMenu.Reflow = Reflow

-- Push a new button size onto the buttons that already exist. Ones built later
-- pick it up from EmoteMenu.ButtonW/H when they are created.
local function ApplyButtonSize()
    UpdateResizeLimits()
    for _, button in ipairs(buttons) do
        button:SetSize(EmoteMenu.ButtonW, EmoteMenu.ButtonH)
    end
    -- The column count can land on the same number at a new button width, and
    -- every position is wrong regardless, so force the relayout.
    Reflow(true)
end
EmoteMenu.ApplyButtonSize = ApplyButtonSize

-- Rebuild the visible set. Buttons are never destroyed, only shown or hidden,
-- so filtering costs one pass over the list and no frame churn.
function ApplyFilter(text)
    local needle = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local wantVoiced = EmoteMenu.FilterVoiced
    local wantAnimated = EmoteMenu.FilterAnimated

    -- In edit mode every emote has to be visible so membership can be toggled,
    -- which is why the search box and the filters are hidden there. They stop
    -- applying as well: a filter that is still narrowing the list while its
    -- control is off screen is worse than no filter at all.
    if EditMode then
        needle, wantVoiced, wantAnimated = "", false, false
    end
    local narrowed = needle ~= "" or wantVoiced or wantAnimated
    wipe(visible)

    -- The tab restricts the list, and the search and the filters narrow it
    -- further. Two filters on is an and, not an or: each one is a question
    -- about the emote and both have to be answered yes.
    for _, button in ipairs(buttons) do
        local entry = button.entry
        local inTab = EditMode or EmoteMenu:TabContains(ActiveTab, entry.emote)
        local marked = (not wantVoiced or entry.voiced)
            and (not wantAnimated or entry.animated)
        if inTab and marked and (needle == "" or Matches(entry, needle)) then
            visible[#visible + 1] = button
            button:Show()
        else
            button:Hide()
        end
        button:UpdateMembership()
    end

    if not narrowed then
        CountLabel:SetText(ActiveTab == "all" and ""
            or ("%d of %d"):format(#visible, #buttons))
    else
        CountLabel:SetText(("%d of %d"):format(#visible, #buttons))
    end
    ClearSearch:SetShown(needle ~= "")
    SearchBox.hint:SetShown(needle == "" and not SearchBox:HasFocus())
    NoMatches:SetShown(#visible == 0)
    if #visible == 0 then
        -- Say which of the three is responsible, because "nothing here" with
        -- no reason given reads as broken.
        local why
        if needle ~= "" and (wantVoiced or wantAnimated) then
            why = "Nothing matches that search and filter."
        elseif needle ~= "" then
            why = "No emotes match that search."
        elseif wantVoiced or wantAnimated then
            why = "No emotes in this tab match that filter."
        else
            why = "This tab is empty. Press Edit to add some."
        end
        NoMatches:SetText(why)
    end

    -- A filter changes every position even when the column count has not, and
    -- the old scroll offset is meaningless against a shorter list.
    ScrollBar:SetValue(0)
    Reflow(true)
end
EmoteMenu.ApplyFilter = ApplyFilter

----------------------------------------------------------------------
-- Tab management
----------------------------------------------------------------------
-- A small modal built by hand. StaticPopup exists on both targets but its
-- behaviour and styling differ, and this needs only a prompt and a confirm.
local Modal = CreateFrame("Frame", nil, UIParent)
Modal:SetFrameStrata("FULLSCREEN_DIALOG")
Modal:SetSize(300, 120)
Modal:SetPoint("CENTER", 0, 120)
Modal:EnableMouse(true)
Modal:Hide()

Modal.bg = Modal:CreateTexture(nil, "BACKGROUND")
Modal.bg:SetAllPoints()
Modal.bg:SetColorTexture(0.04, 0.04, 0.04, 0.97)

Modal.title = Modal:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
Modal.title:SetPoint("TOP", 0, -14)

Modal.body = Modal:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
Modal.body:SetPoint("TOPLEFT", 16, -42)
Modal.body:SetPoint("TOPRIGHT", -16, -42)
Modal.body:SetJustifyH("LEFT")

Modal.input = CreateFrame("EditBox", nil, Modal)
Modal.input:SetPoint("TOPLEFT", 16, -44)
Modal.input:SetPoint("TOPRIGHT", -16, -44)
Modal.input:SetHeight(20)
Modal.input:SetAutoFocus(true)
Modal.input:SetFontObject("GameFontHighlightSmall")
Modal.input:SetTextInsets(6, 6, 0, 0)
Modal.input:SetMaxLetters(18)
Modal.input.bg = Modal.input:CreateTexture(nil, "BACKGROUND")
Modal.input.bg:SetAllPoints()
Modal.input.bg:SetColorTexture(1, 1, 1, 0.08)

Modal.error = Modal:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
Modal.error:SetPoint("TOPLEFT", 16, -68)
Modal.error:SetTextColor(1, 0.45, 0.35)

Modal.accept = CreateFrame("Button", nil, Modal, "UIPanelButtonTemplate")
Modal.accept:SetSize(100, 22)
Modal.accept:SetPoint("BOTTOMRIGHT", -16, 14)

Modal.cancel = CreateFrame("Button", nil, Modal, "UIPanelButtonTemplate")
Modal.cancel:SetSize(100, 22)
Modal.cancel:SetPoint("BOTTOMLEFT", 16, 14)
Modal.cancel:SetText("Cancel")
Modal.cancel:SetScript("OnClick", function() Modal:Hide() end)
Modal:SetScript("OnHide", function(self) self.input:ClearFocus() end)

local function ShowPrompt(opts)
    Modal.title:SetText(opts.title)
    Modal.error:SetText("")
    Modal.accept:SetText(opts.accept or "OK")
    Modal.input:SetShown(opts.input == true)
    Modal.body:SetShown(opts.input ~= true)
    if opts.input then
        Modal.input:SetText("")
    else
        Modal.body:SetText(opts.body or "")
    end
    Modal.accept:SetScript("OnClick", function()
        local err = opts.onAccept(Modal.input:GetText())
        if err then Modal.error:SetText(err) else Modal:Hide() end
    end)
    Modal.input:SetScript("OnEnterPressed", Modal.accept:GetScript("OnClick"))
    Modal.input:SetScript("OnEscapePressed", function() Modal:Hide() end)
    Modal:Show()
    if opts.input then Modal.input:SetFocus() end
end
EmoteMenu.ShowPrompt = ShowPrompt

-- Tab buttons are created here rather than with the strip because selecting
-- one has to re-run the filter, which is defined above.
local RebuildTabStrip
local CommitRename

local function SelectTab(id)
    if ActiveTab == id then return end
    -- Whatever was typed into the old tab's name belongs to the old tab.
    CommitRename()
    ActiveTab = id
    sessionTab = id
    EditMode = false
    RefreshTabs()
    LayoutTabs()
    ApplyFilter(SearchBox:GetText())
end
EmoteMenu.SelectTab = SelectTab

local function PromptNewTab()
    ShowPrompt({
        title = "New tab",
        accept = "Create",
        input = true,
        onAccept = function(text)
            local tab, err = EmoteMenu:AddTab(text)
            if not tab then return err end
            EmoteMenu:WarnIfNotPersisting()
            RebuildTabStrip()
            SelectTab(tab.id)
        end,
    })
end

local function PromptDeleteTab()
    CommitRename()
    local tab = TabById(ActiveTab)
    if not tab or tab.fixed then return end
    -- Say at the point of deletion how to undo it, rather than leaving someone
    -- to discover later that a shipped tab was recoverable all along.
    local body
    if EmoteMenu:IsCustomTab(ActiveTab) then
        body = ("Delete \"%s\" and everything in it? The emotes themselves are "
            .. "not affected, but the tab cannot be brought back."):format(tab.label)
    else
        body = ("Remove \"%s\"? The emotes themselves are not affected, and you "
            .. "can bring the default tabs back by right-clicking the + tab.")
            :format(tab.label)
    end
    ShowPrompt({
        title = "Delete tab",
        accept = "Delete",
        body = body,
        onAccept = function()
            local id = ActiveTab
            ActiveTab = "all"
            EditMode = false
            EmoteMenu:RemoveTab(id)
            RebuildTabStrip()
            RefreshTabs()
            LayoutTabs()
            ApplyFilter(SearchBox:GetText())
        end,
    })
end

function RebuildTabStrip()
    for _, b in ipairs(TabPool) do b:Hide() end
    TabButtons = {}

    local n = 0
    for _, tab in ipairs(AllTabs()) do
        n = n + 1
        local b = MakeTabButton(tab, n)
        b:SetScript("OnClick", function(self) SelectTab(self.id) end)
        b:Show()
        TabButtons[#TabButtons + 1] = b
    end

    -- A trailing "+" reads as "there is room for more" without needing a label.
    local add = MakeTabButton({ id = "__add", label = "+" }, n + 1)
    add.isAdd = true
    add:SetWidth(28)
    add:SetScript("OnClick", function(_, mouseButton)
        if mouseButton ~= "RightButton" then
            PromptNewTab()
        elseif EmoteMenu:HasHiddenTabs() then
            ShowPrompt({
                title = "Restore default tabs",
                accept = "Restore",
                body = "Bring back the default tabs you removed, with their "
                    .. "original contents? Your own tabs are not affected.",
                onAccept = function()
                    EmoteMenu:RestoreDefaultTabs()
                    RebuildTabStrip()
                    RefreshTabs()
                    LayoutTabs()
                end,
            })
        end
    end)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("New tab")
        if EmoteMenu:HasHiddenTabs() then
            GameTooltip:AddLine("Right-click to restore the default tabs you removed.",
                0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", GameTooltip_Hide)
    add:Show()
    TabButtons[#TabButtons + 1] = add
end

-- Guarded against itself: committing gives up focus, and losing focus commits.
local renameInProgress = false

function CommitRename()
    if renameInProgress or not RenameBox:IsShown() then return end
    renameInProgress = true

    local id = ActiveTab
    local tab = TabById(id)
    local typed = RenameBox:GetText()
    if tab and typed ~= tab.label then
        if EmoteMenu:RenameTab(id, typed) then
            EmoteMenu:WarnIfNotPersisting()
            RebuildTabStrip()
        end
    end
    RenameBox:ClearFocus()
    -- Redrawn from what the tab is actually called now, so a name that was
    -- rejected -- empty, or nothing but spaces -- cannot sit in the field
    -- looking accepted.
    local after = TabById(id)
    RenameBox:SetText(after and after.label or "")

    renameInProgress = false
    RefreshTabs()
    LayoutTabs()
end
EmoteMenu.CommitRename = CommitRename
EmoteMenu.RenameBox = RenameBox

RenameBox:SetScript("OnEnterPressed", CommitRename)
RenameBox:SetScript("OnEditFocusLost", CommitRename)
RenameBox:SetScript("OnEscapePressed", function(self)
    local tab = TabById(ActiveTab)
    self:SetText(tab and tab.label or "")
    self:ClearFocus()
end)

DeleteTab:SetScript("OnClick", PromptDeleteTab)
DefaultCheck:SetScript("OnClick", function()
    if ActiveTab == "all" then return end
    EmoteMenu.DefaultTab = (EmoteMenu.DefaultTab == ActiveTab) and "all" or ActiveTab
    EmoteMenu:WarnIfNotPersisting()
    RefreshTabs()
end)
RebuildTabStrip()

EditToggle:SetScript("OnClick", function()
    if ActiveTab == "all" then return end
    -- A name typed but not confirmed still counts: pressing Done is a
    -- reasonable way to finish renaming.
    if EditMode then CommitRename() end
    EditMode = not EditMode
    if EditMode then EmoteMenu:WarnIfNotPersisting() end
    RefreshTabs()
    -- The tab being edited changes width, so the strip has to be laid out
    -- again -- and on a narrow panel that can add or remove a row.
    LayoutTabs()
    ApplyFilter(SearchBox:GetText())
end)

----------------------------------------------------------------------
-- Options
----------------------------------------------------------------------
-- A cog on the panel opens this. Hand-built for the same reason the tabs and
-- the scrollbar are: Blizzard's slider and checkbox templates differ between
-- Classic Era and the modern clients, and this addon ships to both.
--
-- Deliberately not a Blizzard interface-options category either. Those live
-- behind two different APIs depending on the flavour, and a panel reached from
-- inside the menu is where someone will look for it anyway.

local OPT_PAD = 16
local OPT_WIDTH = 330

local Options = CreateFrame("Frame", "EmoteMenuOptionsFrame", UIParent)
-- Above the panel (HIGH) and below the confirm modal (FULLSCREEN_DIALOG).
Options:SetFrameStrata("DIALOG")
Options:SetWidth(OPT_WIDTH)
Options:SetHeight(300)
Options:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
Options:EnableMouse(true)
Options:SetMovable(true)
Options:SetClampedToScreen(true)
Options:RegisterForDrag("LeftButton")
Options:SetScript("OnDragStart", Options.StartMoving)
Options:SetScript("OnDragStop", Options.StopMovingOrSizing)
Options:Hide()
EmoteMenu.Options = Options

-- Escape closes this even when it has been turned off for the panel: that
-- setting is about keeping the emote list on screen, while a dialog that
-- swallows Escape is just broken. CloseSpecialWindows hides the last shown
-- entry first, so this one goes after the panel and closes before it.
table.insert(UISpecialFrames, "EmoteMenuOptionsFrame")

Options.bg = Options:CreateTexture(nil, "BACKGROUND")
Options.bg:SetAllPoints()
Options.bg:SetColorTexture(0.04, 0.04, 0.04, 0.97)

Options.title = Options:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
Options.title:SetPoint("TOPLEFT", OPT_PAD, -14)
Options.title:SetText("Emote Menu options")

local OptClose = CreateFrame("Button", nil, Options, "UIPanelCloseButton")
OptClose:SetSize(28, 28)
OptClose:SetPoint("TOPRIGHT", 0, 0)
OptClose:SetScript("OnClick", function() Options:Hide() end)

-- Rows are stacked against a running cursor rather than anchored to each
-- other, so reordering them later is a matter of moving the lines.
local optY = -46

local function Place(frame, indent, height, gap, stretch)
    frame:SetPoint("TOPLEFT", Options, "TOPLEFT", OPT_PAD + indent, optY)
    if stretch then
        frame:SetPoint("TOPRIGHT", Options, "TOPRIGHT", -OPT_PAD, optY)
    end
    frame:SetHeight(height)
    optY = optY - height - (gap or 8)
end

local function AddHeading(text)
    local fs = Options:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", Options, "TOPLEFT", OPT_PAD, optY)
    fs:SetTextColor(0.98, 0.82, 0.25)
    fs:SetText(text)
    optY = optY - 18
    return fs
end

local function AddTip(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- A tickable row. Used for both the on/off settings and the sort choice: the
-- sort options are one-of-two rather than independent, but giving them their
-- own art for the sake of it would be two shapes to draw and no clearer.
local function MakeCheck(text, tip, onClick)
    local c = CreateFrame("Button", nil, Options)
    c.box = c:CreateTexture(nil, "BACKGROUND")
    c.box:SetSize(13, 13)
    c.box:SetPoint("LEFT", 0, 0)
    c.box:SetColorTexture(1, 1, 1, 0.14)

    c.tick = c:CreateTexture(nil, "ARTWORK")
    c.tick:SetSize(7, 7)
    c.tick:SetPoint("CENTER", c.box, "CENTER")
    c.tick:SetColorTexture(0.98, 0.82, 0.25, 1)
    c.tick:Hide()

    c.label = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    c.label:SetPoint("LEFT", c.box, "RIGHT", 6, 0)
    c.label:SetText(text)
    c:SetWidth(13 + 6 + c.label:GetStringWidth() + 4)
    c:SetScript("OnClick", onClick)
    AddTip(c, text, tip)
    return c
end

-- Label on the left, the number on the right, track underneath. The number is
-- an edit box rather than a label: a slider is quick but vague, and anyone who
-- knows they want 120 should not have to hunt for it with the mouse.
local function MakeSlider(text, tip, minValue, maxValue, apply)
    local row = CreateFrame("Frame", nil, Options)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", 0, -3)
    row.label:SetText(text)

    local box = CreateFrame("EditBox", nil, row)
    box:SetPoint("TOPRIGHT", 0, 0)
    box:SetSize(40, 18)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box:SetJustifyH("CENTER")
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(3, 3, 0, 0)
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    box.bg:SetColorTexture(1, 1, 1, 0.08)
    row.box = box

    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(16)
    slider:SetPoint("BOTTOMLEFT", 0, 0)
    slider:SetPoint("BOTTOMRIGHT", 0, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    slider.track = slider:CreateTexture(nil, "BACKGROUND")
    slider.track:SetPoint("LEFT")
    slider.track:SetPoint("RIGHT")
    slider.track:SetHeight(4)
    slider.track:SetColorTexture(1, 1, 1, 0.10)

    slider.thumb = slider:CreateTexture(nil, "ARTWORK")
    slider.thumb:SetSize(10, 16)
    slider.thumb:SetColorTexture(0.98, 0.82, 0.25, 1)
    slider:SetThumbTexture(slider.thumb)

    -- Rounded on the way in: the widget reports fractions mid-drag, and a
    -- button one and a half pixels wider is not a thing worth allowing.
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        -- Not while it is being typed in: the box is the one place the player
        -- is allowed to hold a value the setting has not taken yet.
        if not box:HasFocus() then box:SetText(tostring(value)) end
        apply(value)
    end)
    AddTip(slider, text, tip)

    row.slider = slider

    function row:Set(value)
        value = math.floor(value + 0.5)
        self.slider:SetValue(value)
        self.box:SetText(tostring(math.floor(self.slider:GetValue() + 0.5)))
    end

    -- Guarded against itself: committing clears the focus, and losing focus
    -- commits.
    local committing = false
    local function Commit()
        if committing then return end
        committing = true
        local typed = tonumber(box:GetText())
        if typed then
            slider:SetValue(math.max(minValue, math.min(maxValue,
                math.floor(typed + 0.5))))
        end
        -- Redrawn from the value that won either way, so an out-of-range or
        -- unparseable entry cannot sit in the box looking accepted.
        row:Set(slider:GetValue())
        box:ClearFocus()
        committing = false
    end

    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function()
        row:Set(slider:GetValue())
        box:ClearFocus()
    end)
    AddTip(box, text, "Type a number and press Enter.")

    return row
end

AddHeading("Order")
local SortAcross = MakeCheck("A to Z across the rows", nil, function()
    EmoteMenu.SortOrder = "across"
    EmoteMenu:RefreshOptions()
    Reflow(true)
end)
local SortDown = MakeCheck("A to Z down the columns", nil, function()
    EmoteMenu.SortOrder = "down"
    EmoteMenu:RefreshOptions()
    Reflow(true)
end)
Place(SortAcross, 8, 16, 4)
Place(SortDown, 8, 16, 12)

AddHeading("Button size")
local WidthSlider = MakeSlider("Width", "How wide each emote button is. Wider "
    .. "buttons mean fewer columns in the same panel.",
    MIN_BUTTON_W, MAX_BUTTON_W, function(value)
        if EmoteMenu.ButtonW == value then return end
        EmoteMenu.ButtonW = value
        ApplyButtonSize()
    end)
local HeightSlider = MakeSlider("Height", "How tall each emote button is.",
    MIN_BUTTON_H, MAX_BUTTON_H, function(value)
        if EmoteMenu.ButtonH == value then return end
        EmoteMenu.ButtonH = value
        ApplyButtonSize()
    end)
local FontSlider = MakeSlider("Text", "The size of the text on the emote "
    .. "buttons. The rest of the panel is left alone.",
    MIN_FONT_SIZE, MAX_FONT_SIZE, function(value)
        if EmoteMenu.FontSize == value then return end
        EmoteMenu.FontSize = value
        ApplyFontSize()
    end)
Place(WidthSlider, 0, 36, 10, true)
Place(HeightSlider, 0, 36, 10, true)
Place(FontSlider, 0, 36, 14, true)

AddHeading("Behaviour")
local EscapeCheck = MakeCheck("Escape closes the menu",
    "Turn this off to keep the menu on screen when you press Escape.",
    function()
        EmoteMenu.EscapeCloses = (EmoteMenu.EscapeCloses == "On") and "Off" or "On"
        SetEscapeCloses(EmoteMenu.EscapeCloses == "On")
        EmoteMenu:RefreshOptions()
    end)
local MinimapCheck = MakeCheck("Show the minimap icon",
    "With this off, reach the menu with /emotemenu or /emm.",
    function()
        EmoteMenu.ShowMinimapIcon = (EmoteMenu.ShowMinimapIcon == "On")
            and "Off" or "On"
        if EmoteMenu.SetMinimapIconShown then
            EmoteMenu:SetMinimapIconShown()
        end
        EmoteMenu:RefreshOptions()
    end)
Place(EscapeCheck, 8, 16, 4)
Place(MinimapCheck, 8, 16, 14)

-- Everything the options panel and the mouse between them can leave in a state
-- worth backing out of: size, position, appearance. Not the tabs -- those are
-- work someone did by hand, and wiping them from a button labelled "reset"
-- would be a nasty surprise.
local function ResetToDefaults()
    EmoteMenu.ButtonW, EmoteMenu.ButtonH = BUTTON_WIDTH, BUTTON_HEIGHT
    EmoteMenu.FontSize = DEFAULT_FONT_SIZE
    EmoteMenu.SortOrder = "across"
    EmoteMenu.EscapeCloses = "On"
    EmoteMenu.ShowMinimapIcon = "On"
    EmoteMenu.PanelW, EmoteMenu.PanelH = DEFAULT_WIDTH, DEFAULT_HEIGHT
    EmoteMenu.MainPanelA, EmoteMenu.MainPanelR = "CENTER", "CENTER"
    EmoteMenu.MainPanelX, EmoteMenu.MainPanelY = 0, 0

    SetEscapeCloses(true)
    ApplyFontSize()
    if EmoteMenu.SetMinimapIconShown then EmoteMenu:SetMinimapIconShown() end
    PageF:ClearAllPoints()
    PageF:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    PageF:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    ApplyButtonSize()
    EmoteMenu:RefreshOptions()
end
EmoteMenu.ResetToDefaults = ResetToDefaults

local ResetButton = CreateFrame("Button", nil, Options, "UIPanelButtonTemplate")
ResetButton:SetSize(140, 22)
ResetButton:SetPoint("BOTTOMLEFT", OPT_PAD, 14)
ResetButton:SetText("Reset to defaults")
ResetButton:SetScript("OnClick", function()
    ShowPrompt({
        title = "Reset to defaults",
        accept = "Reset",
        body = "Put the panel size, position and appearance back the way they "
            .. "shipped? Your tabs and favourites are not affected.",
        onAccept = function() ResetToDefaults() end,
    })
end)

local OptDone = CreateFrame("Button", nil, Options, "UIPanelButtonTemplate")
OptDone:SetSize(100, 22)
OptDone:SetPoint("BOTTOMRIGHT", -OPT_PAD, 14)
OptDone:SetText("Close")
OptDone:SetScript("OnClick", function() Options:Hide() end)

-- The controls stack downwards from the title, so the frame is as tall as they
-- turned out to be plus room for the buttons along the bottom.
Options:SetHeight(-optY + 44)

-- Every control reads its state from EmoteMenu rather than keeping its own, so
-- one function puts the whole panel back in step -- after a click, after a
-- reset, and whenever it is opened.
function EmoteMenu:RefreshOptions()
    SortAcross.tick:SetShown(self.SortOrder ~= "down")
    SortDown.tick:SetShown(self.SortOrder == "down")
    EscapeCheck.tick:SetShown(self.EscapeCloses == "On")
    MinimapCheck.tick:SetShown(self.ShowMinimapIcon == "On")
    WidthSlider:Set(self.ButtonW)
    HeightSlider:Set(self.ButtonH)
    FontSlider:Set(self.FontSize)
end

Options:SetScript("OnShow", function() EmoteMenu:RefreshOptions() end)

-- Reachable without the menu being open, because the minimap icon offers it on
-- a right-click and the panel it normally lives on may well be closed.
function EmoteMenu:ShowOptions()
    Options:Show()
    Options:Raise()
end

-- The cog itself. Left of the close button, and small: the title row is also
-- the drag handle, so anything up there has to stay out of the way.
local OptionsButton = CreateFrame("Button", nil, PageF)
OptionsButton:SetSize(16, 16)
OptionsButton:SetPoint("TOPRIGHT", -40, -8)
OptionsButton:SetNormalTexture(TEXTURE_PATH .. "cog.tga")
OptionsButton:SetHighlightTexture(TEXTURE_PATH .. "cog.tga")
-- Dimmed until the mouse is on it, where the additive highlight brings it
-- back up to full white.
local cogTexture = OptionsButton:GetNormalTexture()
if cogTexture then cogTexture:SetVertexColor(0.75, 0.75, 0.75, 1) end
OptionsButton:SetScript("OnClick", function()
    if Options:IsShown() then Options:Hide() else Options:Show() end
end)
AddTip(OptionsButton, "Options", "Sort order, button size and a few switches.")
EmoteMenu.OptionsButton = OptionsButton

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

    -- Only build buttons for emotes this client actually has. The addon ships
    -- one data file for every flavour, and an older one simply does not know
    -- the newer emotes -- a button that can never do anything is worse than a
    -- missing one.
    --
    -- Listing an emote is not the same as implementing it: the Forever beta
    -- declares huzzah, wince and the rest of the newest block while doing
    -- nothing with them. Those were measured during the capture, so they are
    -- hidden on that flavour and left alone everywhere else, where they work.
    local unimplemented = {}
    local known = core.unimplemented
    if known and known.emotes then
        local _, _, _, interface = GetBuildInfo()
        -- Same flavour, any patch of it: 16001 and 16002 are both Forever,
        -- while 11509 and 120100 are not.
        if interface and math.floor(interface / 1000) == math.floor(known.interface / 1000) then
            unimplemented = known.emotes
        end
    end

    local declared = {}
    for i = 1, (_G.MAXEMOTEINDEX or 1000) do
        local token = _G["EMOTE" .. i .. "_TOKEN"]
        if token then declared[token:lower()] = true end
    end
    -- If the globals are missing entirely, show everything rather than nothing.
    local haveTokenList = next(declared) ~= nil

    local i = 0
    for _, entry in ipairs(core.emoteTable) do
        local available = (not haveTokenList or declared[entry.emote]
            or entry.serverOnly) and not unimplemented[entry.emote]
        if available then
        i = i + 1
        local emoteString = entry.emote

        -- Parented to the scroll child, not the panel, so they scroll with it.
        -- Positions are left to Reflow(), which depends on the current width.
        local eBtn = CreateFrame("Button", nil, ScrollChild, "UIPanelButtonTemplate")
        if ButtonFont then
            eBtn:SetNormalFontObject(ButtonFont)
            eBtn:SetHighlightFontObject(ButtonFontHigh or ButtonFont)
            eBtn:SetDisabledFontObject(ButtonFont)
        else
            eBtn:SetNormalFontObject("GameFontNormalSmall")
        end
        eBtn:SetSize(EmoteMenu.ButtonW, EmoteMenu.ButtonH)
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
            .. CommandNote(entry)
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
end

-- Reflow while the grip is dragged. Guarded on the buttons existing because
-- this also fires during the SetSize call at load, long before that.
PageF:SetScript("OnSizeChanged", function()
    if not buttonsBuilt then return end
    -- A narrower panel may push tabs onto another row, which moves
    -- everything below them.
    LayoutTabs()
    Reflow(true)
end)

-- Restore size and position, then build and lay out the contents
PageF:SetScript("OnHide", function()
    CommitRename()
    EditMode = false
    CloseContextMenu()
    Options:Hide()
end)

PageF:SetScript("OnShow", function(self)
    self:SetSize(EmoteMenu.PanelW, EmoteMenu.PanelH)
    self:ClearAllPoints()
    self:SetPoint(EmoteMenu.MainPanelA, UIParent, EmoteMenu.MainPanelR, EmoteMenu.MainPanelX, EmoteMenu.MainPanelY)
    BuildEmoteButtons()
    ActiveTab = sessionTab or EmoteMenu.DefaultTab or "all"
    EditMode = false
    if not TabById(ActiveTab) then ActiveTab = "all" end
    RebuildTabStrip()
    -- Reapply rather than Reflow: this rebuilds the visible set (which is
    -- empty on the very first show) and forces a full relayout, which also
    -- covers a height change that leaves the column count alone.
    RefreshTabs()
    LayoutTabs()
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
        OnClick = function(_, button)
            if button == "RightButton" then
                EmoteMenu:ShowOptions()
            else
                EmoteMenu:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("Emote Menu")
            tooltip:AddLine("Left-click to open, right-click for options.",
                0.8, 0.8, 0.8)
        end,
    })

    -- NewDataObject returns nil when something already claimed the name, which
    -- happens when two copies of this addon are installed at once -- easy to do
    -- while the folder is being renamed, since WoW leaves the old one behind.
    -- Passing that nil to Register throws, so say something useful instead.
    if not dataObject then
        print("|cff66ccffEmote Menu|r: another copy of this addon is already "
            .. "loaded, so this one is not adding a minimap icon. Check "
            .. "Interface/AddOns for an older folder such as wowEmoteMenu-main "
            .. "and delete it.")
        return
    end

    local minimap = MigrateMinimapSettings()
    icon:Register("Emote_Menu", dataObject, minimap)

    -- The options panel calls this again whenever the setting is changed.
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
-- Key binding
----------------------------------------------------------------------
-- Bindings.xml runs its body in the global environment, so the one global
-- this addon deliberately creates is here. It is prefixed for the same reason
-- every other name is: a bare Toggle() in _G would be asking for a collision.
--
-- The label the game's Key Bindings panel shows, looked up from the binding
-- name in Bindings.xml. It has to match exactly, which the test suite checks,
-- because a mismatch shows up as a raw key or a blank row rather than an error.
_G.BINDING_NAME_EMOTEMENU_TOGGLE = "Open Emote Menu"

-- Why Bindings.xml is six lines with nothing in it:
--
-- WoW's XML is validated against a schema and it does not skip what it does
-- not recognise -- it throws out the element. 1.1.0 shipped a category
-- attribute there, hoping to file the row under AddOns rather than Other, and
-- got "Unrecognized XML: Binding" on login with no binding at all. Do not add
-- an attribute to that file that has not been seen working in game.
--
-- The rewrite that removed it failed too, this time reporting the name
-- attribute as unrecognised -- an attribute Prat uses on this same client
-- without complaint. What that rewrite also had, and the version that worked
-- did not, was a blank line inside a long XML comment. Rather than establish
-- exactly which part the parser dislikes, that file now matches the shape of
-- one known to load here: tabs, CRLF, one short comment on a single line, and
-- a name. Everything worth saying is said in this comment instead, where the
-- worst a parser can do about it is nothing.
--
-- A header is also deliberately absent. One rendered as the literal string
-- HEADER_EMOTEMENU: the panel looks a header's display name up as
-- BINDING_NAME_HEADER_ plus the header name, not the BINDING_HEADER_ form
-- every addon guide says to define, so the lookup missed and it printed the
-- raw key. One binding does not need a heading over it anyway.

function _G.EmoteMenu_Toggle()
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
        -- Appearance
        EmoteMenu:LoadVarNum("ButtonW", BUTTON_WIDTH, MIN_BUTTON_W, MAX_BUTTON_W)
        EmoteMenu:LoadVarNum("ButtonH", BUTTON_HEIGHT, MIN_BUTTON_H, MAX_BUTTON_H)
        EmoteMenu:LoadVarNum("FontSize", DEFAULT_FONT_SIZE, MIN_FONT_SIZE, MAX_FONT_SIZE)
        ApplyFontSize()
        EmoteMenu:LoadVarSet("SortOrder", "across", VALID_SORTS)
        EmoteMenu:LoadVarChk("EscapeCloses", "On")
        SetEscapeCloses(EmoteMenu.EscapeCloses == "On")
        UpdateResizeLimits()
        -- Falls back to All if the stored tab has since been deleted.
        local wanted = EmoteMenuDB.DefaultTab
        EmoteMenu.DefaultTab = (type(wanted) == "string" and TabById(wanted))
            and wanted or "all"

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
        EmoteMenuDB.ButtonW = EmoteMenu.ButtonW
        EmoteMenuDB.ButtonH = EmoteMenu.ButtonH
        EmoteMenuDB.FontSize = EmoteMenu.FontSize
        EmoteMenuDB.SortOrder = EmoteMenu.SortOrder
        EmoteMenuDB.EscapeCloses = EmoteMenu.EscapeCloses
        EmoteMenuDB.DefaultTab = EmoteMenu.DefaultTab
        EmoteMenuDB[SETTINGS_MARKER] = time and time() or 1
    end
end)
