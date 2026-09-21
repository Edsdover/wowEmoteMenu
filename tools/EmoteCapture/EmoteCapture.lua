-- Temporary tool. Delete once the emote data has been regenerated.
--
-- Walks every emote token the CLIENT knows about (EMOTE<n>_TOKEN, which is the
-- authoritative list for whatever build is running), performs each one with and
-- without a target, and records exactly what the server prints back.
--
-- Why this rather than hand-checking: the emote list and its wording differ
-- between builds -- Forever has made at least /spit untargetable -- so data
-- derived from retail cannot be trusted here.
--
-- The first run showed the server rate-limits emotes: a contiguous block in the
-- middle produced no text at all, then it recovered. So this version goes
-- slower, backs off when replies stop arriving, and retries anything it missed
-- before giving up on it.
--
-- Results already collected are loaded from Captured.lua, which is a normal
-- addon file. SavedVariables are written correctly on this build but never read
-- back, so a resumed run cannot recover its own earlier output any other way.

local addonName = ...

local STEP_SECONDS = 2.5     -- 0.4 hit the rate limit; 1.0 lost slow replies
local BACKOFF_AFTER = 999    -- disabled: the few left over are genuinely silent
local BACKOFF_SECONDS = 20
local MAX_PASSES = 1
local PROGRESS_EVERY = 10

local function say(fmt, ...)
    print("|cff66ccffEmoteCapture|r: " .. string.format(fmt, ...))
end

----------------------------------------------------------------------
-- Emote list, straight from the client
----------------------------------------------------------------------
local function CollectTokens()
    local maxIndex = _G.MAXEMOTEINDEX or 1000
    local tokens, seen = {}, {}
    for i = 1, maxIndex do
        local token = _G["EMOTE" .. i .. "_TOKEN"]
        -- Indices are not contiguous and "UNUSED" is a real placeholder value.
        if token and token ~= "UNUSED" and not seen[token] then
            seen[token] = true
            tokens[#tokens + 1] = { index = i, token = token, cmd = _G["EMOTE" .. i .. "_CMD1"] }
        end
    end
    return tokens
end

local function IsComplete(entry)
    return entry and entry.target and entry.noTarget
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local queue, queueIndex, pending, ticker = {}, 0, nil, nil
local misses, pass, paused = 0, 0, false

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")

local function Missing()
    local list = {}
    for token, entry in pairs(EmoteCaptureDB.emotes) do
        if not IsComplete(entry) then list[#list + 1] = token end
    end
    table.sort(list)
    return list
end

local function StopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function Report()
    local missing = Missing()
    local total, done = 0, 0
    for _ in pairs(EmoteCaptureDB.emotes) do total = total + 1 end
    done = total - #missing
    say("pass %d finished: |cff66ff66%d|r of %d complete, %d outstanding.",
        pass, done, total, #missing)
    return missing
end

local RunPass   -- forward declaration

local function Step()
    if paused then return end

    queueIndex = queueIndex + 1
    local job = queue[queueIndex]

    if not job then
        StopTicker()
        local missing = Report()
        if #missing > 0 and pass < MAX_PASSES then
            say("retrying %d in %d seconds...", #missing, BACKOFF_SECONDS)
            C_Timer.After(BACKOFF_SECONDS, function() RunPass(missing) end)
        else
            EmoteCaptureDB.complete = true
            EmoteCaptureDB.finishedAt = date("%Y-%m-%d %H:%M:%S")
            if #missing > 0 then
                say("giving up on %d after %d passes: %s", #missing, pass,
                    table.concat(missing, ", "))
            end
            say("|cffffff00Done. Log out or /reload so the file is written.|r")
        end
        return
    end

    if queueIndex % PROGRESS_EVERY == 0 then
        say("%d / %d ...", queueIndex, #queue)
    end

    -- Skip anything a retry pass already filled in.
    local entry = EmoteCaptureDB.emotes[job.token]
    if (job.withTarget and entry.target) or (not job.withTarget and entry.noTarget) then
        return
    end

    pending = job
    local ok = pcall(DoEmote, job.token, (not job.withTarget) and "none" or nil)
    if not ok then pending = nil end
end

-- A silence usually means the rate limit has kicked in rather than that the
-- emote does not exist, so pause and let it clear rather than burning through
-- the rest of the list getting nothing.
local function NoteMiss()
    misses = misses + 1
    if misses >= BACKOFF_AFTER and not paused then
        paused = true
        say("|cffffaa00no replies for %d emotes -- pausing %ds for the rate limit|r",
            misses, BACKOFF_SECONDS)
        C_Timer.After(BACKOFF_SECONDS, function()
            paused, misses = false, 0
            say("resuming.")
        end)
    end
end

function RunPass(tokens)
    pass = pass + 1
    queue, queueIndex, misses, paused = {}, 0, 0, false
    for _, token in ipairs(tokens) do
        local entry = EmoteCaptureDB.emotes[token]
        if not entry.target   then queue[#queue + 1] = { token = token, withTarget = true } end
        if not entry.noTarget then queue[#queue + 1] = { token = token, withTarget = false } end
    end
    say("pass %d: %d emotes to perform, about %d seconds.",
        pass, #queue, math.ceil(#queue * STEP_SECONDS))
    ticker = C_Timer.NewTicker(STEP_SECONDS, Step)
end

local function Start(resume)
    local targetName = UnitName("target")
    if not targetName then
        say("|cffff6666Select a target first|r -- the targeted wording needs one.")
        return
    end

    local tokens = CollectTokens()
    if #tokens == 0 then
        say("|cffff6666No EMOTE*_TOKEN globals found.|r")
        return
    end

    EmoteCaptureDB = {
        build = { GetBuildInfo() },
        targetName = targetName,
        playerName = UnitName("player"),
        startedAt = date("%Y-%m-%d %H:%M:%S"),
        maxEmoteIndex = _G.MAXEMOTEINDEX,
        complete = false,
        emotes = {},
    }

    local carried = 0
    for _, t in ipairs(tokens) do
        local entry = { index = t.index, cmd = t.cmd }
        local prev = resume and EmoteCapturePrevious and EmoteCapturePrevious[t.token]
        -- Only reuse earlier results if they were captured against this same
        -- target name, otherwise the embedded name would not match.
        if prev and EmoteCapturePreviousTarget == targetName then
            entry.target = prev.target
            entry.noTarget = prev.noTarget
            if IsComplete(entry) then carried = carried + 1 end
        end
        EmoteCaptureDB.emotes[t.token] = entry
    end

    local missing = Missing()
    say("%d emotes known to this client.", #tokens)
    if resume then
        if EmoteCapturePreviousTarget and EmoteCapturePreviousTarget ~= targetName then
            say("|cffffaa00Previous run used target '%s' but yours is '%s' -- starting over.|r",
                tostring(EmoteCapturePreviousTarget), targetName)
        else
            say("carried %d complete entries from the previous run.", carried)
        end
    end
    say("Target is |cffffff00%s|r. Somewhere quiet is advised.", targetName)
    say("Stop early with |cffffff00/emotecapture stop|r.")
    pass = 0
    RunPass(missing)
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        if type(EmoteCaptureDB) ~= "table" then EmoteCaptureDB = {} end
        EmoteCaptureDB.emotes = EmoteCaptureDB.emotes or {}
        local prev = 0
        if EmoteCapturePrevious then
            for _ in pairs(EmoteCapturePrevious) do prev = prev + 1 end
        end
        say("ready (%d results carried forward). Target something, then run "
            .. "|cffffff00/emotecapture resume|r.", prev)
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        if not pending then return end
        local entry = EmoteCaptureDB.emotes[pending.token]
        if entry then
            if pending.withTarget then entry.target = arg1 else entry.noTarget = arg1 end
        end
        pending = nil
        misses = 0
    end
end)

_G.SLASH_EMOTECAPTURE1 = "/emotecapture"
SlashCmdList["EMOTECAPTURE"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "stop" then
        if ticker then
            StopTicker()
            say("stopped at %d / %d.", queueIndex, #queue)
            Report()
            say("Log out or /reload to write what you have.")
        else
            say("not running.")
        end
    elseif msg == "start" then
        if ticker then say("already running.") else Start(false) end
    elseif msg == "resume" then
        if ticker then say("already running.") else Start(true) end
    elseif msg == "status" then
        Report()
    else
        say("usage: /emotecapture resume | start | stop | status")
    end
end
