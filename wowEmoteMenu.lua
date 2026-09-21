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
local FRAME_WIDTH = 870
local FRAME_HEIGHT = 540

local BUTTON_WIDTH = 85
local BUTTON_HEIGHT = 18
local BUTTONS_PER_ROW = 10
local MARGIN_LEFT = 10
local MARGIN_TOP = 60

local PageF = CreateFrame("Frame", "EmoteMenuFrame", UIParent)
EmoteMenu.PageF = PageF

-- Register with the Escape-to-close list. UISpecialFrames looks the frame up
-- by name in _G, so the frame has to be named (it is, above).
table.insert(UISpecialFrames, "EmoteMenuFrame")

PageF:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
PageF:Hide()
PageF:SetFrameStrata("HIGH")
PageF:SetClampedToScreen(true)
PageF:EnableMouse(true)
PageF:SetMovable(true)
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
-- Emote buttons
----------------------------------------------------------------------
-- Show the tooltip for an emote button. Anchored to the panel rather than the
-- button, flipping to whichever side of the panel has room for it.
local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    local parent = self:GetParent()
    local pscale = parent:GetEffectiveScale()
    local gscale = UIParent:GetEffectiveScale()
    local tscale = GameTooltip:GetEffectiveScale()
    local gap = (UIParent:GetRight() * gscale) - (parent:GetRight() * pscale)
    if gap < (250 * tscale) then
        GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    end
    GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
end

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
        -- Reset x every BUTTONS_PER_ROW buttons, step y down one row
        local btnPosX = BUTTON_WIDTH * ((i - 1) % BUTTONS_PER_ROW) + MARGIN_LEFT
        local btnPosY = -BUTTON_HEIGHT * math.floor((i - 1) / BUTTONS_PER_ROW) - MARGIN_TOP

        local eBtn = CreateFrame("Button", nil, PageF, "UIPanelButtonTemplate")
        eBtn:SetNormalFontObject("GameFontNormalSmall")
        eBtn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        eBtn:SetPoint("TOPLEFT", btnPosX, btnPosY)
        eBtn:SetText(emoteString)

        -- Some emotes have no targeted form. Force no target and drop the
        -- second tooltip line for those.
        if entry.targetText == "" then
            eBtn.tiptext = entry.noTargetText
            eBtn:SetScript("OnClick", function()
                DoEmote(emoteString, "none")
            end)
        else
            eBtn.tiptext = entry.noTargetText .. "|n|n|cff00AAFF" .. entry.targetText
            eBtn:SetScript("OnClick", function()
                DoEmote(emoteString)
            end)
        end

        eBtn:SetScript("OnEnter", ShowTooltip)
        eBtn:SetScript("OnLeave", GameTooltip_Hide)
    end
end

-- Position the panel and build its contents when it is shown
PageF:SetScript("OnShow", function(self)
    BuildEmoteButtons()
    self:ClearAllPoints()
    self:SetPoint(EmoteMenu.MainPanelA, UIParent, EmoteMenu.MainPanelR, EmoteMenu.MainPanelX, EmoteMenu.MainPanelY)
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
    end
end)
