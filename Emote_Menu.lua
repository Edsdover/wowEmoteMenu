-- Create global table
_G.EmoteMenuDB = _G.EmoteMenuDB or {}

local addonName, core = ...;
local EmoteMenu = {};
core.UIConfig = {};
local UIConfig = core.UIConfig;

EmoteMenu["AddonVer"] = "1.0.0"
----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
function UIConfig:CreateMiniMapIcon()
    do
        -- Minimap button click function
        local function MiniBtnClickFunc(arg1)
            if EmoteMenu:IsMapsShowing() then
                EmoteMenu["PageF"]:Hide()
            else
                EmoteMenu["PageF"]:Show()
            end
        end

        -- Create minimap button using LibDBIcon
        local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("Emote_Menu", {
            type = "data source",
            text = "Emote Menu",
            icon = "Interface\\Icons\\ability_seal",
            OnClick = function(self, btn)
                MiniBtnClickFunc(btn)
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                tooltip:AddLine("Emote Menu")
            end,
        })

        -- TODO: Function to toggle Minimap Icon - add after UI option added
        local icon = LibStub("LibDBIcon-1.0", true)
        icon:Register("Emote_Menu", miniButton, EmoteMenuDB)

        local function SetLibDBIconFunc()
            if EmoteMenu["ShowMinimapIcon"] == "On" then
                EmoteMenuDB["hide"] = false
                icon:Show("Emote_Menu")
            else
                EmoteMenuDB["hide"] = true
                icon:Hide("Emote_Menu")
            end
        end

        -- TODO: Set Minimap Icon when option is clicked
      --   EmoteMenu["ShowMinimapIcon"]:HookScript("OnClick", SetLibDBIconFunc)
        -- Set Minimap Icon on Startup
        SetLibDBIconFunc()
    end
end

-- Add slash commands
_G.SLASH_Emote_Menu1 = "/emote"
SlashCmdList["Emote_Menu"] = function(self)
   if EmoteMenu:IsMapsShowing() then
      EmoteMenu["PageF"]:Hide()
  else
      EmoteMenu["PageF"]:Show()
  end
end

-- Call main functions when addon is loaded
local dbLoader = CreateFrame("Frame");
dbLoader:RegisterEvent("ADDON_LOADED");
dbLoader:RegisterEvent("PLAYER_LOGOUT")

function dbLoader:OnEvent(event, arg1)
    if (event == "ADDON_LOADED" and arg1 == "Emote_Menu") then
        -- Load init values if none in DB
        EmoteMenu:LoadVarChk("ShowMinimapIcon", "On");
        EmoteMenu:LoadVarAnc("MapPosA", "CENTER")					-- Map anchor
        EmoteMenu:LoadVarAnc("MapPosR", "CENTER")					-- Map relative 
        -- Panel Pos
        EmoteMenu:LoadVarAnc("MainPanelA", "CENTER")				-- Panel anchor
        EmoteMenu:LoadVarAnc("MainPanelR", "CENTER")				-- Panel relative
        EmoteMenu:LoadVarNum("MainPanelX", 0, -5000, 5000)			-- Panel X axis
        EmoteMenu:LoadVarNum("MainPanelY", 0, -5000, 5000)			-- Panel Y axis
        -- Set init minimum button position
        if not EmoteMenuDB["minimapPos"] then
            EmoteMenuDB["minimapPos"] = 204
        end
        -- Set minimap button
        UIConfig:CreateMiniMapIcon();

    elseif event == "PLAYER_LOGOUT" then
        -- Save current settings to DB
        EmoteMenuDB["ShowMinimapIcon"] = EmoteMenu["ShowMinimapIcon"]
        EmoteMenuDB["MapPosA"] = EmoteMenu["MapPosA"]
        EmoteMenuDB["MapPosR"] = EmoteMenu["MapPosR"]
        -- Panel Pos
        EmoteMenuDB["MainPanelA"] = EmoteMenu["MainPanelA"]
        EmoteMenuDB["MainPanelR"] = EmoteMenu["MainPanelR"]
        EmoteMenuDB["MainPanelX"] = EmoteMenu["MainPanelX"]
        EmoteMenuDB["MainPanelY"] = EmoteMenu["MainPanelY"]
    end
end

dbLoader:SetScript("OnEvent", dbLoader.OnEvent);

----------------------------------------------------------------------
-- Functions
----------------------------------------------------------------------
-- Find out if Emote Menu is showing
function EmoteMenu:IsMapsShowing()
    if EmoteMenu["PageF"]:IsShown() then return true end
end
-- Load a string-bool variable and set it to default if it's not in store
function EmoteMenu:LoadVarChk(var, def)
   if EmoteMenuDB[var] and type(EmoteMenuDB[var]) == "string" and EmoteMenuDB[var] == "On" or EmoteMenuDB[var] == "Off" then
       EmoteMenu[var] = EmoteMenuDB[var]
   else
       EmoteMenu[var] = def
       EmoteMenuDB[var] = def
   end
end

-- Load a numeric variable and set it to default if it's not within a given range
function EmoteMenu:LoadVarNum(var, def, valmin, valmax)
   if EmoteMenuDB[var] and type(EmoteMenuDB[var]) == "number" and EmoteMenuDB[var] >= valmin and EmoteMenuDB[var] <= valmax then
       EmoteMenu[var] = EmoteMenuDB[var]
   else
       EmoteMenu[var] = def
       EmoteMenuDB[var] = def
   end
end

-- Load an anchor point variable and set it to default if the anchor point is invalid
function EmoteMenu:LoadVarAnc(var, def)
   if EmoteMenuDB[var] and type(EmoteMenuDB[var]) == "string" and EmoteMenuDB[var] == "CENTER" or EmoteMenuDB[var] == "TOP" or EmoteMenuDB[var] == "BOTTOM" or EmoteMenuDB[var] == "LEFT" or EmoteMenuDB[var] == "RIGHT" or EmoteMenuDB[var] == "TOPLEFT" or EmoteMenuDB[var] == "TOPRIGHT" or EmoteMenuDB[var] == "BOTTOMLEFT" or EmoteMenuDB[var] == "BOTTOMRIGHT" then
       EmoteMenu[var] = EmoteMenuDB[var]
   else
       EmoteMenu[var] = def
       EmoteMenuDB[var] = def
   end
end

-- Show tooltips for configuration buttons and dropdown menus
function EmoteMenu:ShowTooltip()
   GameTooltip:SetOwner(self)
   local parent = self:GetParent()
   local pscale = parent:GetEffectiveScale()
   local gscale = UIParent:GetEffectiveScale()
   local tscale = GameTooltip:GetEffectiveScale()
   local gap = ((UIParent:GetRight() * gscale) - (EmoteMenu["PageF"]:GetRight() * pscale))
   if gap < (250 * tscale) then
      GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
   else
      GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
   end
   GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
end

----------------------------------------------------------------------
-- Main Frame
----------------------------------------------------------------------
local frameWidth = 870
local frameHeight = 540

local PageF = CreateFrame("Frame", nil, UIParent)

-- Make it a system frame
_G["EmoteMenu"] = PageF
table.insert(UISpecialFrames, "EmoteMenu")

-- Set frame parameters
EmoteMenu["PageF"] = PageF
PageF:SetSize(frameWidth, frameHeight)
PageF:Hide()
PageF:SetFrameStrata("HIGH")
PageF:SetClampedToScreen(true)
PageF:EnableMouse(true)
PageF:SetMovable(true)
PageF:RegisterForDrag("LeftButton")
PageF:SetScript("OnDragStart", PageF.StartMoving)
PageF:SetScript("OnDragStop", function()
    PageF:StopMovingOrSizing()
    PageF:SetUserPlaced(false)
    -- Save panel position
    EmoteMenu["MainPanelA"], void, EmoteMenu["MainPanelR"], EmoteMenu["MainPanelX"], EmoteMenu["MainPanelY"] = PageF:GetPoint()
end)

-- Add background color
PageF.t = PageF:CreateTexture(nil, "BACKGROUND")
PageF.t:SetAllPoints()
PageF.t:SetColorTexture(0.05, 0.05, 0.05, 0.9)

-- Set panel position when shown
PageF:SetScript("OnShow", function()
    PageF:ClearAllPoints()
    PageF:SetPoint(EmoteMenu["MainPanelA"], UIParent, EmoteMenu["MainPanelR"], EmoteMenu["MainPanelX"], EmoteMenu["MainPanelY"])
end)
-- Add main title
PageF.mt = PageF:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
PageF.mt:SetPoint('TOPLEFT', 16, -16)
PageF.mt:SetText("Emote Menu")

-- Add version text
PageF.v = PageF:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
PageF.v:SetHeight(32)
PageF.v:SetPoint('TOPLEFT', PageF.mt, 'BOTTOMLEFT', 0, -8)
PageF.v:SetJustifyH('LEFT'); PageF.v:SetJustifyV('TOP')
PageF.v:SetNonSpaceWrap(true); PageF.v:SetText("Classic" .. " " .. EmoteMenu["AddonVer"])

-- Add close Button
local CloseB = CreateFrame("Button", nil, PageF, "UIPanelCloseButton")
CloseB:SetSize(30, 30)
CloseB:SetPoint("TOPRIGHT", 0, 0)

-- TODO: Add sorting function
local sortedList = emoteTable

-- Generate emote buttons from object
for i,v in pairs(sortedList) do
    local buttonWidth = 85
    local buttonHeight = 18
    local numButtonsInRow = 10
    local marginLeft = 10
    local initMarginTop = 60

    local btnPosX = buttonWidth*((i-1)%numButtonsInRow)+marginLeft -- reset x pos every ten buttons in row
    local btnPosY = -buttonHeight*(math.floor ((i-1)/numButtonsInRow))-initMarginTop -- increment y pos every ten buttons
    local emoteString = sortedList[i]["emote"]
    local eBtn = CreateFrame("Button", nil, PageF, "UIPanelButtonTemplate")

    eBtn:SetNormalFontObject("GameFontNormalSmall");
    local font = eBtn:GetNormalFontObject();
    eBtn:SetNormalFontObject(font);
    eBtn:SetPoint('TOPLEFT', btnPosX, btnPosY)
    eBtn:SetText(emoteString)
    eBtn:SetWidth(buttonWidth)
    eBtn:SetHeight(buttonHeight)

    -- Some emotes do not have target text. In that case we force target self and adjust tooltip
    if sortedList[i]["targetText"] == "" then
        eBtn.tiptext = sortedList[i]["noTargetText"]
        eBtn:SetScript("OnClick", function(self, button, down)
            DoEmote(emoteString, "none")
        end)
    else
        eBtn.tiptext = sortedList[i]["noTargetText"] .. "|n|n|cff00AAFF" .. sortedList[i]["targetText"]
        eBtn:SetScript("OnClick", function(self, button, down)
            DoEmote(emoteString)
        end)
    end
    eBtn:SetScript("OnEnter", EmoteMenu.ShowTooltip)
    eBtn:SetScript("OnLeave", GameTooltip_Hide)
end
