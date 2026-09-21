-- Minimal WoW API stub, enough to load and exercise the Emote Menu addon.
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.WOW_PROJECT_ID = 2
_G.WOW_PROJECT_MAINLINE = 1
_G.WOW_PROJECT_CLASSIC = 2

_G.__emotes = {}
function _G.DoEmote(token, target)
    assert(type(token) == "string", "DoEmote got non-string token")
    table.insert(_G.__emotes, { token = token, target = target })
end

_G.__tooltipText = nil
_G.GameTooltip = {
    SetOwner = function(self, owner, anchor)
        assert(owner ~= nil, "GameTooltip:SetOwner called with nil owner")
        assert(anchor ~= nil, "GameTooltip:SetOwner called with no anchor argument")
        self.owner = owner
    end,
    SetPoint = function() end,
    ClearAllPoints = function() end,
    GetEffectiveScale = function() return 1 end,
    SetText = function(self, text)
        assert(type(text) == "string", "GameTooltip:SetText got " .. type(text))
        _G.__tooltipText = text
    end,
    AddLine = function() end,
    Hide = function() end,
}
function _G.GameTooltip_Hide() end

_G.__frames = {}

-- Frame -------------------------------------------------------------------
local frameMeta = {}

-- Unknown widget methods become recorded no-ops so vendor libs can run;
-- everything the addon itself relies on is defined explicitly below.
_G.__autostubbed = {}
frameMeta.__index = function(tbl, key)
    local v = rawget(frameMeta, key)
    if v ~= nil then return v end
    if type(key) == "string" and key:match("^%u") then
        _G.__autostubbed[key] = (_G.__autostubbed[key] or 0) + 1
        local fn = function() end
        rawset(frameMeta, key, fn)
        return fn
    end
    return nil
end

local function stubMethods(t, names)
    for _, n in ipairs(names) do
        if not rawget(t, n) then t[n] = function() end end
    end
end

function frameMeta:SetSize(w, h) self.w, self.h = w, h end
function frameMeta:SetWidth(w) self.w = w end
function frameMeta:SetHeight(h) self.h = h end

-- Real WoW derives a frame's size from its anchors when none is set
-- explicitly. The addon relies on that for the scroll viewport, so a
-- TOPLEFT + BOTTOMRIGHT pair has to produce a usable width and height.
function frameMeta:GetWidth()
    if self.w then return self.w end
    local tl, br = self.points.TOPLEFT, self.points.BOTTOMRIGHT
    if tl and br then
        local parent = tl.rel or self.parent
        if parent then return parent:GetWidth() + (br.x or 0) - (tl.x or 0) end
    end
    return 0
end

function frameMeta:GetHeight()
    if self.h then return self.h end
    local tl, br = self.points.TOPLEFT, self.points.BOTTOMRIGHT
    if tl and br then
        local parent = tl.rel or self.parent
        if parent then return parent:GetHeight() + (tl.y or 0) - (br.y or 0) end
    end
    return 0
end

function frameMeta:GetEffectiveScale() return 1 end
function frameMeta:GetRight() return 1000 end
function frameMeta:GetLeft() return 0 end
function frameMeta:IsShown() return self.shown == true end

function frameMeta:SetText(t)
    assert(type(t) == "string", "SetText got " .. type(t) .. " (nil label?)")
    self.text = t
    if self.frameType == "EditBox" and self.scripts.OnTextChanged then
        self.scripts.OnTextChanged(self, false)
    end
end
function frameMeta:GetText() return self.text or "" end
function frameMeta:SetShown(v) if v then self:Show() else self:Hide() end end
function frameMeta:IsVisible() return self.shown == true end

-- Both SetPoint(point, x, y) and SetPoint(point, rel, relPoint, x, y) are used.
function frameMeta:SetPoint(point, a, b, c, d)
    assert(point ~= nil, "SetPoint called with nil anchor point")
    local rel, relPoint, x, y
    if type(a) == "number" or a == nil then
        rel, relPoint, x, y = self.parent, point, a, b
    else
        rel, relPoint, x, y = a, b, c, d
    end
    self.points[point] = { rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
    self.point = { point, rel, relPoint, x, y }   -- legacy shape used by tests
end
function frameMeta:ClearAllPoints() self.points = {} end
function frameMeta:GetPoint() return "CENTER", _G.UIParent, "CENTER", 12, -34 end

function frameMeta:SetScript(name, fn) self.scripts[name] = fn end
function frameMeta:GetScript(name) return self.scripts[name] end
function frameMeta:HookScript(name, fn) self.scripts[name] = fn end
function frameMeta:RegisterEvent(e) self.events[e] = true end
function frameMeta:UnregisterEvent(e) self.events[e] = nil end
function frameMeta:IsEventRegistered(e) return self.events[e] == true end
function frameMeta:GetParent() return self.parent end
function frameMeta:GetName() return self.name end

-- Textures and font strings are registered alongside frames so tests can find
-- them; they start shown, as they do in the real client.
local function newRegion(parent, kind)
    local r = setmetatable({ frameType = kind, parent = parent, scripts = {},
                             events = {}, points = {}, shown = true }, frameMeta)
    table.insert(_G.__frames, r)
    return r
end
function frameMeta:CreateTexture() return newRegion(self, "Texture") end
function frameMeta:CreateFontString() return newRegion(self, "FontString") end
-- Buttons made from a template own a label; the addon re-anchors it so the
-- text cannot run under the markers, so it has to be a real region here.
function frameMeta:GetFontString()
    if not self.fontString then self.fontString = newRegion(self, "FontString") end
    return self.fontString
end

function frameMeta:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function frameMeta:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function frameMeta:Click(button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton", false) end
end
function frameMeta:Enter() if self.scripts.OnEnter then self.scripts.OnEnter(self) end end
function frameMeta:Leave() if self.scripts.OnLeave then self.scripts.OnLeave(self) end end
function frameMeta:Fire(event, ...)
    if self.events[event] and self.scripts.OnEvent then
        self.scripts.OnEvent(self, event, ...)
    end
end

-- Resizing: drive OnSizeChanged the way dragging the grip would.
function frameMeta:Resize(w, h)
    self:SetSize(w, h)
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, w, h) end
end
function frameMeta:SetResizable(v) self.resizable = v end
function frameMeta:SetResizeBounds(minW, minH, maxW, maxH)
    self.resizeBounds = { minW, minH, maxW, maxH }
end

-- ScrollFrame
function frameMeta:SetScrollChild(child) self.scrollChild = child end
function frameMeta:GetScrollChild() return self.scrollChild end
function frameMeta:SetVerticalScroll(v) self.vscroll = v end
function frameMeta:GetVerticalScroll() return self.vscroll or 0 end

-- EditBox
function frameMeta:SetAutoFocus(v) self.autoFocus = v end
function frameMeta:HasFocus() return self.focused == true end
function frameMeta:SetFocus() self.focused = true end
function frameMeta:ClearFocus()
    self.focused = false
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function frameMeta:SetTextInsets() end
function frameMeta:SetMaxLetters(n) self.maxLetters = n end
function frameMeta:SetFontObject() end
-- SetText on an EditBox fires OnTextChanged, which is what drives filtering.
function frameMeta:Type(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
end
function frameMeta:Escape()
    if self.scripts.OnEscapePressed then self.scripts.OnEscapePressed(self) end
end

-- Slider
function frameMeta:SetMinMaxValues(lo, hi) self.minVal, self.maxVal = lo, hi end
function frameMeta:GetMinMaxValues() return self.minVal or 0, self.maxVal or 0 end
function frameMeta:SetValue(v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function frameMeta:GetValue() return self.value or 0 end
function frameMeta:SetThumbTexture(t) self.thumb = t end
function frameMeta:GetThumbTexture() return self.thumb end

function frameMeta:MouseWheel(delta)
    if self.scripts.OnMouseWheel then self.scripts.OnMouseWheel(self, delta) end
end

stubMethods(frameMeta, {
    "SetAllPoints", "SetColorTexture", "SetTexture", "SetFrameStrata",
    "SetFrameLevel", "SetClampedToScreen", "EnableMouse", "SetMovable",
    "RegisterForDrag", "RegisterForClicks", "StartMoving", "StopMovingOrSizing",
    "StartSizing", "SetUserPlaced", "SetNormalFontObject", "SetHighlightFontObject",
    "SetJustifyH", "SetJustifyV", "SetNonSpaceWrap", "SetAlpha", "SetScale",
    "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture",
    "SetDisabledTexture", "GetNormalTexture", "SetParent", "Raise", "SetToplevel",
    "SetAttribute", "SetHitRectInsets", "EnableMouseWheel", "SetID",
    "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "SetTexCoord",
})

function _G.CreateFrame(frameType, name, parent, template)
    local f = setmetatable({
        frameType = frameType, name = name, parent = parent, template = template,
        scripts = {}, events = {}, points = {}, shown = false,
    }, frameMeta)
    if name then _G[name] = f end
    table.insert(_G.__frames, f)
    return f
end

_G.UIParent = CreateFrame("Frame", "UIParent")
_G.UIParent:SetSize(1920, 1080)
_G.UIParent.shown = true
_G.Minimap = CreateFrame("Frame", "Minimap")
_G.Minimap:SetSize(140, 140)
_G.Minimap.shown = true
_G.MinimapCluster = CreateFrame("Frame", "MinimapCluster")

function _G.GetMinimapShape() return "ROUND" end
function _G.GetCursorPosition() return 0, 0 end
function _G.GetBuildInfo() return "1.60.1", "69913", "Sep 17 2026", 16001 end
function _G.UnitFactionGroup() return "Alliance" end
function _G.InCombatLockdown() return false end
function _G.issecure() return false end
function _G.securecallfunction(f, ...) return f(...) end
_G.C_Timer = { After = function(_, fn) if fn then fn() end end }
_G.C_AddOns = {
    GetAddOnMetadata = function(_, field)
        return ({ Version = "1.0.0", Title = "Emote Menu" })[field]
    end,
}
-- WoW globals that are not part of standard Lua.
function _G.wipe(t) for k in pairs(t) do t[k] = nil end return t end
_G.table.wipe = _G.wipe
function _G.strsplit(sep, str) return str end
_G.hooksecurefunc = function() end
_G.geterrorhandler = function() return function(e) error(e, 0) end end
