-- Temporary tool. Records which emotes play an animation and/or a sound.
--
-- Nothing in the client reports this: the server's chat text says nothing about
-- animations, and there is no API for "did a sound just play". Blizzard's own
-- EmoteList and TextEmoteSpeechList cover only the couple of dozen emotes shown
-- in its own menu, so they are a hint at best. That leaves watching and
-- listening, which is what this makes bearable -- one click per emote.
--
-- Deliberately click-driven rather than keyboard-driven: capturing keys in a
-- frame would swallow the movement keys for the whole session.
--
-- Results go to SavedVariables, which are written correctly on this build even
-- though they are never read back, so they are collected from the file
-- afterwards. Reviewed.lua carries earlier answers across a reload, because
-- addon files do load normally.

local addonName = ...

local AUTO_PLAY_GAP = 0.8   -- do not spam the server's emote rate limit

local function say(fmt, ...)
    print("|cff66ccffEmoteReview|r: " .. string.format(fmt, ...))
end

----------------------------------------------------------------------
-- Emote list
----------------------------------------------------------------------
-- The store is the source of truth for which emotes the menu actually shows;
-- reviewing anything else would be wasted effort.
local function CollectEmotes()
    local list = {}
    if EmoteReviewEmotes then
        for _, row in ipairs(EmoteReviewEmotes) do
            list[#list + 1] = { token = row[1], targetable = row[2] }
        end
        return list
    end
    local maxIndex = _G.MAXEMOTEINDEX or 1000
    local seen = {}
    for i = 1, maxIndex do
        local token = _G["EMOTE" .. i .. "_TOKEN"]
        if token and token ~= "UNUSED" and not seen[token] then
            seen[token] = true
            list[#list + 1] = { token = token:lower(), targetable = true }
        end
    end
    return list
end

-- Blizzard's own lists, shown as a hint only. They are not pre-selected: a
-- wrong default that someone clicks past is worse than no default.
local function BlizzardHint(token)
    local upper = token:upper()
    local anim, sound
    for _, v in ipairs(_G.EmoteList or {}) do
        if v == upper then anim = true break end
    end
    for _, v in ipairs(_G.TextEmoteSpeechList or {}) do
        if v == upper then sound = true break end
    end
    if anim and sound then return "Blizzard lists this as animated and voiced"
    elseif anim then return "Blizzard lists this as animated"
    elseif sound then return "Blizzard lists this as voiced"
    end
    return ""
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local emotes, index, lastPlayed = {}, 0, 0
local recheckMode = false

local function Remaining()
    local n = 0
    for _, e in ipairs(emotes) do
        if EmoteReviewDB.results[e.token] == nil then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
local Panel = CreateFrame("Frame", "EmoteReviewFrame", UIParent)
Panel:SetSize(340, 168)
Panel:SetPoint("CENTER", 0, 160)
Panel:SetFrameStrata("DIALOG")
Panel:EnableMouse(true)
Panel:SetMovable(true)
Panel:RegisterForDrag("LeftButton")
Panel:SetScript("OnDragStart", Panel.StartMoving)
Panel:SetScript("OnDragStop", Panel.StopMovingOrSizing)
Panel:Hide()
table.insert(UISpecialFrames, "EmoteReviewFrame")

Panel.bg = Panel:CreateTexture(nil, "BACKGROUND")
Panel.bg:SetAllPoints()
Panel.bg:SetColorTexture(0.05, 0.05, 0.05, 0.94)

Panel.progress = Panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
Panel.progress:SetPoint("TOPLEFT", 12, -10)

Panel.name = Panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
Panel.name:SetPoint("TOP", 0, -28)

Panel.hint = Panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
Panel.hint:SetPoint("TOP", Panel.name, "BOTTOM", 0, -4)

Panel.question = Panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
Panel.question:SetPoint("TOP", Panel.hint, "BOTTOM", 0, -6)
Panel.question:SetText("Did it play an animation, a sound, both, or neither?")

local function MakeButton(label, width, parent)
    local b = CreateFrame("Button", nil, parent or Panel, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(label)
    return b
end

local Record   -- forward declaration
local Show     -- forward declaration

local BtnNone  = MakeButton("Neither", 74)
local BtnAnim  = MakeButton("Animation", 74)
local BtnSound = MakeButton("Sound", 74)
local BtnBoth  = MakeButton("Both", 74)
BtnNone:SetPoint("BOTTOMLEFT", 12, 44)
BtnAnim:SetPoint("LEFT", BtnNone, "RIGHT", 6, 0)
BtnSound:SetPoint("LEFT", BtnAnim, "RIGHT", 6, 0)
BtnBoth:SetPoint("LEFT", BtnSound, "RIGHT", 6, 0)

local BtnReplay = MakeButton("Replay", 74)
local BtnBack   = MakeButton("Back", 74)
local BtnSkip   = MakeButton("Skip", 74)
local BtnQuit   = MakeButton("Finish", 74)
BtnReplay:SetPoint("BOTTOMLEFT", 12, 14)
BtnBack:SetPoint("LEFT", BtnReplay, "RIGHT", 6, 0)
BtnSkip:SetPoint("LEFT", BtnBack, "RIGHT", 6, 0)
BtnQuit:SetPoint("LEFT", BtnSkip, "RIGHT", 6, 0)

----------------------------------------------------------------------
-- Driving
----------------------------------------------------------------------
local function DoOne(e)
    -- Mirror the menu button: targetable emotes use the current target, the
    -- rest are forced to none. Reviewing the form the button will not use would
    -- record the wrong answer wherever the two differ.
    if e.targetable then
        pcall(DoEmote, e.token)
    else
        pcall(DoEmote, e.token, "none")
    end
end

-- dance, sit, sleep, laydown and kneel put the character into a state that
-- persists until something cancels it, and while it holds the next emote's
-- animation may never play. In recheck mode, cancel first and give the client a
-- moment before performing the real one.
local CANCEL_DELAY = 0.6
local function Perform()
    local e = emotes[index]
    if not e then return end
    local now = GetTime()
    if now - lastPlayed < AUTO_PLAY_GAP then return end
    lastPlayed = now

    if not recheckMode then
        DoOne(e)
        return
    end

    -- "stand" is the cancel, so it cannot clear itself: sit down first so
    -- standing up has something to undo.
    local clear = (e.token == "stand") and "sit" or "stand"
    pcall(DoEmote, clear, "none")
    C_Timer.After(CANCEL_DELAY, function()
        if emotes[index] == e then DoOne(e) end
    end)
end

function Show(newIndex, play)
    index = newIndex
    local e = emotes[index]
    if not e then
        Panel:Hide()
        EmoteReviewDB.finishedAt = date("%Y-%m-%d %H:%M:%S")
        say("finished. |cffffff00Log out or /reload|r to write the results.")
        return
    end

    local done = #emotes - Remaining()
    Panel.progress:SetText(("%d of %d reviewed  --  %d left")
        :format(done, #emotes, Remaining()))
    Panel.name:SetText(e.token .. (e.targetable and "" or "  |cff888888(no target)|r"))
    Panel.hint:SetText(BlizzardHint(e.token))

    local recorded = EmoteReviewDB.results[e.token]
    if recorded then
        Panel.question:SetText(("|cff888888already answered: %s|r")
            :format(recorded.animated and recorded.voiced and "both"
                or recorded.animated and "animation"
                or recorded.voiced and "sound" or "neither"))
    else
        Panel.question:SetText("Animation, sound, both, or neither?")
    end

    if play then Perform() end
end

function Record(animated, voiced)
    local e = emotes[index]
    if not e then return end
    EmoteReviewDB.results[e.token] = { animated = animated, voiced = voiced }
    Show(index + 1, true)
end

BtnNone:SetScript("OnClick",  function() Record(false, false) end)
BtnAnim:SetScript("OnClick",  function() Record(true, false) end)
BtnSound:SetScript("OnClick", function() Record(false, true) end)
BtnBoth:SetScript("OnClick",  function() Record(true, true) end)
BtnReplay:SetScript("OnClick", function() lastPlayed = 0 Perform() end)
BtnSkip:SetScript("OnClick",  function() Show(index + 1, true) end)
BtnBack:SetScript("OnClick",  function() Show(math.max(1, index - 1), true) end)
BtnQuit:SetScript("OnClick",  function()
    Panel:Hide()
    say("stopped at %d of %d. |cffffff00Log out or /reload|r to write results.", index, #emotes)
end)

----------------------------------------------------------------------
-- Load
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= addonName then return end
    if type(EmoteReviewDB) ~= "table" then EmoteReviewDB = {} end
    EmoteReviewDB.results = EmoteReviewDB.results or {}

    local carried = 0
    if EmoteReviewPrevious then
        for token, v in pairs(EmoteReviewPrevious) do
            if EmoteReviewDB.results[token] == nil then
                EmoteReviewDB.results[token] = { animated = v.animated, voiced = v.voiced }
                carried = carried + 1
            end
        end
    end
    say("ready (%d answers carried forward). Run |cffffff00/emotereview|r.", carried)
    self:UnregisterEvent("ADDON_LOADED")
end)

_G.SLASH_EMOTEREVIEW1 = "/emotereview"
SlashCmdList["EMOTEREVIEW"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    emotes = CollectEmotes()
    EmoteReviewDB.build = { GetBuildInfo() }
    EmoteReviewDB.startedAt = EmoteReviewDB.startedAt or date("%Y-%m-%d %H:%M:%S")

    if msg == "recheck" then
        -- Only the emotes a lingering animation may have hidden.
        local want = {}
        for _, t in ipairs(EmoteReviewSuspects or {}) do want[t] = true end
        local subset = {}
        for _, e in ipairs(emotes) do
            if want[e.token] then subset[#subset + 1] = e end
        end
        if #subset == 0 then
            say("no suspects listed.")
            return
        end
        emotes, recheckMode = subset, true
        say("rechecking %d emotes. Each is preceded by a cancel, so watch for the", #subset)
        say("SECOND animation -- the first is just standing up.")
        Panel:Show()
        Show(1, true)
        return
    end

    recheckMode = false
    if msg == "all" then
        say("reviewing all %d emotes.", #emotes)
        Panel:Show()
        Show(1, true)
        return
    end

    -- Default: pick up at the first unanswered emote.
    local start = 1
    for i, e in ipairs(emotes) do
        if EmoteReviewDB.results[e.token] == nil then start = i break end
    end
    if Remaining() == 0 then
        say("all %d already reviewed. Use |cffffff00/emotereview all|r to redo them.", #emotes)
        return
    end
    if not UnitName("target") then
        say("|cffffaa00No target selected.|r 236 of these are performed against a")
        say("target by the menu, so review them with one selected -- an NPC or a")
        say("dummy, not a player you would rather not spam.")
    end
    say("%d of %d left. Third-person view and sound on are advised.",
        Remaining(), #emotes)
    Panel:Show()
    Show(start, true)
end
