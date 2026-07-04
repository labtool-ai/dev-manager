#!/usr/bin/env python3
import base64, pathlib

BRAND = pathlib.Path(__file__).parent
shot = BRAND / "screenshots" / "devmanager-07-project-dark@2x.png"
uri = "data:image/png;base64," + base64.b64encode(shot.read_bytes()).decode()

W, H = 2560, 1600
s = 0.657
X, Y = 580, 360
IW, IH = 2130 * s, 1680 * s

def map_pt(fx, fy):
    return (X + fx * s, Y + fy * s)

targets = {
    "sidebar":  map_pt(520, 415),
    "meta":     map_pt(880, 470),
    "controls": map_pt(775, 582),
    "logs":     map_pt(1150, 980),
}

MINT = "#2DD4BF"
INK  = "#EAF2EF"
DIM  = "#9AA5A1"
FONT = '"PingFang SC","Helvetica Neue",Arial,sans-serif'

def text_w(t):
    tot = 0
    for c in t:
        if ord(c) > 0x2E80: tot += 34
        elif c == "·":      tot += 22
        elif c == " ":      tot += 12
        else:               tot += 19
    return tot

def pill(x_edge, cy, side, title):
    h = 74
    w = int(text_w(title) + 60)
    title = title.replace("&", "&amp;")
    if side == "L":
        x = x_edge - w; tx, anchor = x_edge - 26, "end"
    else:
        x = x_edge; tx, anchor = x_edge + 26, "start"
    y = cy - h / 2
    return f'''<rect x="{x:.0f}" y="{y:.0f}" width="{w}" height="{h}" rx="18"
        fill="#1B2320" stroke="#33403C" stroke-width="1.5"/>
      <text x="{tx:.0f}" y="{cy+11:.0f}" text-anchor="{anchor}" font-family='{FONT}'
        font-size="34" font-weight="600" fill="{INK}">{title}</text>'''

def leader(px, py, tx, ty):
    return (f'<line x1="{px:.0f}" y1="{py:.0f}" x2="{tx:.0f}" y2="{ty:.0f}" '
            f'stroke="{MINT}" stroke-width="2.6" stroke-linecap="round" opacity="0.95"/>'
            f'<circle cx="{tx:.0f}" cy="{ty:.0f}" r="9" fill="{MINT}"/>'
            f'<circle cx="{tx:.0f}" cy="{ty:.0f}" r="16" fill="none" stroke="{MINT}" stroke-width="2" opacity="0.4"/>')

callouts = [
    (520, 560, "L", "项目 & 启动组合",     "sidebar"),
    (520, 900, "L", "一键 启停 · 重启",     "controls"),
    (2040, 540, "R", "命令 · 路径 · 标签",   "meta"),
    (2040, 1120, "R", "实时日志 · 可搜索",   "logs"),
]

leaders_svg, pills_svg = [], []
for edge, cy, side, title, key in callouts:
    tx, ty = targets[key]
    leaders_svg.append(leader(edge, cy, tx, ty))
    pills_svg.append(pill(edge, cy, side, title))

# lt logo（深色底加描边以便可见）
lx, ly, ls = 150, 88, 120 / 1024
def lrect(ox, oy, ow, oh, fill, rx=0):
    return (f'<rect x="{lx+ox*ls:.1f}" y="{ly+oy*ls:.1f}" width="{ow*ls:.1f}" '
            f'height="{oh*ls:.1f}" rx="{rx*ls:.1f}" fill="{fill}"/>')
logo = (
    f'<rect x="{lx}" y="{ly}" width="120" height="120" rx="28" fill="#1B1B1F" stroke="#33403C" stroke-width="1.5"/>'
    + lrect(335,300,76,416,"#F5F5F4",38)
    + lrect(503,352,76,364,"#F5F5F4",38)
    + lrect(453,440,190,80,"#F5F5F4",40)
    + lrect(593,606,96,96,"#2DD4BF",16)
)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
  width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0E1413"/>
      <stop offset="1" stop-color="#182320"/>
    </linearGradient>
    <radialGradient id="glow1" cx="0.85" cy="0.1" r="0.6">
      <stop offset="0" stop-color="#2DD4BF" stop-opacity="0.20"/>
      <stop offset="1" stop-color="#2DD4BF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow2" cx="0.1" cy="0.95" r="0.6">
      <stop offset="0" stop-color="#3B82F6" stop-opacity="0.12"/>
      <stop offset="1" stop-color="#3B82F6" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#glow1)"/>
  <rect width="{W}" height="{H}" fill="url(#glow2)"/>

  {logo}
  <text x="300" y="150" font-family='{FONT}' font-size="60" font-weight="700" fill="#F5F5F4">DevManager</text>
  <text x="302" y="205" font-family='{FONT}' font-size="30" font-weight="500" fill="{DIM}">本地 dev 进程管理器 · 深色 / 浅色自动跟随系统</text>

  <image xlink:href="{uri}" x="{X}" y="{Y}" width="{IW:.0f}" height="{IH:.0f}"/>

  {''.join(leaders_svg)}
  {''.join(pills_svg)}

  <text x="{W/2:.0f}" y="1520" text-anchor="middle" font-family='{FONT}' font-size="30"
    font-weight="500" fill="{DIM}">⌘K 快速启动 · 端口就绪自动识别 · 崩溃/就绪通知 · Sparkle 自动更新 · MCP 让 AI 直接管进程</text>
  <text x="{W-80}" y="1560" text-anchor="end" font-family='{FONT}' font-size="26" fill="#6B7570">labtool</text>
</svg>'''

out = BRAND / "hero-dark.svg"
out.write_text(svg)
print("wrote", out)
