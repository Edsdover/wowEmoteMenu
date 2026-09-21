-- Generated from wowEmoteMenuStore.lua so the review covers exactly the
-- emotes the menu shows, in the same order.
--
-- targetable mirrors the menu button: an emote with targeted text is
-- performed against the current target, and one without is forced to no
-- target. Reviewing the form the button will not use would record the wrong
-- answer for any emote whose animation or sound differs between the two.

EmoteReviewEmotes = {
    { "absent", true },
    { "agree", true },
    { "amaze", true },
    { "angry", true },
    { "apologize", true },
    { "applaud", true },
    { "arm", true },
    { "attackmytarget", true },
    { "awe", true },
    { "backpack", false },
    { "badfeeling", true },
    { "bark", true },
    { "bashful", true },
    { "beckon", true },
    { "beg", true },
    { "bite", true },
    { "blame", true },
    { "blank", true },
    { "bleed", false },
    { "blink", true },
    { "blush", true },
    { "boggle", true },
    { "bonk", true },
    { "boop", true },
    { "bored", true },
    { "bounce", true },
    { "bow", true },
    { "brandish", true },
    { "brb", true },
    { "breath", true },
    { "burp", true },
    { "bye", true },
    { "cackle", true },
    { "calm", true },
    { "challenge", true },
    { "charge", false },
    { "charm", true },
    { "cheer", true },
    { "chicken", true },
    { "chuckle", true },
    { "chug", true },
    { "clap", true },
    { "cold", true },
    { "comfort", true },
    { "commend", true },
    { "confused", true },
    { "congratulate", true },
    { "cough", true },
    { "coverears", true },
    { "cower", true },
    { "crack", true },
    { "cringe", true },
    { "crossarms", true },
    { "cry", true },
    { "cuddle", true },
    { "curious", true },
    { "curtsey", true },
    { "dance", true },
    { "ding", true },
    { "disagree", true },
    { "doubt", true },
    { "drink", true },
    { "drool", true },
    { "duck", true },
    { "eat", true },
    { "embarrass", true },
    { "encourage", true },
    { "enemy", true },
    { "eye", true },
    { "eyebrow", true },
    { "facepalm", true },
    { "fail", true },
    { "faint", true },
    { "fart", true },
    { "fidget", true },
    { "flee", true },
    { "flex", true },
    { "flirt", true },
    { "flop", true },
    { "follow", true },
    { "frown", true },
    { "gasp", true },
    { "gaze", true },
    { "giggle", true },
    { "glare", true },
    { "gloat", true },
    { "glower", true },
    { "go", true },
    { "going", true },
    { "golfclap", true },
    { "goodluck", true },
    { "greet", true },
    { "grin", true },
    { "groan", true },
    { "grovel", true },
    { "growl", true },
    { "guffaw", true },
    { "hail", true },
    { "happy", true },
    { "headache", true },
    { "healme", false },
    { "hello", true },
    { "helpme", false },
    { "hiccup", false },
    { "highfive", true },
    { "hiss", true },
    { "holdhand", true },
    { "hug", true },
    { "hungry", true },
    { "hurry", true },
    { "idea", false },
    { "incoming", false },
    { "insult", true },
    { "introduce", true },
    { "jealous", true },
    { "jk", true },
    { "joke", true },
    { "kiss", true },
    { "kneel", true },
    { "laugh", true },
    { "laydown", true },
    { "lick", true },
    { "listen", true },
    { "look", true },
    { "lost", true },
    { "love", true },
    { "luck", true },
    { "map", false },
    { "massage", true },
    { "meow", true },
    { "mercy", true },
    { "moan", true },
    { "mock", true },
    { "moo", true },
    { "moon", true },
    { "mountspecial", false },
    { "mourn", true },
    { "mutter", true },
    { "nervous", true },
    { "no", true },
    { "nod", true },
    { "nosepick", true },
    { "object", true },
    { "offer", true },
    { "oom", false },
    { "oops", false },
    { "openfire", false },
    { "panic", true },
    { "pat", true },
    { "peer", true },
    { "pet", true },
    { "pinch", true },
    { "pity", true },
    { "plead", true },
    { "point", true },
    { "poke", true },
    { "ponder", true },
    { "pounce", true },
    { "pout", true },
    { "praise", true },
    { "pray", true },
    { "promise", true },
    { "proud", true },
    { "pulse", true },
    { "punch", true },
    { "purr", true },
    { "puzzle", true },
    { "raise", true },
    { "rasp", true },
    { "ready", true },
    { "regret", true },
    { "revenge", true },
    { "roar", true },
    { "rofl", true },
    { "rolleyes", true },
    { "rude", true },
    { "ruffle", true },
    { "sad", false },
    { "salute", true },
    { "scared", true },
    { "scoff", true },
    { "scold", true },
    { "scowl", true },
    { "scratch", true },
    { "search", true },
    { "serious", true },
    { "sexy", true },
    { "shake", true },
    { "shakefist", true },
    { "shifty", true },
    { "shimmy", true },
    { "shiver", true },
    { "shoo", true },
    { "shout", true },
    { "shrug", true },
    { "shudder", true },
    { "shy", true },
    { "sigh", true },
    { "signal", true },
    { "silence", true },
    { "sing", true },
    { "sit", false },
    { "slap", true },
    { "sleep", false },
    { "smack", true },
    { "smile", true },
    { "smirk", true },
    { "snap", true },
    { "snarl", true },
    { "sneak", true },
    { "sneeze", true },
    { "snicker", true },
    { "sniff", true },
    { "snort", true },
    { "snub", true },
    { "soothe", true },
    { "spit", false },
    { "squeal", true },
    { "stand", false },
    { "stare", true },
    { "stink", true },
    { "stopattack", true },
    { "surprised", true },
    { "surrender", true },
    { "suspicious", true },
    { "sweat", true },
    { "talk", true },
    { "talkex", true },
    { "talkq", true },
    { "tap", true },
    { "taunt", true },
    { "tease", true },
    { "thank", true },
    { "think", true },
    { "thirsty", true },
    { "threaten", true },
    { "tickle", true },
    { "tired", true },
    { "toast", true },
    { "train", false },
    { "truce", true },
    { "twiddle", false },
    { "veto", true },
    { "victory", true },
    { "violin", true },
    { "wait", true },
    { "warn", true },
    { "wave", true },
    { "welcome", true },
    { "whine", true },
    { "whistle", true },
    { "whoa", true },
    { "wink", true },
    { "work", true },
    { "yawn", true },
    { "yw", true },
}

-- Emotes worth a second look. A looping emote (dance, sit, sleep, laydown,
-- stand) persists until cancelled and suppresses the next few animations, so
-- anything reviewed just after one may have been recorded as having no
-- animation when it simply never got to play. /emotereview recheck walks
-- these, cancelling the lingering state first.
EmoteReviewSuspects = {
    "ding",
    "lick",
    "listen",
    "look",
    "mountspecial",
    "slap",
    "smack",
    "smile",
    "smirk",
    "snap",
    "snarl",
    "sneak",
    "sneeze",
    "stand",
    "stare",
    "stink",
    "stopattack",
    "surprised",
}

-- Answers carried across a reload. Regenerate with build_flags.py --carry
-- after a partial session; SavedVariables are written but never restored on
-- this build, so the addon cannot read back its own earlier output.

EmoteReviewPrevious = {
    ["absent"] = { animated = false, voiced = false },
    ["agree"] = { animated = false, voiced = false },
    ["amaze"] = { animated = false, voiced = false },
    ["angry"] = { animated = true, voiced = false },
    ["apologize"] = { animated = false, voiced = true },
    ["applaud"] = { animated = true, voiced = true },
    ["arm"] = { animated = false, voiced = false },
    ["attackmytarget"] = { animated = true, voiced = true },
    ["awe"] = { animated = false, voiced = false },
    ["backpack"] = { animated = false, voiced = false },
    ["badfeeling"] = { animated = false, voiced = false },
    ["bark"] = { animated = false, voiced = false },
    ["bashful"] = { animated = true, voiced = false },
    ["beckon"] = { animated = false, voiced = false },
    ["beg"] = { animated = true, voiced = true },
    ["bite"] = { animated = false, voiced = false },
    ["blame"] = { animated = true, voiced = false },
    ["blank"] = { animated = false, voiced = false },
    ["bleed"] = { animated = false, voiced = false },
    ["blink"] = { animated = false, voiced = false },
    ["blush"] = { animated = true, voiced = false },
    ["boggle"] = { animated = true, voiced = false },
    ["bonk"] = { animated = false, voiced = false },
    ["boop"] = { animated = true, voiced = false },
    ["bored"] = { animated = false, voiced = true },
    ["bounce"] = { animated = false, voiced = false },
    ["bow"] = { animated = true, voiced = false },
    ["brandish"] = { animated = false, voiced = false },
    ["brb"] = { animated = false, voiced = false },
    ["breath"] = { animated = false, voiced = false },
    ["burp"] = { animated = false, voiced = false },
    ["bye"] = { animated = true, voiced = true },
    ["cackle"] = { animated = true, voiced = true },
    ["calm"] = { animated = false, voiced = false },
    ["challenge"] = { animated = false, voiced = false },
    ["charge"] = { animated = true, voiced = true },
    ["charm"] = { animated = false, voiced = false },
    ["cheer"] = { animated = true, voiced = true },
    ["chicken"] = { animated = true, voiced = true },
    ["chuckle"] = { animated = true, voiced = true },
    ["chug"] = { animated = false, voiced = false },
    ["clap"] = { animated = true, voiced = true },
    ["cold"] = { animated = false, voiced = false },
    ["comfort"] = { animated = false, voiced = false },
    ["commend"] = { animated = true, voiced = true },
    ["confused"] = { animated = true, voiced = false },
    ["congratulate"] = { animated = true, voiced = true },
    ["cough"] = { animated = false, voiced = false },
    ["coverears"] = { animated = false, voiced = false },
    ["cower"] = { animated = false, voiced = false },
    ["crack"] = { animated = false, voiced = false },
    ["cringe"] = { animated = false, voiced = false },
    ["crossarms"] = { animated = false, voiced = false },
    ["cry"] = { animated = true, voiced = true },
    ["cuddle"] = { animated = false, voiced = false },
    ["curious"] = { animated = true, voiced = false },
    ["curtsey"] = { animated = true, voiced = false },
    ["dance"] = { animated = true, voiced = false },
    ["ding"] = { animated = false, voiced = false },
    ["disagree"] = { animated = true, voiced = false },
    ["doubt"] = { animated = true, voiced = false },
    ["drink"] = { animated = true, voiced = false },
    ["drool"] = { animated = false, voiced = false },
    ["duck"] = { animated = false, voiced = false },
    ["eat"] = { animated = true, voiced = false },
    ["embarrass"] = { animated = false, voiced = false },
    ["encourage"] = { animated = false, voiced = false },
    ["enemy"] = { animated = false, voiced = false },
    ["eye"] = { animated = false, voiced = false },
    ["eyebrow"] = { animated = false, voiced = false },
    ["facepalm"] = { animated = false, voiced = false },
    ["fail"] = { animated = true, voiced = false },
    ["faint"] = { animated = false, voiced = false },
    ["fart"] = { animated = false, voiced = false },
    ["fidget"] = { animated = false, voiced = false },
    ["flee"] = { animated = true, voiced = true },
    ["flex"] = { animated = true, voiced = false },
    ["flirt"] = { animated = true, voiced = true },
    ["flop"] = { animated = false, voiced = false },
    ["follow"] = { animated = true, voiced = true },
    ["frown"] = { animated = false, voiced = false },
    ["gasp"] = { animated = true, voiced = false },
    ["gaze"] = { animated = false, voiced = false },
    ["giggle"] = { animated = true, voiced = true },
    ["glare"] = { animated = false, voiced = false },
    ["gloat"] = { animated = true, voiced = true },
    ["glower"] = { animated = false, voiced = false },
    ["go"] = { animated = false, voiced = false },
    ["going"] = { animated = false, voiced = false },
    ["golfclap"] = { animated = true, voiced = true },
    ["goodluck"] = { animated = false, voiced = false },
    ["greet"] = { animated = true, voiced = false },
    ["grin"] = { animated = false, voiced = false },
    ["groan"] = { animated = false, voiced = false },
    ["grovel"] = { animated = true, voiced = false },
    ["growl"] = { animated = true, voiced = false },
    ["guffaw"] = { animated = true, voiced = true },
    ["hail"] = { animated = true, voiced = false },
    ["happy"] = { animated = false, voiced = false },
    ["headache"] = { animated = false, voiced = false },
    ["healme"] = { animated = true, voiced = true },
    ["hello"] = { animated = true, voiced = true },
    ["helpme"] = { animated = true, voiced = true },
    ["hiccup"] = { animated = false, voiced = false },
    ["highfive"] = { animated = false, voiced = false },
    ["hiss"] = { animated = false, voiced = false },
    ["holdhand"] = { animated = false, voiced = false },
    ["hug"] = { animated = false, voiced = false },
    ["hungry"] = { animated = false, voiced = false },
    ["hurry"] = { animated = false, voiced = false },
    ["idea"] = { animated = false, voiced = false },
    ["incoming"] = { animated = true, voiced = true },
    ["insult"] = { animated = true, voiced = false },
    ["introduce"] = { animated = false, voiced = false },
    ["jealous"] = { animated = false, voiced = false },
    ["jk"] = { animated = false, voiced = false },
    ["joke"] = { animated = true, voiced = true },
    ["kiss"] = { animated = true, voiced = true },
    ["kneel"] = { animated = true, voiced = false },
    ["laugh"] = { animated = true, voiced = true },
    ["laydown"] = { animated = true, voiced = false },
    ["lick"] = { animated = false, voiced = false },
    ["listen"] = { animated = false, voiced = false },
    ["look"] = { animated = false, voiced = false },
    ["lost"] = { animated = true, voiced = false },
    ["love"] = { animated = false, voiced = false },
    ["luck"] = { animated = false, voiced = false },
    ["map"] = { animated = false, voiced = false },
    ["massage"] = { animated = false, voiced = false },
    ["meow"] = { animated = false, voiced = false },
    ["mercy"] = { animated = true, voiced = false },
    ["moan"] = { animated = false, voiced = false },
    ["mock"] = { animated = false, voiced = false },
    ["moo"] = { animated = false, voiced = false },
    ["moon"] = { animated = false, voiced = false },
    ["mountspecial"] = { animated = false, voiced = false },
    ["mourn"] = { animated = true, voiced = true },
    ["mutter"] = { animated = false, voiced = false },
    ["nervous"] = { animated = false, voiced = false },
    ["no"] = { animated = true, voiced = true },
    ["nod"] = { animated = true, voiced = true },
    ["nosepick"] = { animated = false, voiced = false },
    ["object"] = { animated = true, voiced = false },
    ["offer"] = { animated = false, voiced = false },
    ["oom"] = { animated = true, voiced = true },
    ["oops"] = { animated = true, voiced = true },
    ["openfire"] = { animated = true, voiced = true },
    ["panic"] = { animated = false, voiced = false },
    ["pat"] = { animated = false, voiced = false },
    ["peer"] = { animated = false, voiced = false },
    ["pet"] = { animated = false, voiced = false },
    ["pinch"] = { animated = false, voiced = false },
    ["pity"] = { animated = false, voiced = false },
    ["plead"] = { animated = true, voiced = false },
    ["point"] = { animated = true, voiced = false },
    ["poke"] = { animated = false, voiced = false },
    ["ponder"] = { animated = true, voiced = false },
    ["pounce"] = { animated = false, voiced = false },
    ["pout"] = { animated = false, voiced = false },
    ["praise"] = { animated = false, voiced = false },
    ["pray"] = { animated = true, voiced = false },
    ["promise"] = { animated = false, voiced = false },
    ["proud"] = { animated = false, voiced = false },
    ["pulse"] = { animated = false, voiced = false },
    ["punch"] = { animated = false, voiced = false },
    ["purr"] = { animated = false, voiced = false },
    ["puzzle"] = { animated = true, voiced = false },
    ["raise"] = { animated = false, voiced = false },
    ["rasp"] = { animated = true, voiced = true },
    ["ready"] = { animated = false, voiced = false },
    ["regret"] = { animated = false, voiced = false },
    ["revenge"] = { animated = false, voiced = false },
    ["roar"] = { animated = true, voiced = true },
    ["rofl"] = { animated = true, voiced = true },
    ["rolleyes"] = { animated = false, voiced = false },
    ["rude"] = { animated = true, voiced = false },
    ["ruffle"] = { animated = false, voiced = false },
    ["sad"] = { animated = false, voiced = false },
    ["salute"] = { animated = true, voiced = false },
    ["scared"] = { animated = false, voiced = false },
    ["scoff"] = { animated = false, voiced = false },
    ["scold"] = { animated = false, voiced = false },
    ["scowl"] = { animated = false, voiced = false },
    ["scratch"] = { animated = false, voiced = false },
    ["search"] = { animated = false, voiced = false },
    ["serious"] = { animated = false, voiced = false },
    ["sexy"] = { animated = false, voiced = false },
    ["shake"] = { animated = false, voiced = false },
    ["shakefist"] = { animated = false, voiced = false },
    ["shifty"] = { animated = false, voiced = false },
    ["shimmy"] = { animated = false, voiced = false },
    ["shiver"] = { animated = false, voiced = false },
    ["shoo"] = { animated = false, voiced = false },
    ["shout"] = { animated = true, voiced = false },
    ["shrug"] = { animated = true, voiced = false },
    ["shudder"] = { animated = false, voiced = false },
    ["shy"] = { animated = true, voiced = false },
    ["sigh"] = { animated = false, voiced = true },
    ["signal"] = { animated = false, voiced = false },
    ["silence"] = { animated = false, voiced = false },
    ["sing"] = { animated = true, voiced = false },
    ["sit"] = { animated = true, voiced = false },
    ["slap"] = { animated = false, voiced = false },
    ["sleep"] = { animated = true, voiced = false },
    ["smack"] = { animated = false, voiced = false },
    ["smile"] = { animated = false, voiced = false },
    ["smirk"] = { animated = false, voiced = false },
    ["snap"] = { animated = false, voiced = false },
    ["snarl"] = { animated = false, voiced = false },
    ["sneak"] = { animated = false, voiced = false },
    ["sneeze"] = { animated = false, voiced = false },
    ["snicker"] = { animated = false, voiced = false },
    ["sniff"] = { animated = false, voiced = false },
    ["snort"] = { animated = false, voiced = false },
    ["snub"] = { animated = false, voiced = false },
    ["soothe"] = { animated = false, voiced = false },
    ["spit"] = { animated = false, voiced = false },
    ["squeal"] = { animated = false, voiced = false },
    ["stand"] = { animated = true, voiced = false },
    ["stare"] = { animated = false, voiced = false },
    ["stink"] = { animated = false, voiced = false },
    ["stopattack"] = { animated = false, voiced = false },
    ["surprised"] = { animated = false, voiced = false },
    ["surrender"] = { animated = true, voiced = false },
    ["suspicious"] = { animated = false, voiced = false },
    ["sweat"] = { animated = false, voiced = false },
    ["talk"] = { animated = true, voiced = false },
    ["talkex"] = { animated = true, voiced = false },
    ["talkq"] = { animated = true, voiced = false },
    ["tap"] = { animated = false, voiced = false },
    ["taunt"] = { animated = true, voiced = true },
    ["tease"] = { animated = false, voiced = false },
    ["thank"] = { animated = true, voiced = true },
    ["think"] = { animated = false, voiced = false },
    ["thirsty"] = { animated = false, voiced = false },
    ["threaten"] = { animated = false, voiced = true },
    ["tickle"] = { animated = false, voiced = false },
    ["tired"] = { animated = false, voiced = false },
    ["toast"] = { animated = true, voiced = false },
    ["train"] = { animated = true, voiced = true },
    ["truce"] = { animated = false, voiced = false },
    ["twiddle"] = { animated = false, voiced = false },
    ["veto"] = { animated = false, voiced = false },
    ["victory"] = { animated = true, voiced = false },
    ["violin"] = { animated = true, voiced = true },
    ["wait"] = { animated = true, voiced = true },
    ["warn"] = { animated = false, voiced = false },
    ["wave"] = { animated = true, voiced = false },
    ["welcome"] = { animated = true, voiced = true },
    ["whine"] = { animated = false, voiced = false },
    ["whistle"] = { animated = false, voiced = true },
    ["whoa"] = { animated = true, voiced = true },
    ["wink"] = { animated = false, voiced = false },
    ["work"] = { animated = false, voiced = false },
    ["yawn"] = { animated = false, voiced = true },
    ["yw"] = { animated = true, voiced = true },
}
