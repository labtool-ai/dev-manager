---
format: 1920x1080
message: 一屏管好所有本地 dev 服务
arc: 痛点 → 产品 → 核心功能 → 数据证明 → AI/MCP → 品牌落板
audience: 写代码的独立开发者 / 前端 / 全栈
language: 中文（屏幕字，无旁白）
audio: silent (BGM from HeyGen library)
music: minimal upbeat electronic, clean modern tech, light and motivating, subtle — a product promo bed
brand: labtool · 主色薄荷绿 #2DD4BF · 炭灰 #1B1B1F · 米白 #F5F5F4
---

## Video direction

全片一套观感 + 一套运动语法，各帧只写增量。

- **palette system**（取自 frame.md，勿自创）：底 canvas `#F5F5F4`；正文 ink `#0E1413`；次要文字 `#6B6B6B`；**唯一强调色薄荷绿 `#2DD4BF`**——只用于:标注引线/圆点、进度条、高亮、热力图填充、MCP 脉冲连线、光标方块。深色场景(Frame 6 终端、Frame 7 身后窗口)用炭灰 `#1B1B1F`/`#0E1413` 做**各自的整屏 clip 底**、配 `#F5F5F4` 文字。除薄荷绿外不引入任何第二强调色。
- **motion grammar + reveal model**：长尾缓动 `power3` 为默认，**平滑压过弹跳**(禁 back/bounce/elastic 默认)。静音片以**「屏幕字/元素出现的节拍」当作 VO 提示轨**——t=0 只出当下这句要说的东西，其余元素按各自文字节拍在镜头**后半 50%** 陆续揭示，绝不一次性堆满。入场一律 `fromTo`。文字硬切之间用速度匹配的 seam cut(cut-catalog)。
- **rhythm / 留白帧**：忙 = Frame 1(痛点连击)、Frame 3(四次定点变焦)、Frame 6(终端→联动)。静 / 呼吸 = Frame 2 尾(窗口立定)、Frame 3 尾(拉回并存)、Frame 5 尾、Frame 7 尾(落板)。留白帧只允许低幅 **subtle jitter**(`sine-wave-loop` 低幅)保活。
- **negative list**：无弹跳/过冲默认；无「呼吸式」缩放保活；后半段无闲置慢推/慢摇(Frame 3 的定点变焦是有节拍的揭示，不是闲置漂移);无 `repeat`/`yoyo`/无限动画;无 `Math.random`/`Date.now`;无浏览器 chrome/滚动条/真实系统光标(Frame 4/6 是我们自己的截图 UI 重演，允许);无紫蓝「AI」渐变/散景;不出现薄荷绿以外的杂色。

---

## Frame 1 — 痛点开场

- type: pain_point
- blueprint: kinetic-type-beats (Reproduce)
- duration: 4s
- transition_in: cut
- status: animated
- src: compositions/frames/01-pain.html
- scene: 三句本地开发痛点在薄荷绿光标下逐句硬切，收束成一句反问
- asset_candidates: menubar.png — 菜单栏残影
- focal: assets/menubar.png
- roles: menubar = supporting（右上角 ~15% 透明、虚化的幽灵残影，做「一堆服务」暗示）
- poster: 3s

Scene 1 (0.0–1.1s): 米白底；大字「6 个终端来回切」居中 **kinetic-beat-slam**(`kinetic-beat-slam`) 砸入、`power3` 收；右上一枚虚化 menubar 幽灵 **selective-blur**(`depth-of-field-blur`) 低透明衬底。Centered，主体 ≥45%。
Scene 2 (1.1–2.1s): 速度匹配硬切换字「忘了哪个还在跑」(**hard-cut word-swap** `discrete-text-sequence`，seam=cut-the-curve)。
Scene 3 (2.1–3.1s): 再硬切「端口又撞了，谁占的?」(`discrete-text-sequence`)。
Scene 4 (3.1–4.0s): 三句退场，薄荷绿收束句「本地开发，该有个总控台了」**spring-pop**(`spring-pop-entrance`) 弹入居中并定住；至多低幅 **subtle jitter**(`sine-wave-loop`)。

## Frame 2 — 产品登场

- type: product_intro
- blueprint: device-surface-showcase (Adapt)
- duration: 5s
- transition_in: crossfade
- status: animated
- src: compositions/frames/02-intro.html
- scene: DevManager 主窗口自下升入立定，大标题 + 副标滑入
- asset_candidates: main-empty.png — 主界面空状态
- focal: assets/main-empty.png
- roles: main-empty = cutout（前景 hero）
- poster: 4s

Adapt: 保留「窗口作 hero、镜头引入」的招牌，去掉多屏循环，改静态立定 + 标题落。
Scene 1 (0.0–1.4s): 米白底；大字「DevManager」居中偏上 **spring-pop**(`spring-pop-entrance`, `power3`)。Centered。
Scene 2 (1.4–2.8s): 副标「一屏管好所有本地服务」在标题下 **per-word 揭示**(`dynamic-content-sequencing`)。
Scene 3 (2.8–4.4s): 主窗口 main-empty 带阴影自下升起、轻微 3D 立起后定住(**push/settle** `multi-phase-camera` + `spring-pop-entrance`)；标题/副标上移到上三分。Layered-depth，窗口 ~60%，3 层景深。
Scene 4 (4.4–5.0s): 一条薄荷绿进度条自窗口顶一扫而过(`stat-bars-and-fills`)；定住，subtle jitter。

## Frame 3 — 核心：运行中一屏搞定 ★

- type: feature_showcase
- blueprint: device-surface-showcase (Adapt)
- duration: 8s
- transition_in: crossfade
- status: animated
- src: compositions/frames/03-feature.html
- scene: 运行中窗口作 hero，镜头依次变焦四个热点，薄荷绿引线+胶囊标注逐个弹出
- asset_candidates: project-running.png — 运行中详情
- focal: assets/project-running.png
- roles: project-running = cutout（前景 hero）
- poster: 6s

Adapt: 保留「窗口 hero + 焦点巡游」招牌；巡游的是四个功能热点，每站一次定点变焦 + 标注揭示。
Scene 1 (0.0–1.2s): project-running 窗口居中立定作 hero，其余平静(建立镜头)。Centered，~70%。
Scene 2 (1.2–2.8s): **zoom-to-target**(`coordinate-target-zoom`) 推近日志区，窗口其余 **selective-blur**(`depth-of-field-blur`) 压暗；薄荷绿圆点+细引线+胶囊「彩色实时日志」**spring-pop**(`spring-pop-entrance`)。
Scene 3 (2.8–4.4s): 镜头平移(`viewport-change`)到指标行；胶囊「CPU · 内存 · 运行时长」揭示；内存数字轻 **count-up**(`counting-dynamic-scale`)。
Scene 4 (4.4–6.0s): 平移变焦到二维码(`coordinate-target-zoom`)；胶囊「局域网二维码 · 手机扫码调试」揭示；二维码后 **glow bloom**(`ambient-glow-bloom`)。
Scene 5 (6.0–7.2s): 平移到控制按钮；停止/启动键做一次 **press**(`press-release-spring`)；胶囊「一键 启停 · 重启」揭示。
Scene 6 (7.2–8.0s): 拉回全窗(`multi-phase-camera` 回位)，四枚薄荷绿圆点短暂并存；定住，subtle jitter。

## Frame 4 — 加项目 & 启动组合

- type: feature_showcase
- blueprint: cursor-ui-demo (Adapt)
- duration: 4s
- transition_in: wipe
- status: animated
- src: compositions/frames/04-add.html
- scene: 新建弹窗字段逐字填入，再化为侧栏一条项目，tag 分组示意
- asset_candidates: new-process.png — 新建弹窗; main-empty.png — 侧栏落点底
- focal: assets/new-process.png
- roles: new-process = cutout（前景 hero）· main-empty = supporting（收尾侧栏落点的底）
- poster: 3s

Adapt: 保留「操作驱动界面变化」招牌，去掉真实系统光标，改字段逐字填 + 卡片交接。
Scene 1 (0.0–1.0s): new-process 弹窗居中(~60%)入场；上方标题「填目录 + 命令 = 一个项目」**type-on**(`discrete-text-sequence` + `context-sensitive-cursor`)。
Scene 2 (1.0–2.2s): 字段按序逐字填:目录 → 命令 `npm run dev` → tag(各 `discrete-text-sequence`);命令框一道薄荷绿 **highlight**(`css-marker-patterns`) 扫过。
Scene 3 (2.2–3.4s): 弹窗 **scale-swap**(`scale-swap-transition`) 收成侧栏(main-empty)里的一条项目；第二句「按 tag 分组 · 一键起一整组」per-word 揭示。
Scene 4 (3.4–4.0s): 定住；一枚薄荷绿 tag chip 轻脉冲一次(subtle jitter)。

## Frame 5 — 数据证明：启动热力图

- type: social_proof
- blueprint: dataviz-countup (Adapt)
- duration: 4s
- transition_in: cut
- status: animated
- src: compositions/frames/05-stats.html
- scene: 顶部数字 count-up 跳动，GitHub 风格热力图格子逐列点亮
- asset_candidates: stats-heatmap.png — 统计热力图
- focal: assets/stats-heatmap.png
- roles: stats-heatmap = cutout（前景 hero）
- poster: 3s

Adapt: 保留 count-up 招牌，数据源用真实统计页 + 热力图逐列填充。
Scene 1 (0.0–1.2s): stats-heatmap 立定；顶部四个统计数字从 0 **count-up**(`counting-dynamic-scale`) 到位。Centered/上三分。
Scene 2 (1.2–2.6s): 热力图格子按列自左向右薄荷绿 **fill**(`stat-bars-and-fills`) 逐列点亮。
Scene 3 (2.6–3.4s): 「你的本地开发，数据看得见」在下方(避开底部字幕带)per-word 揭示。
Scene 4 (3.4–4.0s): 定住；最后一列(今天)**glow bloom**(`ambient-glow-bloom`);subtle jitter。

## Frame 6 — AI 时代：MCP

- type: feature_showcase
- blueprint: typewriter-reveal (Adapt)
- duration: 6s
- transition_in: crossfade
- status: animated
- src: compositions/frames/06-mcp.html
- scene: 深色终端卡片里命令逐字打出，随后「AI ⇄ 进程」联动点亮
- asset_candidates: logo.png — 品牌章
- focal: assets/logo.png
- roles: logo = supporting（左上角小品牌章）
- poster: 4s

Adapt: 保留 type-on 招牌，打完后卡片重组为 AI⇄进程 联动网络。整帧为**深色**：自带一层炭灰 `#0E1413` 整屏 clip 底。
Scene 1 (0.0–1.6s): 深色终端卡片居中；光标逐字 **type-on**(`discrete-text-sequence` + `context-sensitive-cursor`) 打出 `claude mcp add devmanager -- npx @labtool/devmanager-mcp`。左上 logo 小章淡入。
Scene 2 (1.6–2.6s): 回车；薄荷绿 **highlight**(`css-marker-patterns`) 划过 `@labtool/devmanager-mcp`。
Scene 3 (2.6–4.4s): 卡片重组为网络——左节点「AI · Claude / Codex / Cursor」，右簇「你的 dev 进程」，中间 **connector 自绘**(`svg-path-draw`) + 薄荷绿脉冲沿线走(`avatar-cloud-network`)。
Scene 4 (4.4–5.4s): 右侧项目圆点由灰转薄荷绿依次点亮=被启动(`dynamic-content-sequencing`);「一行命令，让 AI 直接帮你管进程」揭示。
Scene 5 (5.4–6.0s): 定住；脉冲收尾；subtle jitter。

## Frame 7 — 品牌落板 + 深浅色

- type: branding
- blueprint: logo-assemble-lockup (Reproduce)
- duration: 6s
- transition_in: crossfade
- status: animated
- src: compositions/frames/07-brand.html
- scene: lt logo 由色块组装成型，身后窗口做一次明暗翻转，落 slogan + labtool
- asset_candidates: logo.png — 品牌 logo; project-running.png — 浅色底; project-dark.png — 深色底
- focal: assets/logo.png
- roles: logo = cutout（前景 hero）· project-running = background（身后，~40% 暗、虚化）· project-dark = background（翻转后的暗态）
- poster: 4s

Scene 1 (0.0–1.6s): 身后窗口 project-running 作暗底(~40%、`depth-of-field-blur`)，做一次浅→深 **card-morph-anchor / scale-swap**(`card-morph-anchor`) 翻转到 project-dark(点「深浅色自动跟随」)。
Scene 2 (1.6–3.2s): 前景 lt logo 四个色块 **depth-scatter-assemble**(`depth-scatter-assemble`) 组装成型于中心。
Scene 3 (3.2–4.4s): 大字「DevManager」在标下 **spring-pop**(`spring-pop-entrance`);副「一屏管好所有本地服务」per-word 揭示(`dynamic-content-sequencing`)。
Scene 4 (4.4–5.4s): 底部「labtool」淡入;薄荷绿光标方块 **blink 一次**(`context-sensitive-cursor`)。
Scene 5 (5.4–6.0s): 终帧定住(允许真实收尾)；subtle jitter。
