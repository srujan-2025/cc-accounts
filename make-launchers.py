#!/usr/bin/env python3
"""Build double-clickable launcher apps (+ distinct icons) for every registered Claude account.

Per account (SHORT = its short name, see `claude-accounts.sh short`), in ~/Applications/Claude Accounts/:
  cc-SHORT.app   asks for a folder, opens Terminal with CLAUDE_CONFIG_DIR set (terminal-style icon)
  ccd-SHORT.app  opens Claude.app with its own --user-data-dir profile (Claude-logo icon)
(`default` gets only a Code launcher: plain Claude.app is already the default desktop profile.)
Every .app in that folder is rebuilt from scratch each run, so keep nothing else there.
"""
import colorsys, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HOME = Path.home()
REGISTRY = Path(os.environ.get("CLAUDE_ACCOUNTS_REGISTRY", HOME / ".config/claude-accounts/accounts"))
OUT = HOME / "Applications" / "Claude Accounts"
BASE_ICNS = Path("/Applications/Claude.app/Contents/Resources/electron.icns")
FONT = "/System/Library/Fonts/Helvetica.ttc"
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")


def accounts():
    for line in REGISTRY.read_text().splitlines():
        parts = line.split("\t")
        if len(parts) >= 2 and NAME_RE.match(parts[0]) and parts[1]:
            short = parts[2] if len(parts) > 2 and NAME_RE.match(parts[2]) else parts[0]
            flags = parts[3].split(",") if len(parts) > 3 else []
            if "hidden" in flags:
                continue
            yield parts[0], parts[1], short, ("nodesktop" in flags)


def shell_dir(d):
    return d.replace(str(HOME), "$HOME", 1) if d.startswith(str(HOME)) else d


def hue_for(name):
    return (sum(ord(c) * (i + 7) for i, c in enumerate(name)) % 360) / 360


def accent(name):
    r, g, b = colorsys.hsv_to_rgb(hue_for(name), 0.65, 0.95)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def terminal_icon(name, short=None, W=1024):
    """Dark terminal window in the account colour: title bar, three dots, '>_' prompt, initial badge."""
    col = accent(name)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    m, rad = int(W * 0.08), int(W * 0.18)
    box = (m, m, W - m, W - m)
    body = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle(box, radius=rad, fill=(28, 28, 32, 255))
    bar_h = int(W * 0.13)
    bd.rectangle((m, m, W - m, m + bar_h), fill=col)
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=rad, fill=255)
    img.paste(body, (0, 0), mask)
    d = ImageDraw.Draw(img)
    for i, c in enumerate(((255, 95, 86), (255, 189, 46), (39, 201, 63))):
        cx, cy, r = m + int(W * 0.07) + i * int(W * 0.065), m + bar_h // 2, int(W * 0.022)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c + (255,))
    mono = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", int(W * 0.34))
    d.text((int(W * 0.40), int(W * 0.47)), ">_", font=mono, fill=col, anchor="mm")
    f = ImageFont.truetype(FONT, int(W * 0.26))
    cx, cy, r = int(W * 0.76), int(W * 0.78), int(W * 0.145)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col, outline=(28, 28, 32, 255), width=int(W * 0.012))
    d.text((cx, cy), (short or name)[0].upper(), font=f, fill=(28, 28, 32, 255), anchor="mm")
    return img


def desktop_icon(base, name, short=None):
    """Claude logo recoloured per account, with the account initial badge."""
    img = base.copy().convert("RGBA")
    h = hue_for(name)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                _, s_, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                nr, ng, nb = colorsys.hsv_to_rgb(h, max(s_, 0.55), v)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    d = ImageDraw.Draw(img)
    W = img.width
    f = ImageFont.truetype(FONT, int(W * 0.30))
    cx, cy, r = int(W * 0.74), int(W * 0.74), int(W * 0.22)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 255), outline=(30, 30, 30, 255), width=int(W * 0.012))
    d.text((cx, cy), (short or name)[0].upper(), font=f, fill=(30, 30, 30, 255), anchor="mm")
    return img


def make_icon(base, name, kind, dest_icns, tmp, short=None):
    img = terminal_icon(name, short) if kind == "code" else desktop_icon(base, name, short)
    iconset = Path(tmp) / f"{name}-{kind}.iconset"
    iconset.mkdir()
    for size in (16, 32, 128, 256, 512):
        img.resize((size, size), Image.LANCZOS).save(iconset / f"icon_{size}x{size}.png")
        img.resize((size * 2, size * 2), Image.LANCZOS).save(iconset / f"icon_{size}x{size}@2x.png")
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(dest_icns)], check=True)


def build_app(app_name, script, icns):
    # build outside ~/Desktop (iCloud adds xattrs that break signing), then copy in without xattrs
    stage = Path(tempfile.mkdtemp()) / f"{app_name}.app"
    subprocess.run(["osacompile", "-o", str(stage), "-e", script], check=True)
    res = stage / "Contents/Resources"
    (res / "Assets.car").unlink(missing_ok=True)
    shutil.copy(icns, res / "applet.icns")
    subprocess.run(["plutil", "-remove", "CFBundleIconName", str(stage / "Contents/Info.plist")], capture_output=True)
    subprocess.run(["xattr", "-cr", str(stage)], check=True)
    subprocess.run(["codesign", "--force", "--sign", "-", str(stage)], check=True, capture_output=True)
    app = OUT / f"{app_name}.app"
    if app.exists():
        shutil.rmtree(app)
    subprocess.run(["ditto", "--norsrc", "--noextattr", str(stage), str(app)], check=True)
    shutil.rmtree(stage.parent)


def main():
    if not REGISTRY.exists():
        sys.exit(f"no registry at {REGISTRY}; run claude-accounts.sh scan first")
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.app"):
        shutil.rmtree(old)  # launchers from any earlier naming scheme, rebuilt below
    tmp = tempfile.mkdtemp()
    png = Path(tmp) / "base.png"
    subprocess.run(["sips", "-s", "format", "png", str(BASE_ICNS), "--out", str(png)], check=True, capture_output=True)
    base = Image.open(png)
    for name, d, short, no_desktop in accounts():
        code_icns = Path(tmp) / f"{name}-code.icns"
        make_icon(base, name, "code", code_icns, tmp, short)
        script = (
            f'set targetFolder to choose folder with prompt "Project folder for cc-{short}:" default location (path to home folder)\n'
            f'tell application "Terminal"\n'
            f'  do script "cd " & quoted form of POSIX path of targetFolder & " && CLAUDE_CONFIG_DIR=\\"{shell_dir(d)}\\" claude"\n'
            f'  activate\nend tell\n'
        )
        build_app(f"cc-{short}", script, code_icns)
        print(f"built cc-{short}")
        if name == "default" or no_desktop:
            continue
        desk_icns = Path(tmp) / f"{name}-desktop.icns"
        make_icon(base, name, "desktop", desk_icns, tmp, short)
        script = (
            f'do shell script "open -n -a \\"/Applications/Claude.app\\" --args '
            f'--user-data-dir=\\"$HOME/Library/Application Support/Claude-{name}\\" > /dev/null 2>&1 &"\n'
        )
        build_app(f"ccd-{short}", script, desk_icns)
        print(f"built ccd-{short}")
    shutil.rmtree(tmp)
    print(f"done -> {OUT}")


if __name__ == "__main__":
    main()
