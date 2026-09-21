"""Regenerate wowEmoteMenuStore.lua from an EmoteCapture run.

    python tools/EmoteCapture/build_store.py <path to SavedVariables/EmoteCapture.lua>

Why this exists: the emote list and its exact wording differ between builds.
Forever reworded a number of emotes and made others ignore their target, so data
taken from retail does not match what the server actually prints. Rather than
hand-check hundreds of strings, EmoteCapture performs every emote and records
the replies, and this turns that into the store file.

The transformation is not quite mechanical, which is the real reason to keep
this script rather than redo it from memory next time:

  * The target's name is substituted back to %s. Possessives fall out naturally
    ("Thornpaw's nose" -> "%s's nose") because only the bare name is replaced.
  * An emote whose targeted and untargeted text are identical ignores its
    target. Those get an empty targetText, which makes the menu call
    DoEmote(emote, "none") rather than let the server drop the target quietly.
  * Some emotes print nothing at all but still do something (sit, stand). They
    are kept, with the slash command carried so the tooltip has something to say.
  * Some tokens the client advertises are not implemented server-side and do
    nothing whatsoever. Those are dropped; they would be dead buttons.
  * Some emotes the server accepts are absent from the client's EMOTE*_TOKEN
    list, so a capture can never see them. Those are carried over from the
    existing store untouched. Do not let a capture delete them.
"""
import os
import re
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.exit("needs lupa:  python -m pip install lupa")

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STORE = os.path.join(REPO, "wowEmoteMenuStore.lua")

# Verified in game on 1.60.1.69913. Re-check these after a client patch.
#   kept: performs an action but prints no text
#   dropped: does nothing at all
KEEP_TEXTLESS = {"SIT", "STAND", "TRAIN", "MOUNTSPECIAL"}
DROP = {
    # Newest retail block (indices 623-628), not implemented on Forever.
    "WINCE", "HUZZAH", "IMPRESSED", "MAGNIFICENT", "QUACK", "LEAN",
    "READ",
    # Faction-gated and silent for both factions when tested.
    "FORTHEALLIANCE", "FORTHEHORDE",
}
# animated/voiced for the text-less ones, from watching them in game.
TEXTLESS_FLAGS = {
    "SIT": (True, False), "STAND": (True, False),
    "TRAIN": (True, True), "MOUNTSPECIAL": (True, False),
}

STORE_PATTERN = (
    r'\{\s*emote\s*=\s*"([^"]*)",\s*(?:cmd\s*=\s*"[^"]*",\s*)?'
    r'noTargetText\s*=\s*"([^"]*)",\s*targetText\s*=\s*"([^"]*)",'
    r'\s*animated\s*=\s*(\w+),\s*voiced\s*=\s*(\w+),?\s*\}'
)


def read_capture(path):
    lua = LuaRuntime()
    lua.execute(open(path, encoding="utf-8").read())
    db = lua.eval("EmoteCaptureDB")
    if db is None or db["emotes"] is None:
        sys.exit("no EmoteCaptureDB in " + path)
    build = db["build"]
    version = "%s.%s" % (build[1], build[2]) if build else "unknown build"
    rows = {}
    for token in db["emotes"]:
        e = db["emotes"][token]
        rows[token] = dict(index=e["index"], cmd=e["cmd"] or "",
                           target=e["target"], noTarget=e["noTarget"])
    return db["targetName"], rows, version


def read_store():
    src = open(STORE, encoding="utf-8").read()
    return {a.upper(): dict(emote=a, noTarget=b, target=c, animated=d, voiced=e)
            for a, b, c, d, e in re.findall(STORE_PATTERN, src)}


def build(target_name, capture, store):
    entries = {}
    for token, r in capture.items():
        if token in DROP:
            continue
        plain, targeted = r["noTarget"], r["target"]

        if not plain and not targeted:
            if token not in KEEP_TEXTLESS:
                continue          # silent and unknown: assume not implemented
            plain, targeted = "", ""
        else:
            plain = plain or ""
            targeted = targeted.replace(target_name, "%s") if targeted else ""
            if targeted and targeted == plain:
                targeted = ""     # ignores its target

        prev = store.get(token, {})
        animated, voiced = TEXTLESS_FLAGS.get(
            token, (prev.get("animated", "false"), prev.get("voiced", "false")))
        entries[token] = dict(emote=token.lower(), cmd=r["cmd"],
                              noTarget=plain, targetText=targeted,
                              animated=str(animated).lower(),
                              voiced=str(voiced).lower())

    # Emotes the server accepts but the client never advertises, so a capture
    # cannot reach them. Verified by hand; carried over as-is.
    carried = sorted(set(store) - set(capture))
    for token in carried:
        s = store[token]
        entries[token] = dict(emote=s["emote"], cmd="/" + s["emote"],
                              noTarget=s["noTarget"], targetText=s["target"],
                              animated=s["animated"], voiced=s["voiced"])
    return entries, carried


def quote(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_store(entries, build_info):
    rows = sorted(entries.values(), key=lambda e: e["emote"])
    for r in rows:
        if "\t" in r["noTarget"] or "\t" in r["targetText"]:
            sys.exit("a stray tab survived in " + r["emote"])

    out = [
        "-- Emote data for the Emote Menu addon.",
        "--",
        "-- emote        : the emote token, lowercase. Passed straight to DoEmote() and",
        "--                used as the button label.",
        "-- cmd          : the slash command the client reports for it. Shown in the",
        "--                tooltip for emotes that produce no message text.",
        "-- noTargetText : what the server prints when the emote has no target.",
        "-- targetText   : what the server prints when the emote has a target. Empty",
        "--                means the emote ignores the target, so the menu forces",
        '--                DoEmote(emote, "none").',
        "-- animated     : the emote plays a character animation.",
        "-- voiced       : the emote plays a voice line.",
        "--",
        "-- GENERATED by tools/EmoteCapture/build_store.py -- edit that, not this.",
        "-- Captured from " + build_info + " by performing every emote with and",
        "-- without a target and recording what the server printed back. The result",
        "-- text is server-generated and is not available from the client, which is",
        "-- why it has to live here; it stays English on non-enUS clients.",
        "--",
        "-- A few emotes the server accepts are absent from the client's EMOTE*_TOKEN",
        "-- list, so a capture cannot reach them; those were verified by hand.",
        "",
        "local _, core = ...",
        "",
        "core.emoteTable = {",
    ]
    for r in rows:
        out += ["    {",
                "        emote = " + quote(r["emote"]) + ",",
                "        cmd = " + quote(r["cmd"]) + ",",
                "        noTargetText = " + quote(r["noTarget"]) + ",",
                "        targetText = " + quote(r["targetText"]) + ",",
                "        animated = " + r["animated"] + ",",
                "        voiced = " + r["voiced"] + ",",
                "    },"]
    out += ["}", ""]
    open(STORE, "w", encoding="utf-8", newline="\r\n").write("\r\n".join(out))
    return rows


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    capture_path = sys.argv[1]
    target_name, capture, version = read_capture(capture_path)
    store = read_store()
    before = set(store)

    entries, carried = build(target_name, capture, store)
    rows = write_store(entries, "a live WoW: Forever client (%s)" % version)

    after = set(entries)
    print(f"captured tokens : {len(capture)}  (target: {target_name})")
    print(f"carried by hand : {len(carried)}  {carried}")
    print(f"written         : {len(rows)}  (was {len(before)})")
    added, removed = sorted(after - before), sorted(before - after)
    print(f"added           : {added}")
    print(f"removed         : {removed}")
    if removed:
        print("\n!! check these are genuinely gone and not just absent from")
        print("   EMOTE*_TOKEN, which a capture cannot see.")


if __name__ == "__main__":
    main()
