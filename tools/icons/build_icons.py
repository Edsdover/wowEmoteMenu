"""Generate the animation/sound marker icons.

    python tools/icons/build_icons.py

Writes 64x64 uncompressed 32-bit TGA files into Textures/. WoW wants
power-of-two dimensions, and TGA is loaded by every client generation, unlike
the atlas API which modern clients have and Classic Era does not.

Drawn white with an alpha channel so the addon can tint them at runtime with
SetVertexColor -- gold for sound, blue for animation -- which keeps one file per
shape instead of one per colour.

Supersampled 8x and downsampled, because these display at roughly 12 pixels and
aliased edges turn to mush at that size. Shapes are deliberately chunky for the
same reason: thin strokes disappear.
"""
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(REPO, "Textures")

SIZE = 64
SS = 8                      # supersample factor
W = SIZE * SS
WHITE = (255, 255, 255, 255)


def new_canvas():
    img = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def s(*vals):
    """Scale 64-space coordinates into supersampled space."""
    return tuple(v * SS for v in vals)


def thick_line(draw, p1, p2, width):
    """A line with rounded ends, which survives downsampling better."""
    draw.line([s(*p1), s(*p2)], fill=WHITE, width=width * SS)
    r = (width * SS) // 2
    for (x, y) in (s(*p1), s(*p2)):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)


def build_speaker():
    img, d = new_canvas()
    # Classic speaker: a rectangular neck opening into a cone.
    body = [(10, 25), (22, 25), (36, 9), (36, 55), (22, 39), (10, 39)]
    d.polygon([s(*p) for p in body], fill=WHITE)
    # Two arcs suggesting sound coming out of it.
    for radius, width in ((13, 5), (22, 5)):
        box = [s(36 - radius, 32 - radius), s(36 + radius, 32 + radius)]
        d.arc([box[0][0], box[0][1], box[1][0], box[1][1]],
              start=-52, end=52, fill=WHITE, width=width * SS)
    return img


def build_dancer():
    img, d = new_canvas()
    # A figure mid-step: one arm raised, legs apart. Detail is pointless at the
    # size this renders, so it is built from a few heavy strokes.
    d.ellipse([s(21, 4), s(35, 18)], fill=WHITE)          # head
    thick_line(d, (28, 19), (31, 36), 6)                   # torso
    thick_line(d, (28, 23), (14, 11), 5)                   # arm raised
    thick_line(d, (30, 25), (46, 21), 5)                   # arm out
    thick_line(d, (31, 36), (19, 57), 6)                   # leg
    thick_line(d, (31, 36), (46, 50), 6)                   # leg kicking out
    return img


def build_cog():
    """A gear for the options button: teeth from an alternating-radius polygon,
    then a hole punched through the middle so it reads as a cog and not a star.
    """
    img, d = new_canvas()
    cx = cy = 32.0
    teeth = 8
    r_out, r_in, r_hole = 30.0, 21.0, 9.5
    pts = []
    step = 2 * math.pi / teeth
    for k in range(teeth):
        # One tooth per turn of the loop, centred on its own slice so the gear
        # comes out symmetric about the vertical axis with a tooth pointing up.
        mid = -math.pi / 2 + k * step
        for frac, r in ((-0.38, r_in), (-0.17, r_out),
                        (0.17, r_out), (0.38, r_in)):
            a = mid + frac * step
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon([s(*p) for p in pts], fill=WHITE)
    # Drawn rather than composited: ImageDraw writes the alpha straight in, so
    # a fully transparent fill cuts a hole instead of blending onto the tooth.
    d.ellipse([s(cx - r_hole, cy - r_hole), s(cx + r_hole, cy + r_hole)],
              fill=(255, 255, 255, 0))
    return img


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    small = img.resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(OUT, name)
    small.save(path)                      # Pillow writes uncompressed 32-bit TGA
    print("wrote %s (%dx%d)" % (path, SIZE, SIZE))
    return small


def preview(img, name):
    """Rough look at how it reads once it is only a dozen pixels across."""
    tiny = img.resize((14, 14), Image.LANCZOS)
    ramp = " .:-=+*#%@"
    print("\n%s at 14px:" % name)
    for y in range(14):
        row = ""
        for x in range(14):
            a = tiny.getpixel((x, y))[3]
            row += ramp[min(len(ramp) - 1, a * len(ramp) // 256)] * 2
        print("  " + row)


def main():
    for builder, name in ((build_speaker, "sound.tga"), (build_dancer, "animation.tga"),
                      (build_cog, "cog.tga")):
        img = save(builder(), name)
        preview(img, name)


if __name__ == "__main__":
    main()
