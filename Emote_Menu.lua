-- Namespaces

-- Create global table
_G.EmoteMenuDB = _G.EmoteMenuDB or {}

local addonName, core = ...;
local EmoteMenu = {};
core.UIConfig = {};
local UIConfig = core.UIConfig;

EmoteMenu["AddonVer"] = "1.0.0"

function UIConfig:CreateMenu()
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
        -- Set Minimap Icon when option is clicked and on startup
        EmoteMenu["ShowMinimapIcon"]:HookScript("OnClick", SetLibDBIconFunc)
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
        EmoteMenu:LoadVarChk("ShowMinimapIcon", "On")
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
        UIConfig:CreateMenu();

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

-- Find out if Emote Menu is showing
function EmoteMenu:IsMapsShowing()
    if EmoteMenu["PageF"]:IsShown() then return true end
end
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
local emoteTable = {
    {
       emote = "absent",
       noTargetText = "You look absent-minded.",
       targetText = "You look at %s absently.",
       animated = false,
       voiced = false,
    },
    {
        emote = "agree",
        noTargetText = "You agree.",
        targetText = "You agree with %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "amaze",
        noTargetText = "You are amazed!",
        targetText = "You look at %s absently.",
        animated = false,
        voiced = false,
     },
     {
        emote = "angry",
        noTargetText = "You raise your fist in anger.",
        targetText = "You raise your fist in anger at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "apologize",
        noTargetText = "You apologize to everyone. Sorry!",
        targetText = "You apologize to %s. Sorry!",
        animated = false,
        voiced = true,
     },
     {
        emote = "applaud",
        noTargetText = "You applaud. Bravo!",
        targetText = "You applaud at %s. Bravo!",
        animated = true,
        voiced = true,
     },
     {
        emote = "arm",
        noTargetText = "You stretch your arms out.",
        targetText = "You put your arm around %s's shoulder.",
        animated = false,
        voiced = false,
     },
     {
        emote = "attackMyTarget",
        noTargetText = "You tell everyone to attack something.",
        targetText = "You tell everyone to attack %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "awe",
        noTargetText = "You look around in awe.",
        targetText = "You stare at %s in awe.",
        animated = false,
        voiced = false,
     },
     {
        emote = "backpack",
        noTargetText = "You dig through your backpack.",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "badfeeling",
        noTargetText = "You have a bad feeling about this...",
        targetText = "You have a bad feeling about %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "bark",
        noTargetText = "You bark. Woof woof!",
        targetText = "You bark at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "bashful",
        noTargetText = "You are bashful.",
        targetText = "You are so bashful...too bashful to get %s's attention.",
        animated = true,
        voiced = false,
     },
     {
        emote = "beckon",
        noTargetText = "You beckon everyone over to you.",
        targetText = "You beckon %s over.",
        animated = false,
        voiced = false,
     },
     {
        emote = "beg",
        noTargetText = "You beg everyone around you. How pathetic.",
        targetText = "You beg %s. How pathetic.",
        animated = true,
        voiced = true,
     },
     {
        emote = "bite",
        noTargetText = "You look around for someone to bite.",
        targetText = "You bite %s. Ouch!",
        animated = false,
        voiced = false,
     },
     {
        emote = "blame",
        noTargetText = "You blame yourself for what happened.",
        targetText = "You blame %s for everything.",
        animated = true,
        voiced = false,
     },
     {
        emote = "blank",
        noTargetText = "You stare blankly at your surroundings.",
        targetText = "You stare blankly at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "bleed",
        noTargetText = "Blood oozes from your wounds.",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "blink",
        noTargetText = "You blink your eyes.",
        targetText = "You blink at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "blush",
        noTargetText = "You blush.",
        targetText = "You blush at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "boggle",
        noTargetText = "You boggle at the situation.",
        targetText = "You boggle at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "bonk",
        noTargetText = "You bonk yourself on the noggin. Doh!",
        targetText = "You bonk %s on the noggin. Doh!",
        animated = false,
        voiced = false,
     },
     {
        emote = "boop",
        noTargetText = "You boop your own nose. Boop!",
        targetText = "You boop %s's nose.",
        animated = true,
        voiced = false,
     },
     {
        emote = "bored",
        noTargetText = "You are overcome with boredom. Oh the drudgery!",
        targetText = "You are terribly bored with %s.",
        animated = false,
        voiced = true,
     },
     {
        emote = "bounce",
        noTargetText = "You bounce up and down.",
        targetText = "You bounce up and down in front of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "bow",
        noTargetText = "You bow down graciously.",
        targetText = "You bow before %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "brandish",
        noTargetText = "You brandish your weapon fiercely.",
        targetText = "You brandish your weapon fiercely at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "brb",
        noTargetText = "You let everyone know you'll be right back.",
        targetText = "You let %s know you'll be right back.",
        animated = false,
        voiced = false,
     },
     {
        emote = "breath",
        noTargetText = "You take a deep breath.",
        targetText = "You tell %s to take a deep breath.",
        animated = false,
        voiced = false,
     },
     {
        emote = "burp",
        noTargetText = "You let out a loud belch.",
        targetText = "You burp rudely in %s's face.",
        animated = false,
        voiced = false,
     },
     {
        emote = "bye",
        noTargetText = "You wave goodbye to everyone. Farewell!",
        targetText = "	You wave goodbye to %s. Farewell!",
        animated = true,
        voiced = true,
     },
     {
        emote = "cackle",
        noTargetText = "You cackle maniacally at the situation.",
        targetText = "You cackle maniacally at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "calm",
        noTargetText = "You remain calm.",
        targetText = "	You try to calm %s down.",
        animated = false,
        voiced = false,
     },
     {
        emote = "challenge",
        noTargetText = "You put out a challenge to everyone. Bring it on!",
        targetText = "You challenge %s to a duel.",
        animated = false,
        voiced = false,
     },
     {
        emote = "charge",
        noTargetText = "You start to charge.",
        targetText = "",
        animated = true,
        voiced = true,
     },
     {
        emote = "charm",
        noTargetText = "You put on the charm.",
        targetText = "You think %s is charming.",
        animated = false,
        voiced = false,
     },
     {
        emote = "cheer",
        noTargetText = "You cheer!",
        targetText = "You cheer at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "chicken",
        noTargetText = "With arms flapping, you strut around. Cluck, Cluck, Chicken!",
        targetText = "With arms flapping, you strut around %s. Cluck, Cluck, Chicken!",
        animated = true,
        voiced = true,
     },
     {
        emote = "chuckle",
        noTargetText = "You let out a hearty chuckle.",
        targetText = "You chuckle at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "chug",
        noTargetText = "You take a mighty quaff of your beverage.",
        targetText = "	You encourage %s to chug. CHUG! CHUG! CHUG!",
        animated = false,
        voiced = false,
     },
     {
        emote = "clap",
        noTargetText = "You clap excitedly.",
        targetText = "You clap excitedly for %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "cold",
        noTargetText = "You let everyone know that you are cold.",
        targetText = "You let %s know that you are cold.",
        animated = false,
        voiced = false,
     },
     {
        emote = "comfort",
        noTargetText = "You need to be comforted.",
        targetText = "You comfort %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "commend",
        noTargetText = "You commend everyone on a job well done.",
        targetText = "You commend %s on a job well done.",
        animated = true,
        voiced = false,
     },
     {
        emote = "confused",
        noTargetText = "You are hopelessly confused.",
        targetText = "You look at %s with a confused look.",
        animated = true,
        voiced = false,
     },
     {
        emote = "congratulate",
        noTargetText = "You congratulate everyone around you.",
        targetText = "You congratulate %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "cough",
        noTargetText = "You let out a hacking cough.",
        targetText = "You cough at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "coverears",
        noTargetText = "You cover your ears.",
        targetText = "You cover %s's ears.",
        animated = false,
        voiced = false,
     },
     {
        emote = "cower",
        noTargetText = "You cower in fear.",
        targetText = "You cower in fear at the sight of %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "crack",
        noTargetText = "You crack your knuckles.",
        targetText = "You crack your knuckles while staring at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "cringe",
        noTargetText = "You cringe in fear.",
        targetText = "You cringe away from %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "crossarms",
        noTargetText = "You cross your arms.",
        targetText = "You cross your arms at %s. Hmph!",
        animated = false,
        voiced = false,
     },
     {
        emote = "cry",
        noTargetText = "You cry.",
        targetText = "You cry on %s's shoulder.",
        animated = true,
        voiced = true,
     },
     {
        emote = "cuddle",
        noTargetText = "You need to be cuddled.",
        targetText = "You cuddle up against %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "curious",
        noTargetText = "You express your curiosity to those around you.",
        targetText = "You are curious what %s is up to.",
        animated = true,
        voiced = false,
     },
     {
        emote = "curtsey",
        noTargetText = "You curtsey.",
        targetText = "You curtsey before %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "dance",
        noTargetText = "You burst into dance.",
        targetText = "You dance with %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "ding",
        noTargetText = "You reached a new level. DING!",
        targetText = "You congratulate %s on a new level. DING!",
        animated = false,
        voiced = false,
     },
     {
        emote = "disagree",
        noTargetText = "You disagree.",
        targetText = "You disagree with %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "threaten",
        noTargetText = "You threaten everyone with the wrath of doom.",
        targetText = "You threaten %s with the wrath of doom.",
        animated = false,
        voiced = true,
     },
     {
        emote = "doubt",
        noTargetText = "You doubt the situation will end in your favor.",
        targetText = "You doubt %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "drink",
        noTargetText = "You raise a drink in the air before chugging it down. Cheers!",
        targetText = "You raise a drink to %s. Cheers!",
        animated = true,
        voiced = true,
     },
     {
        emote = "drool",
        noTargetText = "A tendril of drool runs down your lip.",
        targetText = "You look at %s and begin to drool.",
        animated = false,
        voiced = false,
     },
     {
        emote = "duck",
        noTargetText = "You duck for cover.",
        targetText = "You duck behind %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "eat",
        noTargetText = "You begin to eat.",
        targetText = "You begin to eat in front of %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "embarrass",
        noTargetText = "You flush with embarrassment.",
        targetText = "You are embarrassed by %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "encourage",
        noTargetText = "You encourage everyone around you.",
        targetText = "You encourage %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "enemy",
        noTargetText = "You warn everyone that an enemy is near.",
        targetText = "You warn %s that an enemy is near.",
        animated = false,
        voiced = false,
     },
     {
        emote = "eye",
        noTargetText = "You cross your eyes.",
        targetText = "You eye %s up and down.",
        animated = false,
        voiced = false,
     },
     {
        emote = "eyebrow",
        noTargetText = "You raise your eyebrow inquisitively.",
        targetText = "You raise your eyebrow inquisitively at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "facepalm",
        noTargetText = "You cover your face with your palm.",
        targetText = "You look at %s and cover your face with your palm.",
        animated = false,
        voiced = false,
     },
     {
        emote = "faint",
        noTargetText = "You faint.",
        targetText = "You faint at the sight of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "fart",
        noTargetText = "You fart loudly. Whew...what stinks?",
        targetText = "You brush up against %s and fart loudly.",
        animated = false,
        voiced = false,
     },
     {
        emote = "fidget",
        noTargetText = "You fidget.",
        targetText = "You fidget impatiently while waiting for %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "flee",
        noTargetText = "You yell for everyone to flee!",
        targetText = "You yell for %s to flee!",
        animated = true,
        voiced = true,
     },
     {
        emote = "flex",
        noTargetText = "You flex your muscles. Oooooh so strong!",
        targetText = "You flex at %s. Oooooh so strong!",
        animated = true,
        voiced = false,
     },
     {
        emote = "flirt",
        noTargetText = "You flirt.",
        targetText = "You flirt with %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "flop",
        noTargetText = "You flop about helplessly.",
        targetText = "You flop about helplessly around %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "follow",
        noTargetText = "You motion for everyone to follow.",
        targetText = "You motion for %s to follow.",
        animated = true,
        voiced = true,
     },
     {
        emote = "frown",
        noTargetText = "You frown.",
        targetText = "You frown with disappointment at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "gasp",
        noTargetText = "You gasp.",
        targetText = "You gasp at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "gaze",
        noTargetText = "You gaze off into the distance.",
        targetText = "You gaze longingly at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "giggle",
        noTargetText = "You giggle.",
        targetText = "You giggle at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "glare",
        noTargetText = "You glare angrily.",
        targetText = "You glare angrily at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "gloat",
        noTargetText = "You gloat over everyone's misfortune.",
        targetText = "You gloat over %s's misfortune.",
        animated = true,
        voiced = true,
     },
     {
        emote = "glower",
        noTargetText = "You glower at averyone around you.",
        targetText = "You glower at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "go",
        noTargetText = "You tell everyone to go.",
        targetText = "You tell %s to go.",
        animated = false,
        voiced = false,
     },
     {
        emote = "going",
        noTargetText = "You must be going.",
        targetText = "You tell %s that you must be going.",
        animated = false,
        voiced = false,
     },
     {
        emote = "golfclap",
        noTargetText = "You clap half-heartedly, clearly unimpressed.",
        targetText = "You clap for %s, clearly unimpressed.",
        animated = true,
        voiced = false,
     },
     {
        emote = "greet",
        noTargetText = "You greet everyone warmly.",
        targetText = "You greet %s warmly.",
        animated = true,
        voiced = false,
     },
     {
        emote = "grin",
        noTargetText = "You grin wickedly.",
        targetText = "You grin wickedly at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "groan",
        noTargetText = "You begin to groan in pain.",
        targetText = "You look at %s and groan in pain.",
        animated = false,
        voiced = false,
     },
     {
        emote = "grovel",
        noTargetText = "You grovel on the ground, wallowing in subservience.",
        targetText = "You grovel before %s like a subservient peon.",
        animated = true,
        voiced = false,
     },
     {
        emote = "growl",
        noTargetText = "You growl menacingly.",
        targetText = "You growl menacingly at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "guffaw",
        noTargetText = "You let out a boisterous guffaw!",
        targetText = "You take one look at %s and let out a guffaw!",
        animated = true,
        voiced = true,
     },
     {
        emote = "hail",
        noTargetText = "You hail those around you.",
        targetText = "You hail %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "happy",
        noTargetText = "You are filled with happiness!",
        targetText = "You are very happy with %s!",
        animated = false,
        voiced = false,
     },
     {
        emote = "headache",
        noTargetText = "You are getting a headache.",
        targetText = "You are getting a headache from %s's antics.",
        animated = false,
        voiced = false,
     },
     {
        emote = "healme",
        noTargetText = "You call out for healing!",
        targetText = "",
        animated = true,
        voiced = true,
     },
     {
        emote = "hello",
        noTargetText = "You greet everyone with a hearty hello!",
        targetText = "You greet %s with a hearty hello!",
        animated = true,
        voiced = true,
     },
     {
        emote = "helpme",
        noTargetText = "You cry out for help!",
        targetText = "",
        animated = true,
        voiced = true,
     },
     {
        emote = "hiccup",
        noTargetText = "You hiccup loudly.",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "highfive",
        noTargetText = "You put up your hand for a high five.",
        targetText = "You give %s a high five!",
        animated = false,
        voiced = false,
     },
     {
        emote = "hiss",
        noTargetText = "You hiss at everyone around you.",
        targetText = "You hiss at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "holdhand",
        noTargetText = "You wish someone would hold your hand.",
        targetText = "You hold %s's hand.",
        animated = false,
        voiced = false,
     },
     {
        emote = "hug",
        noTargetText = "You need a hug!",
        targetText = "You hug %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "hungry",
        noTargetText = "You are hungry!",
        targetText = "You are hungry. Maybe %s has some food...",
        animated = false,
        voiced = false,
     },
     {
        emote = "hurry",
        noTargetText = "You try to pick up the pace.",
        targetText = "You tell %s to hurry up.",
        animated = false,
        voiced = false,
     },
     {
        emote = "idea",
        noTargetText = "You have an idea!",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "incoming",
        noTargetText = "You warn everyone of incoming enemies!",
        targetText = "You point out %s as an incoming enemy!",
        animated = true,
        voiced = true,
     },
     {
        emote = "insult",
        noTargetText = "You think everyone around you is a son of a motherless ogre",
        targetText = "You think %s is the son of a motherless ogre.",
        animated = true,
        voiced = false,
     },
     {
        emote = "introduce",
        noTargetText = "You introduce yourself to everyone.",
        targetText = "You introduce yourself to %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "jealous",
        noTargetText = "You are jealous of everyone around you.",
        targetText = "You are jealous of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "jk",
        noTargetText = "You were just kidding!",
        targetText = "You let %s know that you were just kidding!",
        animated = false,
        voiced = false,
     },
     {
        emote = "kiss",
        noTargetText = "You blow a kiss into the wind.",
        targetText = "You blow a kiss to %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "kneel",
        noTargetText = "You kneel down.",
        targetText = "You kneel before %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "laugh",
        noTargetText = "You laugh.",
        targetText = "You laugh at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "lick",
        noTargetText = "You lick your lips.",
        targetText = "You lick %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "listen",
        noTargetText = "You are listening!",
        targetText = "You listen intently to %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "look",
        noTargetText = "You look around.",
        targetText = "You look at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "lost",
        noTargetText = "You are hopelessly lost.",
        targetText = "You want %s to know that you are hopelessly lost.",
        animated = true,
        voiced = false,
     },
     {
        emote = "love",
        noTargetText = "You feel the love.",
        targetText = "You love %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "luck",
        noTargetText = "You wish everyone good luck.",
        targetText = "You wish %s the best of luck.",
        animated = false,
        voiced = false,
     },
     {
        emote = "toast",
        noTargetText = "You nod approvingly. Magnificent job!",
        targetText = "You nod approvingly at %s. Magnificent job!",
        animated = true,
        voiced = false,
     },
     {
        emote = "map",
        noTargetText = "You pull out your map.",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "massage",
        noTargetText = "You need a massage!",
        targetText = "You massage %s's shoulders.",
        animated = false,
        voiced = false,
     },
     {
        emote = "meow",
        noTargetText = "You meow.",
        targetText = "You meow at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "mercy",
        noTargetText = "You plead for mercy.",
        targetText = "You plead with %s for mercy.",
        animated = true,
        voiced = false,
     },
     {
        emote = "moan",
        noTargetText = "You moan suggestively.",
        targetText = "You moan suggestively at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "mock",
        noTargetText = "You mock life and all it stands for.",
        targetText = "You mock the foolishness of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "moo",
        noTargetText = "Mooooooooooo",
        targetText = "You moo at %s. Mooooooooooo.",
        animated = false,
        voiced = false,
     },
     {
        emote = "moon",
        noTargetText = "You drop your trousers and moon everyone.",
        targetText = "You drop your trousers and moon %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "mourn",
        noTargetText = "In quiet contemplation, you mourn the loss of the dead.",
        targetText = "In quiet contemplation, you mourn the death of %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "mutter",
        noTargetText = "You mutter angrily to yourself. Hmmmph!",
        targetText = "You mutter angrily at %s. Hmmmph!",
        animated = false,
        voiced = false,
     },
     {
        emote = "nervous",
        noTargetText = "You look around nervously.",
        targetText = "You look at %s nervously.",
        animated = false,
        voiced = false,
     },
     {
        emote = "no",
        noTargetText = "You clearly state, NO.",
        targetText = "You tell %s NO. Not going to happen.",
        animated = true,
        voiced = true,
     },
     {
        emote = "nod",
        noTargetText = "You nod.",
        targetText = "You nod at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "nosepick",
        noTargetText = "With a finger deep in one nostril, you pass the time.",
        targetText = "You pick your nose and show it to %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "object",
        noTargetText = "You OBJECT!",
        targetText = "You object to %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "offer",
        noTargetText = "You want to make an offer.",
        targetText = "You attempt to make %s an offer they can't refuse.",
        animated = false,
        voiced = false,
     },
     {
        emote = "oom",
        noTargetText = "You announce that you have low mana!",
        targetText = "",
        animated = true,
        voiced = true,
     },
     {
        emote = "oops",
        noTargetText = "You made a mistake.",
        targetText = "",
        animated = true,
        voiced = true,
     },
     {
        emote = "openfire",
        noTargetText = "You give the order to open fire.",
        targetText = "",
        animated = true,
        voiced = true,
     },
     {
        emote = "panic",
        noTargetText = "You run around in a frenzied state of panic.",
        targetText = "You take one look at %s and panic.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pat",
        noTargetText = "You need a pat.",
        targetText = "You gently pat %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "peer",
        noTargetText = "You peer around, searchingly.",
        targetText = "You peer at %s searchingly.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pet",
        noTargetText = "You need to be petted.",
        targetText = "You pet %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pinch",
        noTargetText = "You pinch yourself.",
        targetText = "You pinch %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pity",
        noTargetText = "You pity those around you.",
        targetText = "You look down upon %s with pity.",
        animated = false,
        voiced = false,
     },
     {
        emote = "plead",
        noTargetText = "You drop to your knees and plead in desperation.",
        targetText = "You plead with %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "point",
        noTargetText = "You point over yonder.",
        targetText = "You point at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "poke",
        noTargetText = "You poke your belly and giggle.",
        targetText = "You poke %s. Hey!",
        animated = false,
        voiced = false,
     },
     {
        emote = "ponder",
        noTargetText = "You ponder the situation.",
        targetText = "You ponder %s's actions.",
        animated = true,
        voiced = false,
     },
     {
        emote = "pounce",
        noTargetText = "You pounce out from the shadows.",
        targetText = "You pounce towards %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pout",
        noTargetText = "You pout at everyone around you.",
        targetText = "You pout at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "praise",
        noTargetText = "You praise the Light.",
        targetText = "You lavish praise upon %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pray",
        noTargetText = "You pray to the Gods.",
        targetText = "You say a prayer for %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "promise",
        noTargetText = "",
        targetText = "You make %s a promise.",
        animated = false,
        voiced = false,
     },
     {
        emote = "proud",
        noTargetText = "You are proud of yourself.",
        targetText = "You are proud of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "pulse",
        noTargetText = "You check your own pulse.",
        targetText = "You check %s for a pulse. Oh no!",
        animated = false,
        voiced = false,
     },
     {
        emote = "punch",
        noTargetText = "You punch yourself.",
        targetText = "You punch %s's shoulder.",
        animated = false,
        voiced = false,
     },
     {
        emote = "purr",
        noTargetText = "You purr like a kitten.",
        targetText = "You purr at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "puzzle",
        noTargetText = "You are puzzled. What's going on here?",
        targetText = "You are puzzled by %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "raise",
        noTargetText = "You raise your hand in the air.",
        targetText = "You look at %s and raise your hand.",
        animated = false,
        voiced = false,
     },
     {
        emote = "rasp",
        noTargetText = "You make a rude gesture.",
        targetText = "You make a rude gesture at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "ready",
        noTargetText = "You let everyone know that you are ready!",
        targetText = "You let %s know that you are ready!",
        animated = false,
        voiced = false,
     },
     {
        emote = "regret",
        noTargetText = "You are filled with regret.",
        targetText = "You think that %s will regret it.",
        animated = false,
        voiced = false,
     },
     {
        emote = "revenge",
        noTargetText = "You vow you will have your revenge.",
        targetText = "You vow revenge on %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "roar",
        noTargetText = "You roar with bestial vigor. So fierce!",
        targetText = "You roar with bestial vigor at %s. So fierce!",
        animated = true,
        voiced = true,
     },
     {
        emote = "rofl",
        noTargetText = "You roll on the floor laughing.",
        targetText = "You roll on the floor laughing at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "rolleyes",
        noTargetText = "You roll your eyes.",
        targetText = "You roll your eyes at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "rude",
        noTargetText = "You make a rude gesture.",
        targetText = "You make a rude gesture at %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "ruffle",
        noTargetText = "You ruffle your hair.",
        targetText = "You ruffle %s's hair.",
        animated = false,
        voiced = false,
     },
     {
        emote = "sad",
        noTargetText = "You hang your head dejectedly.",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "salute",
        noTargetText = "You stand at attention and salute.",
        targetText = "You salute %s with respect.",
        animated = true,
        voiced = false,
     },
     {
        emote = "scared",
        noTargetText = "You are scared!",
        targetText = "You are scared of %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "scoff",
        noTargetText = "You scoff.",
        targetText = "You scoff at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "scold",
        noTargetText = "You scold yourself.",
        targetText = "You scold %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "scowl",
        noTargetText = "You scowl.",
        targetText = "You scowl at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "scratch",
        noTargetText = "You scratch yourself. Ah, much better!",
        targetText = "You scratch %s. How catty!",
        animated = false,
        voiced = false,
     },
     {
        emote = "search",
        noTargetText = "You search for something.",
        targetText = "You search %s for something.",
        animated = false,
        voiced = false,
     },
     {
        emote = "sexy",
        noTargetText = "You're too sexy for your tunic...so sexy it hurts.",
        targetText = "You think %s is a sexy devil.",
        animated = false,
        voiced = false,
     },
     {
        emote = "shake",
        noTargetText = "You shake your rear.",
        targetText = "You shake your rear at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "shakefist",
        noTargetText = "You shake your fist.",
        targetText = "You shake your fist at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "shifty",
        noTargetText = "Your eyes shift back and forth suspiciously.",
        targetText = "You give %s a shifty look.",
        animated = false,
        voiced = false,
     },
     {
        emote = "shimmy",
        noTargetText = "You shimmy before the masses.",
        targetText = "You shimmy before %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "shiver",
        noTargetText = "You shiver in your boots. Chilling!",
        targetText = "You shiver beside %s. Chilling!",
        animated = false,
        voiced = false,
     },
     {
        emote = "shoo",
        noTargetText = "You shoo the measly pests away.",
        targetText = "You shoo %s away. Be gone pest!",
        animated = false,
        voiced = false,
     },
     {
        emote = "shout",
        noTargetText = "You shout.",
        targetText = "You shout at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "shrug",
        noTargetText = "You shrug. Who knows?",
        targetText = "You shrug at %s. Who knows?",
        animated = true,
        voiced = false,
     },
     {
        emote = "shudder",
        noTargetText = "You shudder.",
        targetText = "You shudder at the sight of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "shy",
        noTargetText = "You smile shyly.",
        targetText = "You smile shyly at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "sigh",
        noTargetText = "You let out a long, drawn-out sigh.",
        targetText = "You sigh at %s.",
        animated = false,
        voiced = true,
     },
     {
        emote = "signal",
        noTargetText = "You give the signal.",
        targetText = "You give %s the signal.",
        animated = false,
        voiced = false,
     },
     {
        emote = "silence",
        noTargetText = "You tell everyone to be quiet. Shhh!",
        targetText = "You tell %s to be quiet. Shhh!",
        animated = false,
        voiced = false,
     },
     {
        emote = "joke",
        noTargetText = "You tell a joke.",
        targetText = "You tell %s a joke.",
        animated = true,
        voiced = true,
     },
     {
        emote = "sing",
        noTargetText = "You burst into song.",
        targetText = "You serenade %s with a song.",
        animated = true,
        voiced = false,
     },
     {
        emote = "slap",
        noTargetText = "You slap yourself across the face. Ouch!",
        targetText = "You slap %s across the face. Ouch!",
        animated = false,
        voiced = false,
     },
     {
        emote = "sleep",
        noTargetText = "You fall asleep. Zzzzzzz.",
        targetText = "",
        animated = true,
        voiced = false,
     },
     {
        emote = "smack",
        noTargetText = "You smack your forehead.",
        targetText = "You smack %s upside the head.",
        animated = false,
        voiced = false,
     },
     {
        emote = "smile",
        noTargetText = "You smile.",
        targetText = "You smile at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "smirk",
        noTargetText = "A sly smirk spreads across your face.",
        targetText = "You smirk slyly at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "snap",
        noTargetText = "You snap your fingers.",
        targetText = "You snap your fingers at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "snarl",
        noTargetText = "You bare your teeth and snarl.",
        targetText = "You bare your teeth and snarl at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "sneak",
        noTargetText = "You try to sneak away.",
        targetText = "You try to sneak away from %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "sneeze",
        noTargetText = "You sneeze. Achoo!",
        targetText = "You sneeze on %s. Achoo!",
        animated = false,
        voiced = false,
     },
     {
        emote = "snicker",
        noTargetText = "You quietly snicker to yourself.",
        targetText = "You snicker at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "sniff",
        noTargetText = "You sniff the air around you.",
        targetText = "You sniff %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "snort",
        noTargetText = "You snort.",
        targetText = "You snort derisively at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "snub",
        noTargetText = "You snub all of the lowly peons around you.",
        targetText = "You snub %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "soothe",
        noTargetText = "You need to be soothed.",
        targetText = "You soothe %s. There, there...things will be ok.",
        animated = false,
        voiced = false,
     },
     {
        emote = "spit",
        noTargetText = "You spit on the ground.",
        targetText = "You spit on %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "squeal",
        noTargetText = "You squeal like a pig.",
        targetText = "You squeal at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "stare",
        noTargetText = "You stare off into the distance.",
        targetText = "You stare %s down.",
        animated = false,
        voiced = false,
     },
     {
        emote = "stink",
        noTargetText = "You smell the air around you. Wow, someone stinks!",
        targetText = "You smell %s. Wow, someone stinks!",
        animated = false,
        voiced = false,
     },
     {
        emote = "surprised",
        noTargetText = "You are so surprised!",
        targetText = "You are surprised by %s's actions.",
        animated = false,
        voiced = false,
     },
     {
        emote = "surrender",
        noTargetText = "You surrender to your opponents.",
        targetText = "You surrender before %s. Such is the agony of defeat...",
        animated = true,
        voiced = false,
     },
     {
        emote = "suspicious",
        noTargetText = "You narrow your eyes in suspicion.",
        targetText = "You are suspicious of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "sweat",
        noTargetText = "You are sweating.",
        targetText = "You sweat at the sight of %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "talk",
        noTargetText = "You talk to yourself since no one else seems interested.",
        targetText = "You want to talk things over with %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "talkex",
        noTargetText = "You talk excitedly with everyone.",
        targetText = "You talk excitedly with %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "talkq",
        noTargetText = "You want to know the meaning of life.",
        targetText = "You question %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "tap",
        noTargetText = "You tap your foot. Hurry up already!",
        targetText = "You tap your foot as you wait for %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "taunt",
        noTargetText = "You taunt everyone around you. Bring it fools!",
        targetText = "You make a taunting gesture at %s. Bring it!",
        animated = true,
        voiced = true,
     },
     {
        emote = "tease",
        noTargetText = "You are such a tease.",
        targetText = "You tease %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "thank",
        noTargetText = "You thank everyone around you.",
        targetText = "You thank %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "think",
        noTargetText = "You are lost in thought.",
        targetText = "You think about %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "thirsty",
        noTargetText = "You are so thirsty. Can anyone spare a drink?",
        targetText = "You let %s know you are thirsty. Spare a drink?",
        animated = false,
        voiced = false,
     },
     {
        emote = "tickle",
        noTargetText = "You want to be tickled. Hee hee!",
        targetText = "You tickle %s. Hee hee!",
        animated = false,
        voiced = false,
     },
     {
        emote = "tired",
        noTargetText = "You let everyone know that you are tired.",
        targetText = "You let %s know that you are tired.",
        animated = false,
        voiced = false,
     },
     {
        emote = "truce",
        noTargetText = "You offer a truce.",
        targetText = "You offer %s a truce.",
        animated = false,
        voiced = false,
     },
     {
        emote = "twiddle",
        noTargetText = "You twiddle your thumbs.",
        targetText = "",
        animated = false,
        voiced = false,
     },
     {
        emote = "veto",
        noTargetText = "You veto the motion on the floor.",
        targetText = "You veto %s's motion.",
        animated = false,
        voiced = false,
     },
     {
        emote = "victory",
        noTargetText = "You bask in the glory of victory.",
        targetText = "You bask in the glory of victory with %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "violin",
        noTargetText = "You begin to play the world's smallest violin.",
        targetText = "You play the world's smallest violin for %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "wait",
        noTargetText = "You ask everyone to wait.",
        targetText = "You ask %s to wait.",
        animated = true,
        voiced = true,
     },
     {
        emote = "warn",
        noTargetText = "You warn everyone.",
        targetText = "You warn %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "wave",
        noTargetText = "You wave.",
        targetText = "You wave at %s.",
        animated = true,
        voiced = false,
     },
     {
        emote = "welcome",
        noTargetText = "You welcome everyone.",
        targetText = "You welcome %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "whine",
        noTargetText = "You whine pathetically.",
        targetText = "You whine pathetically at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "whistle",
        noTargetText = "You let forth a sharp whistle.",
        targetText = "	You whistle at %s.",
        animated = false,
        voiced = true,
     },
     {
        emote = "whoa",
        noTargetText = "You are blown away.",
        targetText = "You are blown away by %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "wink",
        noTargetText = "You wink slyly.",
        targetText = "You wink slyly at %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "work",
        noTargetText = "You begin to work.",
        targetText = "You work with %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "yawn",
        noTargetText = "You yawn sleepily.",
        targetText = "You yawn sleepily at %s.",
        animated = false,
        voiced = true,
     },
     {
        emote = "yw",
        noTargetText = "You were happy to help.",
        targetText = "You were happy to help %s.",
        animated = true,
        voiced = true,
     },
     {
        emote = "fail",
        noTargetText = "You have failed.",
        targetText = "You think %s has failed.",
        animated = true,
        voiced = false,
     },
     {
        emote = "goodluck",
        noTargetText = "You wish for some good luck.",
        targetText = "You were happy to help %s.",
        animated = false,
        voiced = false,
     },
     {
        emote = "serious",
        noTargetText = "You think this is serious business.",
        targetText = "You think %s is serious.",
        animated = true,
        voiced = true,
     },
     {
        emote = "stopAttack",
        noTargetText = "You tell everyone to stop attacking.",
        targetText = "You tell %s to stop attacking.",
        animated = true,
        voiced = true,
     }
 } 
----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------
local frameWidth = 870
local frameHeight = 540
local PageF = CreateFrame("Frame", nil, UIParent)
_G["EmoteMenu"] = PageF
table.insert(UISpecialFrames, "EmoteMenu")

-- Set frame parameters
EmoteMenu["PageF"] = PageF
PageF:SetSize(frameWidth, frameHeight)
PageF:Hide()
PageF:SetFrameStrata("FULLSCREEN_DIALOG")
PageF:SetFrameLevel(20)
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
    local btnPosX = 85*((i-1)%10)+10 -- (buttonWidth)*(resetEvery10)+(marginLeft)
    local btnPosY = -18*(math.floor ((i-1)/10))-60 -- -(buttonHeight)*(incrementEvery10)-(initMarginTop)
    local emoteString = sortedList[i]["emote"]
    local eBtn = CreateFrame("Button", nil, PageF, "UIPanelButtonTemplate")

    eBtn:SetNormalFontObject("GameFontNormalSmall");
    local font = eBtn:GetNormalFontObject();
    eBtn:SetNormalFontObject(font);

    eBtn:SetPoint('TOPLEFT', btnPosX, btnPosY)
    eBtn:SetText(emoteString)
    eBtn:SetWidth(85)
    eBtn:SetHeight(18)

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
