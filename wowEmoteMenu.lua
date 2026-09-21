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
-- Main frame
----------------------------------------------------------------------
local DEFAULT_COLUMNS = 10
local DEFAULT_HEIGHT = 540

local BUTTON_WIDTH = 85
local BUTTON_HEIGHT = 18

local MARGIN_LEFT = 10          -- gap between the panel edge and the grid
local MARGIN_BOTTOM = 10
local CONTENT_TOP = 60          -- room for the title and version text
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

EmoteMenu.PanelW = DEFAULT_WIDTH
EmoteMenu.PanelH = DEFAULT_HEIGHT

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
PageF.mt:SetPoint("TOPLEFT", 16, -16)
PageF.mt:SetText("Emote Menu")

-- Add version text
PageF.v = PageF:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
PageF.v:SetHeight(32)
PageF.v:SetPoint("TOPLEFT", PageF.mt, "BOTTOMLEFT", 0, -8)
PageF.v:SetJustifyH("LEFT")
PageF.v:SetJustifyV("TOP")
PageF.v:SetNonSpaceWrap(true)
PageF.v:SetText("v" .. addonVersion)

-- Add close button
local CloseB = CreateFrame("Button", nil, PageF, "UIPanelCloseButton")
CloseB:SetSize(30, 30)
CloseB:SetPoint("TOPRIGHT", 0, 0)

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

local buttons = {}
local layoutColumns = 0

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
local function Reflow()
    if #buttons == 0 then return end

    local viewportWidth = ScrollF:GetWidth()
    local columns, rows = ComputeGrid(viewportWidth, #buttons)

    if columns ~= layoutColumns then
        layoutColumns = columns
        for i, button in ipairs(buttons) do
            local column = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", column * BUTTON_WIDTH, -row * BUTTON_HEIGHT)
        end
        ScrollChild:SetSize(columns * BUTTON_WIDTH, rows * BUTTON_HEIGHT)
    end

    UpdateScrollRange()
end
EmoteMenu.Reflow = Reflow

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
        buttons[i] = eBtn

        -- An empty targetText means the emote ignores the target, so force no
        -- target rather than letting the server silently drop it.
        local ignoresTarget = entry.targetText == ""
        eBtn.tiptext = BuildTooltip(entry)
        if ignoresTarget then
            eBtn:SetScript("OnClick", function()
                DoEmote(emoteString, "none")
            end)
        else
            eBtn:SetScript("OnClick", function()
                DoEmote(emoteString)
            end)
        end

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
PageF:SetScript("OnShow", function(self)
    self:SetSize(EmoteMenu.PanelW, EmoteMenu.PanelH)
    self:ClearAllPoints()
    self:SetPoint(EmoteMenu.MainPanelA, UIParent, EmoteMenu.MainPanelR, EmoteMenu.MainPanelX, EmoteMenu.MainPanelY)
    BuildEmoteButtons()
    -- Force a pass: the column count may be unchanged from last time while the
    -- height, and so the scroll range, is not.
    layoutColumns = 0
    Reflow()
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
    end
end)
