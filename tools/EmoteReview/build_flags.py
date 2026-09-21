"""Merge an EmoteReview session into the store's animated/voiced flags.

    python tools/EmoteReview/build_flags.py <path to SavedVariables/EmoteReview.lua>
    python tools/EmoteReview/build_flags.py <path> --carry

Nothing in the client reports whether an emote plays an animation or a sound, so
those flags can only come from someone watching and listening. This writes the
answers into wowEmoteMenuStore.lua.

--carry instead regenerates tools/EmoteReview/Emotes.lua with the answers so far
baked in, so a partial session can be resumed after a reload. That is only
necessary because SavedVariables are written but never restored on the Forever
beta; addon files still load normally, which is the way around it.

Emotes left unanswered keep whatever flags they already had, so a partial
session is safe to apply.
"""
import os
import re
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.exit("needs lupa:  python -m pip install lupa")

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
STORE = os.path.join(REPO, "wowEmoteMenuStore.lua")
EMOTES_LUA = os.path.join(HERE, "Emotes.lua")


def read_results(path):
    lua = LuaRuntime()
    lua.execute(open(path, encoding="utf-8").read())
    db = lua.eval("EmoteReviewDB")
    if db is None or db["results"] is None:
        sys.exit("no EmoteReviewDB in " + path)
    out = {}
    for token in db["results"]:
        r = db["results"][token]
        out[token] = (bool(r["animated"]), bool(r["voiced"]))
    return out


def write_carry(results):
    src = open(EMOTES_LUA, encoding="utf-8").read()
    head = src.split("EmoteReviewPrevious")[0].rstrip()
    lines = [head, "", "EmoteReviewPrevious = {"]
    for token in sorted(results):
        animated, voiced = results[token]
        lines.append('    ["%s"] = { animated = %s, voiced = %s },'
                     % (token, str(animated).lower(), str(voiced).lower()))
    lines += ["}", ""]
    open(EMOTES_LUA, "w", encoding="utf-8", newline="\r\n").write("\r\n".join(lines))
    print("carried %d answers into %s" % (len(results), os.path.basename(EMOTES_LUA)))


def apply_flags(results):
    src = open(STORE, encoding="utf-8", newline="").read()
    changed, missing = 0, []

    def repl(match):
        nonlocal changed
        token, body = match.group(1), match.group(0)
        if token not in results:
            missing.append(token)
            return body
        animated, voiced = results[token]
        new = re.sub(r"animated = (?:true|false)",
                     "animated = " + str(animated).lower(), body)
        new = re.sub(r"voiced = (?:true|false)",
                     "voiced = " + str(voiced).lower(), new)
        if new != body:
            changed += 1
        return new

    pattern = (r'\{\r?\n        emote = "([^"]*)",'
               r'(?:\r?\n        [a-zA-Z]+ = [^\r\n]*)+?\r?\n    \},')
    src = re.sub(pattern, repl, src)
    open(STORE, "w", encoding="utf-8", newline="").write(src)
    return changed, missing


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    results = read_results(sys.argv[1])
    print("answers in session : %d" % len(results))

    if "--carry" in sys.argv:
        write_carry(results)
        return

    changed, missing = apply_flags(results)
    animated = sum(1 for a, _ in results.values() if a)
    voiced = sum(1 for _, v in results.values() if v)
    print("flags changed      : %d" % changed)
    print("animated           : %d" % animated)
    print("voiced             : %d" % voiced)
    if missing:
        print("left untouched     : %d (not answered this session)" % len(missing))


if __name__ == "__main__":
    main()
