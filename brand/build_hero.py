#!/usr/bin/env python3
import base64, pathlib

BRAND = pathlib.Path(__file__).parent
shot = BRAND / "screenshots" / "devmanager-02-project-running@2x.png"
b64 = base64.b64encode(shot.read_bytes()).decode()
uri = f"data:image/png;base64,{b64}"

W, H = 2560, 1600
# 截图放置：原图 2130x1680，缩放 s，左上角 (X,Y)
s = 0.657
X, Y = 580, 360
IW, IH = 2130 * s, 1680 * s

def map_pt(fx, fy):
    return (X + fx * s, Y + fy * s)

# 关键功能在原图(2130x1680)中的像素位置
targets = {
    "sidebar":  map_pt(520, 415),
    "controls": map_pt(1000, 643),
    "qr":       map_pt(1736, 500),
    "logs":     map_pt(1100, 1065),
}

MINT = "#14B8A6"
INK  = "#1F2937"
DIM  = "#6B7280"
FONT = '"PingFang SC","Helvetica Neue",Arial,sans-serif'

def text_w(t):
    tot = 0
    for c in t:
        if ord(c) > 0x2E80:      # CJK 全角
            tot += 34
        elif c == "·":
            tot += 22
        elif c == " ":
            tot += 12
        else:                     # 拉丁/数字
            tot += 19
    return tot

def pill(x_edge, cy, w, side, title):
    # side: 'L' 右边缘对齐 x_edge / 'R' 左边缘对齐 x_edge
    h = 74
    w = int(text_w(title) + 60)   # 按文字自动算宽（左右各 30 内边距）
    if side == "L":
        x = x_edge - w
        tx, anchor = x_edge - 26, "end"
    else:
        x = x_edge
        tx, anchor = x_edge + 26, "start"
    y = cy - h / 2
    title = title.replace("&", "&amp;")
    return f'''<rect x="{x:.0f}" y="{y:.0f}" width="{w}" height="{h}" rx="18"
        fill="#FFFFFF" stroke="#E4E9E7" stroke-width="1.5"/>
      <text x="{tx:.0f}" y="{cy+11:.0f}" text-anchor="{anchor}" font-family='{FONT}'
        font-size="34" font-weight="600" fill="{INK}">{title}</text>'''

def leader(px, py, tx, ty):
    return (f'<line x1="{px:.0f}" y1="{py:.0f}" x2="{tx:.0f}" y2="{ty:.0f}" '
            f'stroke="{MINT}" stroke-width="2.6" stroke-linecap="round" opacity="0.9"/>'
            f'<circle cx="{tx:.0f}" cy="{ty:.0f}" r="9" fill="{MINT}"/>'
            f'<circle cx="{tx:.0f}" cy="{ty:.0f}" r="16" fill="none" stroke="{MINT}" stroke-width="2" opacity="0.35"/>')

# 标注配置: (edge_x, cy, width, side, 文案, target_key)
callouts = [
    (520, 520, 320, "L", "项目 & 启动组合",       "sidebar"),
    (520, 900, 320, "L", "一键 启停 · 重启",       "controls"),
    (2040, 540, 380, "R", "局域网二维码 · 扫码调试", "qr"),
    (2040, 1150, 350, "R", "彩色实时日志 · 可搜索",  "logs"),
]

leaders_svg, pills_svg = [], []
for edge, cy, w, side, title, key in callouts:
    tx, ty = targets[key]
    px = edge if side == "L" else edge
    leaders_svg.append(leader(px, cy, tx, ty))
    pills_svg.append(pill(edge, cy, w, side, title))

# lt logo 小标（120px），左上角 (150,88)
lx, ly, ls = 150, 88, 120 / 1024
def lrect(ox, oy, ow, oh, fill, rx=0):
    return (f'<rect x="{lx+ox*ls:.1f}" y="{ly+oy*ls:.1f}" width="{ow*ls:.1f}" '
            f'height="{oh*ls:.1f}" rx="{rx*ls:.1f}" fill="{fill}"/>')
logo = (
    f'<rect x="{lx}" y="{ly}" width="120" height="120" rx="28" fill="#1B1B1F"/>'
    + lrect(335,300,76,416,"#F5F5F4",38)
    + lrect(503,352,76,364,"#F5F5F4",38)
    + lrect(453,440,190,80,"#F5F5F4",40)
    + lrect(593,606,96,96,"#2DD4BF",16)
)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
  width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#F1F8F5"/>
      <stop offset="1" stop-color="#DCE9EC"/>
    </linearGradient>
    <radialGradient id="glow1" cx="0.85" cy="0.1" r="0.6">
      <stop offset="0" stop-color="#2DD4BF" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#2DD4BF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow2" cx="0.1" cy="0.95" r="0.6">
      <stop offset="0" stop-color="#6AA6E8" stop-opacity="0.14"/>
      <stop offset="1" stop-color="#6AA6E8" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#glow1)"/>
  <rect width="{W}" height="{H}" fill="url(#glow2)"/>

  {logo}
  <text x="300" y="150" font-family='{FONT}' font-size="60" font-weight="700" fill="#1B1B1F">DevManager</text>
  <text x="302" y="205" font-family='{FONT}' font-size="30" font-weight="500" fill="{DIM}">本地 dev 进程管理器 · 一屏管好所有本地服务</text>

  <image xlink:href="{uri}" x="{X}" y="{Y}" width="{IW:.0f}" height="{IH:.0f}"/>

  {''.join(leaders_svg)}
  {''.join(pills_svg)}

  <text x="{W/2:.0f}" y="1520" text-anchor="middle" font-family='{FONT}' font-size="30"
    font-weight="500" fill="{DIM}">⌘K 快速启动 · 端口就绪自动识别 · 崩溃/就绪通知 · Sparkle 自动更新 · MCP 让 AI 直接管进程</text>
  <text x="{W-80}" y="1560" text-anchor="end" font-family='{FONT}' font-size="26" fill="#9AA6A2">labtool</text>
</svg>'''

out = BRAND / "hero.svg"
out.write_text(svg)
print("wrote", out, len(svg), "bytes")
